import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../models/table_info.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../utils/snackbar_helper.dart';

class GameTableScreen extends StatefulWidget {
  const GameTableScreen({super.key});

  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen> with TickerProviderStateMixin {
  late final GameService _gameService;
  GameTableInfo? _tableInfo;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _autoAdvanceTimer;
  int _phaseTimeRemaining = 0;
  GameProvider? _gameProvider;
  
  // Animation state for reactions
  final Map<String, AnimationController> _reactionAnimations = {};
  final Map<String, String> _playerReactionStates = {}; // 'like', 'dislike', or ''

  @override
  void initState() {
    super.initState();
    _gameService = GameService(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTableInfo(); // Load table info directly
      _setupReactionCallback();
    });
    _startRefreshTimer();
    
    // Add timeout to prevent infinite loading
    Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        print('⚠️ Loading timeout reached, setting loading to false');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Timeout: Could not load game data';
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameProvider = Provider.of<GameProvider>(context, listen: false);
    _gameProvider?.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (mounted) {
      // If game state becomes available and we're still loading, try to load table info
      if (_gameProvider?.currentGameState != null && _isLoading) {
        print('🔄 Game state became available, loading table info');
        _loadTableInfo();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _gameProvider?.removeListener(_onGameStateChanged);
    // Dispose animation controllers
    for (var controller in _reactionAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadTableInfo();
        _refreshGameInfo();
      }
    });
  }

  Future<void> _loadTableInfo() async {
    try {
      print('🔄 Loading table info...');
      
      // Try to load table info directly from room-info endpoint
      try {
      final data = await _gameService.getGameTableInfo();
      print('📊 Raw data: $data');
      print('🔍 Current speaker in data: ${data['current_speaker']}');
        print('🔍 Table image URL in data: ${data['table_image_url']}');
        print('🔍 Players in data: ${data['players']}');
        print('🔍 Scenario name in data: ${data['scenario_name']}');
      
      final tableInfo = GameTableInfo.fromJson(data);
      print('🔍 Current speaker after parsing: ${tableInfo.currentSpeaker?.username}');
      print('🔍 Players speaking status:');
      for (var player in tableInfo.players) {
        print('  - ${player.username}: isSpeaking=${player.isSpeaking}');
      }
        print('🔍 Table image URL after parsing: ${tableInfo.tableImageUrl}');
        print('🔍 Scenario name after parsing: ${tableInfo.scenarioName}');
      
        // Use the table info from backend as is (including the image URL)
      if (mounted) {
        setState(() {
          _tableInfo = tableInfo;
          _isLoading = false;
          _errorMessage = null;
        });
        print('✅ Table info updated in state');
          print('📸 Table image URL from backend: ${tableInfo.tableImageUrl}');
        
        // شروع تایمر نوبت صحبت
        _startAutoAdvanceTimer();
        }
      } catch (e) {
        print('❌ Error loading real table info, creating basic table info: $e');
        await _createBasicTableInfo();
      }
    } catch (e) {
      print('❌ Error loading table info: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _createBasicTableInfo() async {
    try {
      print('🔄 Creating basic table info...');
      
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final room = gameProvider.currentRoom;
      
      if (room == null) {
        print('❌ No room available for basic table info');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No room available';
          });
        }
        return;
      }

      // Try to get players from API first
      List<Player> players = gameProvider.currentPlayers;
      print('🔍 Current players from provider: ${players.length}');
      
      // If no players from provider, try to fetch from API
      if (players.isEmpty) {
        try {
          print('🔄 No players in provider, trying to fetch from API...');
          final result = await _gameService.getLobby(room.id);
          players = result['players'] as List<Player>;
          print('🔍 Players from API: ${players.length}');
          
          // Update provider with fetched players
          gameProvider.setCurrentPlayers(players);
        } catch (e) {
          print('⚠️ Could not fetch players from API: $e');
        }
      }
      
      // If still no players, create dummy players
      if (players.isEmpty) {
        print('⚠️ Still no players, creating dummy players');
        players = List.generate(room.currentPlayers, (index) => Player(
          id: index + 1,
          userId: index + 1,
          username: 'Player ${index + 1}',
          roomId: room.id,
          isAlive: true,
          isReady: true,
          joinedAt: DateTime.now(),
          votesReceived: 0,
          isProtected: false,
          specialActionsUsed: {},
        ));
      }

      // Create basic player seats in a circle
      final playerSeats = <PlayerSeat>[];
      final playerCount = players.length;
      
      for (int i = 0; i < playerCount; i++) {
        final angle = (i * 360.0 / playerCount) * (3.14159 / 180); // Convert to radians
        final radius = 0.25; // کاهش شعاع برای اطمینان از قرارگیری در محدوده
        final x = (0.5 + radius * cos(angle)).clamp(0.1, 0.9); // محدود کردن به محدوده امن
        final y = (0.5 + radius * sin(angle)).clamp(0.1, 0.9); // محدود کردن به محدوده امن
        
        // Debug print برای بررسی موقعیت‌ها
        print('🎯 Player ${i + 1} (${players[i].username}): angle=${angle.toStringAsFixed(2)}, x=${x.toStringAsFixed(3)}, y=${y.toStringAsFixed(3)}');
        
        playerSeats.add(PlayerSeat(
          id: i + 1,
          username: players[i].username,
          role: null, // Room players don't have roles yet
          isAlive: players[i].isAlive,
          avatarUrl: null,
          seatPosition: SeatPosition(
            x: x,
            y: y,
            angle: (i * 360.0 / playerCount),
          ),
          isSpeaking: false,
          reactions: {},
        ));
      }

      // Create basic table info without image (will use custom design)
      final basicTableInfo = GameTableInfo(
        tableImageUrl: null, // No image, will use custom table design
        scenarioName: room.scenario?.name ?? 'Basic Game',
        players: playerSeats,
        currentSpeaker: null,
        speakingQueue: SpeakingQueue(
          spokenPlayers: [],
          remainingPlayers: players.map((p) => p.username).toList(),
        ),
      );

      if (mounted) {
        setState(() {
          _tableInfo = basicTableInfo;
          _isLoading = false;
          _errorMessage = null;
        });
        print('✅ Basic table info created with ${playerSeats.length} players');
        
        // شروع تایمر نوبت صحبت
        _startAutoAdvanceTimer();
      }
      
    } catch (e) {
      print('❌ Error creating basic table info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error creating basic table info: $e';
        });
      }
    }
  }

  Future<void> _refreshGameInfo() async {
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      print('🔄 Refreshing game info...');
      
      // Try to load table info directly first
      await _loadTableInfo();
      
      // Also try to refresh game info if possible
      try {
        await gameProvider.refreshGameInfo();
      final gameState = gameProvider.currentGameState;
      print('📊 Game state after refresh:');
      print('  - phase: ${gameState?.phase}');
      print('  - phaseTimeRemaining: ${gameState?.phaseTimeRemaining}');
      print('  - playerRole: ${gameState?.playerRole}');
      } catch (e) {
        print('⚠️ Could not refresh game info: $e');
      }
      
      // شروع تایمر auto-advance
      _startAutoAdvanceTimer();
    } catch (e) {
      print('❌ Error refreshing game info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error refreshing game info: $e';
        });
      }
    }
  }

  void _startAutoAdvanceTimer() {
    // لغو تایمر قبلی
    _autoAdvanceTimer?.cancel();
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final gameState = gameProvider.currentGameState;
    
    print('⏰ Starting auto-advance timer:');
    print('  - gameState: $gameState');
    print('  - currentSpeaker: ${_tableInfo?.currentSpeaker?.username}');
    print('  - timeRemaining: ${_tableInfo?.currentSpeaker?.timeRemaining}');
    
    // برای نوبت صحبت در فاز روز
    if (gameState != null && 
        gameState.phase == 'day' && 
        _tableInfo?.currentSpeaker != null &&
        _tableInfo!.currentSpeaker!.timeRemaining > 0) {
      _phaseTimeRemaining = _tableInfo!.currentSpeaker!.timeRemaining;
      print('  - _phaseTimeRemaining set to: $_phaseTimeRemaining');
      
      _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _phaseTimeRemaining--;
          });
          
          print('⏰ Timer tick: $_phaseTimeRemaining seconds remaining');
          
          // اگر زمان تمام شد، نوبت صحبت را به‌روزرسانی کن
          if (_phaseTimeRemaining <= 0) {
            timer.cancel();
            print('⏰ Speaking time up! Refreshing game info...');
            _refreshGameInfo(); // این باعث auto-advance در backend می‌شود
            _loadTableInfo(); // همچنین اطلاعات میز را هم به‌روزرسانی کن
          }
        } else {
          timer.cancel();
        }
      });
    }
    // برای اقدامات شب
    else if (gameState != null && 
             gameState.phase == 'night' && 
             gameState.phaseTimeRemaining > 0) {
      _phaseTimeRemaining = gameState.phaseTimeRemaining;
      print('  - Night action timer set to: $_phaseTimeRemaining');
      
      _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _phaseTimeRemaining--;
          });
          
          print('🌙 Night timer tick: $_phaseTimeRemaining seconds remaining');
          
          // اگر زمان تمام شد، فاز شب را به‌روزرسانی کن
          if (_phaseTimeRemaining <= 0) {
            timer.cancel();
            print('🌙 Night action time up! Refreshing game info...');
            _refreshGameInfo(); // این باعث auto-advance در backend می‌شود
            _loadTableInfo(); // همچنین اطلاعات میز را هم به‌روزرسانی کن
          }
        } else {
          timer.cancel();
        }
      });
    } else {
      print('⚠️ Cannot start timer: no active timer needed');
      _phaseTimeRemaining = 0;
    }
  }

  String _getCurrentRoleTurnText() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final gameState = gameProvider.currentGameState;
    
    // اگر اطلاعات نقش‌ها در gameState موجود باشد
    if (gameState != null) {
      // بر اساس فاز واقعی از backend تصمیم بگیر
      if (gameState.phase == 'night') {
        // در حالت شب، بر اساس زمان باقی‌مانده حدس بزن
        if (_phaseTimeRemaining > 20) {
          return 'شب - نوبت مافیا: نقش‌های مخفی در حال تصمیم‌گیری هستند';
        } else if (_phaseTimeRemaining > 10) {
          return 'شب - نوبت دکتر: نقش‌های محافظ در حال عمل هستند';
        } else if (_phaseTimeRemaining > 5) {
          return 'شب - نوبت کارآگاه: نقش‌های جاسوس در حال تحقیق هستند';
        } else {
          return 'شب - پایان فاز شب: منتظر نتایج باشید';
        }
      } else if (gameState.phase == 'day') {
        // در حالت روز
        return 'روز - در مورد بازیکنان مشکوک صحبت کنید';
      } else {
        // سایر حالت‌ها
        return 'منتظر شروع بازی...';
      }
    }
    
    return 'شب - نقش‌های مخفی در حال عمل هستند';
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have a room first
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    print('🔍 GameTableScreen.build: Current room: ${gameProvider.currentRoom}');
    print('🔍 GameTableScreen.build: Current players: ${gameProvider.currentPlayers.length}');
    print('🔍 GameTableScreen.build: Loading: $_isLoading');
    print('🔍 GameTableScreen.build: Error: $_errorMessage');
    
    if (gameProvider.currentRoom == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('میز بازی'),
          backgroundColor: const Color(0xFF1a1a1a),
          foregroundColor: const Color(0xFFFFD700),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'اتاق بازی یافت نشد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'ابتدا وارد یک اتاق شوید',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text('بازگشت به خانه'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // Try to load table info anyway
                  await _loadTableInfo();
                },
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('میز بازی'),
          backgroundColor: const Color(0xFF1a1a1a),
          foregroundColor: const Color(0xFFFFD700),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
              const SizedBox(height: 16),
              const Text(
                'در حال بارگذاری اطلاعات بازی...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'اتاق: ${gameProvider.currentRoom?.name ?? 'نامشخص'}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = false;
                  });
                  _refreshGameInfo();
                },
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'خطا در بارگذاری اطلاعات میز',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTableInfo,
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tableInfo == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('میز بازی'),
          backgroundColor: const Color(0xFF1a1a1a),
          foregroundColor: const Color(0xFFFFD700),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_chart, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'اطلاعات میز یافت نشد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'در حال تلاش برای بارگذاری مجدد...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _refreshGameInfo();
                },
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
    return Scaffold(
          appBar: _buildAppBar(gameProvider),
          body: SafeArea(
            child: Column(
            children: [
              _buildStatusBar(gameProvider),
              Expanded(child: _buildTableLayout(gameProvider)),
            ],
          ),
          ),
          bottomNavigationBar: SafeArea(
            child: _buildControls(gameProvider),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(GameProvider gameProvider) {
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night' || gameState?.phase == 'mafia_night';
    
    return AppBar(
          leading: Icon(
            isNightPhase ? Icons.nightlight_round : Icons.wb_sunny,
            color: const Color(0xFFFFD700), // طلایی
            size: 24,
          ),
          title: Text(
            _tableInfo!.scenarioName,
            textAlign: TextAlign.center,
          ),
          centerTitle: true,
      actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showGameInfo(),
              tooltip: 'اطلاعات بازی',
            ),
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () => _showDebugDialog(),
              tooltip: 'حالت دیباگ',
            ),
        if (_tableInfo!.currentSpeaker != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '${_tableInfo!.currentSpeaker!.timeRemaining}s',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBar(GameProvider gameProvider) {
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night' || gameState?.phase == 'mafia_night';
    final userRole = gameState?.playerRole;
    
    // Debug prints
    print('🔍 StatusBar Debug:');
    print('  - gameState: $gameState');
    print('  - phase: ${gameState?.phase}');
    print('  - isNightPhase: $isNightPhase');
    print('  - userRole: $userRole');
    print('  - _phaseTimeRemaining: $_phaseTimeRemaining');
    
    String statusText = '';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info;
    
    if (_tableInfo?.currentSpeaker != null) {
      // اگر کسی در حال صحبت است
      statusText = '${_tableInfo!.currentSpeaker!.username} در حال صحبت است';
      statusColor = Colors.blue;
      statusIcon = Icons.mic;
    } else if (isNightPhase) {
      // حالت شب
      switch (userRole?.toLowerCase()) {
        case 'mafia':
          statusText = 'شب - نوبت مافیا: یک بازیکن را برای کشتن انتخاب کنید';
          statusColor = Colors.red;
          statusIcon = Icons.person_remove;
          break;
        case 'doctor':
          statusText = 'شب - نوبت دکتر: یک بازیکن را برای درمان انتخاب کنید';
          statusColor = Colors.green;
          statusIcon = Icons.healing;
          break;
        case 'detective':
          statusText = 'شب - نوبت کارآگاه: یک بازیکن را برای تحقیق انتخاب کنید';
          statusColor = Colors.blue;
          statusIcon = Icons.search;
          break;
        case 'sniper':
          statusText = 'شب - نوبت تیرانداز: یک هدف را برای شلیک انتخاب کنید';
          statusColor = Colors.orange;
          statusIcon = Icons.gps_fixed;
          break;
        default:
          // برای شهروندان، نشان دادن نوبت نقش‌ها
          if (isNightPhase) {
            statusText = _getCurrentRoleTurnText();
            statusColor = Colors.purple;
            statusIcon = Icons.nightlight_round;
          } else {
            statusText = 'روز - در مورد بازیکنان مشکوک صحبت کنید';
            statusColor = Colors.amber;
            statusIcon = Icons.wb_sunny;
          }
          break;
      }
    } else {
      // حالت روز
      statusText = 'روز - در مورد بازیکنان مشکوک صحبت کنید';
      statusColor = Colors.amber;
      statusIcon = Icons.wb_sunny;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            statusColor.withOpacity(0.2),
            statusColor.withOpacity(0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableLayout(GameProvider gameProvider) {
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night' || gameState?.phase == 'mafia_night';
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.none, // اجازه نمایش المان‌های خارج از محدوده
        children: [
          // Table background
          _buildTableBackground(),
          
          // دایره‌های بازیکنان
          ..._tableInfo!.players.map((player) => _buildPlayerSeat(player)),
          
              // پرده تاریک برای حالت شب
              if (isNightPhase)
                IgnorePointer(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                ),
              
          // اطلاعات اضافی
          _buildGameInfo(),
        ],
      ),
    );
  }

  Widget _buildTableBackground() {
    if (_tableInfo?.tableImageUrl != null && _tableInfo!.tableImageUrl!.isNotEmpty) {
      print('🖼️ Attempting to load table image: ${_tableInfo!.tableImageUrl}');
      
      return Stack(
        children: [
          // Background image
          Image.network(
            _tableInfo!.tableImageUrl!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'image/*',
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                color: Colors.brown[300],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'در حال لود عکس میز...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading table image: $error');
              print('❌ Image URL: ${_tableInfo!.tableImageUrl}');
              print('❌ Stack trace: $stackTrace');
              _tryFallbackImage();
              
              // Return custom design as fallback
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.brown[400]!,
                      Colors.brown[600]!,
                      Colors.brown[800]!,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
                child: CustomPaint(
                  painter: TablePatternPainter(),
                ),
              );
            },
          ),
        ],
      );
    } else {
      print('🎨 Using custom table design (no image URL)');
      // Create a simple table background with gradient
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Colors.brown[400]!,
              Colors.brown[600]!,
              Colors.brown[800]!,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: TablePatternPainter(),
        ),
      );
    }
  }

  void _tryFallbackImage() {
    if (mounted) {
      setState(() {
        // If image fails to load, use custom table design instead
        if (_tableInfo != null) {
          _tableInfo = GameTableInfo(
            tableImageUrl: null, // Remove image URL to use custom design
            scenarioName: _tableInfo!.scenarioName,
            players: _tableInfo!.players,
            currentSpeaker: _tableInfo!.currentSpeaker,
            speakingQueue: _tableInfo!.speakingQueue,
          );
        }
      });
    }
  }

  Widget _buildPlayerSeat(PlayerSeat player) {
    final screenSize = MediaQuery.of(context).size;
    final x = player.seatPosition.x * screenSize.width;
    final y = player.seatPosition.y * screenSize.height;
    
    // بررسی فاز بازی
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night' || gameState?.phase == 'mafia_night';
    
    // در شب، دایره‌ها نباید روشن باشند
    final isActuallySpeaking = !isNightPhase && player.isSpeaking;
    
    // بررسی وضعیت انیمیشن واکنش
    final reactionType = _playerReactionStates[player.username] ?? '';
    final isAnimating = reactionType.isNotEmpty;
    final animationController = _reactionAnimations[player.username];
    
    // Debug print
    print('🎯 Player: ${player.username}, Position: ($x, $y), Screen: ${screenSize.width}x${screenSize.height}');
    print('  - isSpeaking: ${player.isSpeaking}');
    print('  - isNightPhase: $isNightPhase');
    print('  - isActuallySpeaking: $isActuallySpeaking');
    print('  - currentSpeaker: ${_tableInfo?.currentSpeaker?.username}');
    print('  - reactionType: $reactionType, isAnimating: $isAnimating');
    
    // پیدا کردن شماره صندلی
    final seatNumber = _tableInfo!.players.indexOf(player) + 1;
    
    return Positioned(
      left: x - 60, // نصف عرض کل widget
      top: y - 60,  // نصف ارتفاع کل widget
      child: GestureDetector(
        onTap: () => _onPlayerTap(player),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دایره اصلی
            AnimatedBuilder(
              animation: animationController ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getPlayerCircleColors(isActuallySpeaking, isAnimating, reactionType, animationController?.value ?? 0.0),
                    ),
                    border: Border.all(
                      color: _getPlayerBorderColor(isActuallySpeaking, isAnimating, reactionType, animationController?.value ?? 0.0),
                      width: isActuallySpeaking ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // آواتار بازیکن
                      Center(
                        child: isAnimating 
                            ? _buildAnimatedAvatar(player, reactionType, animationController?.value ?? 0.0)
                            : (player.avatarUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      player.avatarUrl!,
                                      width: 55,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildDefaultAvatar(player.username);
                                      },
                                    ),
                                  )
                                : _buildDefaultAvatar(player.username)),
                      ),
                  
                      // شماره صندلی
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              seatNumber.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // نشانگر صحبت
                      if (isActuallySpeaking)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF8B0000), Color(0xFF5D0000)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            
            // نام کاربری - چسبیده به دایره
            Transform.translate(
              offset: const Offset(0, -5), // 5 پیکسل بالاتر (کمتر از قبل)
              child: Container(
                width: 90,
                height: 22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: player.isSpeaking 
                        ? [const Color(0xFF8B0000), const Color(0xFF5D0000)]
                        : [const Color(0xFF2C2C2C), const Color(0xFF1a1a1a)],
                  ),
                  borderRadius: BorderRadius.zero, // حذف لبه‌های گرد
                  border: Border.all(
                    color: player.isSpeaking 
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF404040),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    player.username.isNotEmpty ? player.username : 'بدون نام',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 1,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                    ),
                  ),
                ),
              
              // واکنش‌ها
            if (player.reactions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (player.reactions['likes'] != null && player.reactions['likes']! > 0)
                        _buildReactionIcon(Icons.thumb_up, player.reactions['likes']!),
                      if (player.reactions['dislikes'] != null && player.reactions['dislikes']! > 0)
                        _buildReactionIcon(Icons.thumb_down, player.reactions['dislikes']!),
                    ],
                ),
            ],
            ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String username) {
    return Container(
      width: 55,
      height: 55,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedAvatar(PlayerSeat player, String reactionType, double animationValue) {
    final username = player.username;
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    
    // Calculate animation effects
    final scale = 1.0 + (0.3 * animationValue); // Scale up to 1.3x
    final rotation = animationValue * 2 * 3.14159; // Full rotation
    final opacity = 0.7 + (0.3 * (1 - animationValue)); // Fade in then out
    
    // Choose colors based on reaction type
    Color backgroundColor;
    Color textColor;
    if (reactionType == 'like') {
      backgroundColor = const Color(0xFF4CAF50); // Green
      textColor = Colors.white;
    } else if (reactionType == 'dislike') {
      backgroundColor = const Color(0xFFF44336); // Red
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.grey;
      textColor = Colors.white;
    }
    
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.5),
                  blurRadius: 10 + (10 * animationValue),
                  spreadRadius: 2 + (3 * animationValue),
                ),
              ],
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: textColor,
                  fontSize: 28 + (8 * animationValue), // Grow text size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getPlayerCircleColors(bool isSpeaking, bool isAnimating, String reactionType, double animationValue) {
    if (isAnimating) {
      if (reactionType == 'like') {
        // Green gradient for like
        return [
          Color.lerp(const Color(0xFF2C2C2C), const Color(0xFF4CAF50), animationValue)!,
          Color.lerp(const Color(0xFF1a1a1a), const Color(0xFF2E7D32), animationValue)!,
        ];
      } else if (reactionType == 'dislike') {
        // Red gradient for dislike
        return [
          Color.lerp(const Color(0xFF2C2C2C), const Color(0xFFF44336), animationValue)!,
          Color.lerp(const Color(0xFF1a1a1a), const Color(0xFFC62828), animationValue)!,
        ];
      }
    }
    
    // Default colors
    if (isSpeaking) {
      return [const Color(0xFF8B0000), const Color(0xFF5D0000)]; // Red mafia gradient
    } else {
      return [const Color(0xFF2C2C2C), const Color(0xFF1a1a1a)]; // Gray mafia gradient
    }
  }

  Color _getPlayerBorderColor(bool isSpeaking, bool isAnimating, String reactionType, double animationValue) {
    if (isAnimating) {
      if (reactionType == 'like') {
        return Color.lerp(const Color(0xFF404040), const Color(0xFF4CAF50), animationValue)!;
      } else if (reactionType == 'dislike') {
        return Color.lerp(const Color(0xFF404040), const Color(0xFFF44336), animationValue)!;
      }
    }
    
    // Default colors
    if (isSpeaking) {
      return const Color(0xFFFFD700); // Gold
    } else {
      return const Color(0xFF404040); // Light gray
    }
  }


  Widget _buildReactionIcon(IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'بازیکنان زنده: ${_tableInfo!.players.length}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            if (_tableInfo!.currentSpeaker != null)
              Text(
                'گوینده: ${_tableInfo!.currentSpeaker!.username}',
                style: const TextStyle(color: Colors.yellow, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اطلاعات بازی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سناریو: ${_tableInfo?.scenarioName ?? 'نامشخص'}'),
            const SizedBox(height: 8),
            Text('تعداد بازیکنان: ${_tableInfo?.players.length ?? 0}'),
            const SizedBox(height: 8),
            Text('عکس میز: ${_tableInfo?.tableImageUrl != null ? 'از Backend' : 'طراحی سفارشی'}'),
            if (_tableInfo?.tableImageUrl != null) ...[
              const SizedBox(height: 4),
              Text(
                'URL: ${_tableInfo!.tableImageUrl}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // Test image loading
                  print('🧪 Testing image URL: ${_tableInfo!.tableImageUrl}');
                  
                  try {
                    // Try to validate the URL
                    final uri = Uri.parse(_tableInfo!.tableImageUrl!);
                    print('✅ URL is valid: $uri');
                    print('✅ Scheme: ${uri.scheme}');
                    print('✅ Host: ${uri.host}');
                    print('✅ Path: ${uri.path}');
                    
                    // Force reload the image
                    setState(() {
                      // This will trigger a rebuild and reload the image
                    });
                  } catch (e) {
                    print('❌ Invalid URL: $e');
                  }
                },
                child: const Text('تست لود عکس'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // Debug raw API data
                  print('🔍 Debugging raw API data...');
                  try {
                    final data = await _gameService.getGameTableInfo();
                    print('📊 Raw API Response:');
                    print('  - Keys: ${data.keys.toList()}');
                    print('  - Table image URL: ${data['table_image_url']}');
                    print('  - Players: ${data['players']}');
                    print('  - Scenario name: ${data['scenario_name']}');
                    print('  - Current speaker: ${data['current_speaker']}');
                    print('  - Speaking queue: ${data['speaking_queue']}');
                    
                    // Show in dialog
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Raw API Data'),
                          content: SingleChildScrollView(
                            child: Text(
                              'Keys: ${data.keys.toList()}\n\n'
                              'Table Image URL: ${data['table_image_url']}\n\n'
                              'Players: ${data['players']}\n\n'
                              'Scenario Name: ${data['scenario_name']}\n\n'
                              'Current Speaker: ${data['current_speaker']}\n\n'
                              'Speaking Queue: ${data['speaking_queue']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('بستن'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    print('❌ Error getting raw data: $e');
                  }
                },
                child: const Text('Debug API Data'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(GameProvider gameProvider) {
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night' || gameState?.phase == 'mafia_night';
    final userRole = gameState?.playerRole;
        
    return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1a1a1a).withOpacity(0.95),
                const Color(0xFF1a1a1a),
              ],
            ),
        border: Border(
              top: BorderSide(color: const Color(0xFF404040), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // دکمه‌های صحبت
              if (_tableInfo!.currentSpeaker != null && _isCurrentUserSpeaking())
                _buildActionButton(
                  icon: Icons.stop,
                  label: 'پایان صحبت',
                  color: const Color(0xFFE53935),
                  onPressed: _endSpeaking,
                  isFullWidth: true,
                )
              else if (isNightPhase)
                // دکمه‌های نقش برای حالت شب
                _buildNightPhaseButtons(userRole)
              else
                // دکمه‌های واکنش و چالش برای حالت روز
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                    _buildReactionButton(
                      icon: Icons.thumb_up_alt,
                      label: 'لایک',
                      color: const Color(0xFF2196F3),
                      onPressed: () => _addReaction('like'),
                    ),
                    _buildReactionButton(
                      icon: Icons.thumb_down_alt,
                      label: 'دیسلایک',
                      color: const Color(0xFFE53935),
                      onPressed: () => _addReaction('dislike'),
                    ),
                    _buildReactionButton(
                      icon: Icons.gavel,
                      label: 'چالش',
                      color: const Color(0xFFFF9800),
                      onPressed: _challengeSpeaking,
                    ),
                  ],
                ),
            ],
          ),
        );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNightPhaseButtons(String? userRole) {
    switch (userRole?.toLowerCase()) {
      case 'mafia':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNightActionButton(
              icon: Icons.person_remove,
              label: 'کشتن',
              color: const Color(0xFF8B0000),
              onPressed: () => _performNightAction('kill'),
            ),
            _buildNightActionButton(
              icon: Icons.visibility,
              label: 'مشاهده',
              color: const Color(0xFF4CAF50),
              onPressed: () => _performNightAction('observe'),
            ),
            _buildNightActionButton(
              icon: Icons.psychology,
              label: 'تحلیل',
              color: const Color(0xFF9C27B0),
              onPressed: () => _performNightAction('analyze'),
            ),
          ],
        );
      
      case 'doctor':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNightActionButton(
              icon: Icons.healing,
              label: 'درمان',
              color: const Color(0xFF4CAF50),
              onPressed: () => _performNightAction('heal'),
            ),
            _buildNightActionButton(
              icon: Icons.visibility,
              label: 'مشاهده',
              color: const Color(0xFF2196F3),
              onPressed: () => _performNightAction('observe'),
            ),
            _buildNightActionButton(
              icon: Icons.psychology,
              label: 'تحلیل',
              color: const Color(0xFF9C27B0),
              onPressed: () => _performNightAction('analyze'),
            ),
          ],
        );
      
      case 'detective':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNightActionButton(
              icon: Icons.search,
              label: 'تحقیق',
              color: const Color(0xFF2196F3),
              onPressed: () => _performNightAction('investigate'),
            ),
            _buildNightActionButton(
              icon: Icons.visibility,
              label: 'مشاهده',
              color: const Color(0xFF4CAF50),
              onPressed: () => _performNightAction('observe'),
            ),
            _buildNightActionButton(
              icon: Icons.psychology,
              label: 'تحلیل',
              color: const Color(0xFF9C27B0),
              onPressed: () => _performNightAction('analyze'),
            ),
          ],
        );
      
      case 'sniper':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
            _buildNightActionButton(
              icon: Icons.gps_fixed,
              label: 'شلیک',
              color: const Color(0xFF8B0000),
              onPressed: () => _performNightAction('shoot'),
            ),
            _buildNightActionButton(
              icon: Icons.visibility,
              label: 'مشاهده',
              color: const Color(0xFF4CAF50),
              onPressed: () => _performNightAction('observe'),
            ),
            _buildNightActionButton(
              icon: Icons.psychology,
              label: 'تحلیل',
              color: const Color(0xFF9C27B0),
              onPressed: () => _performNightAction('analyze'),
            ),
          ],
        );
      
      default:
        // برای شهروندان عادی
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNightActionButton(
              icon: Icons.visibility,
              label: 'مشاهده',
              color: const Color(0xFF4CAF50),
              onPressed: () => _performNightAction('observe'),
            ),
            _buildNightActionButton(
              icon: Icons.psychology,
              label: 'تحلیل',
              color: const Color(0xFF9C27B0),
              onPressed: () => _performNightAction('analyze'),
            ),
            _buildNightActionButton(
              icon: Icons.nightlight_round,
              label: 'استراحت',
              color: const Color(0xFF607D8B),
              onPressed: () => _performNightAction('rest'),
            ),
          ],
        );
    }
  }

  Widget _buildNightActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final buttonWidth = (screenWidth - 40 - 16) / 3; // عرض منو منهای padding و فاصله‌ها تقسیم بر 3
        
        return Container(
          width: buttonWidth,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final buttonWidth = (screenWidth - 40 - 16) / 3; // عرض منو منهای padding و فاصله‌ها تقسیم بر 3
        
        return Container(
          width: buttonWidth,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(0.6),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isCurrentUserSpeaking() {
    if (_tableInfo?.currentSpeaker == null) return false;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.authData?.user;
    
    return _tableInfo!.currentSpeaker!.username == currentUser?.username;
  }

  void _performNightAction(String action) {
    print('🌙 Performing night action: $action');
    
    switch (action) {
      case 'kill':
        _showPlayerSelectionDialog('انتخاب هدف برای کشتن', (player) async {
          await _sendNightAction('mafia_kill', player.username);
        });
        break;
      case 'heal':
        _showPlayerSelectionDialog('انتخاب بازیکن برای درمان', (player) async {
          await _sendNightAction('doctor_save', player.username);
        });
        break;
      case 'investigate':
        _showPlayerSelectionDialog('انتخاب بازیکن برای تحقیق', (player) async {
          await _sendNightAction('detective_investigate', player.username);
        });
        break;
      case 'shoot':
        _showPlayerSelectionDialog('انتخاب هدف برای شلیک', (player) async {
          await _sendNightAction('sniper_shot', player.username);
        });
        break;
      case 'observe':
        // مشاهده عمومی - نیازی به انتخاب بازیکن نیست
        _sendNightAction('observe', null);
        break;
      case 'analyze':
        // تحلیل - نیازی به انتخاب بازیکن نیست
        _sendNightAction('analyze', null);
        break;
      case 'rest':
        // استراحت - نیازی به انتخاب بازیکن نیست
        _sendNightAction('rest', null);
        break;
    }
  }
  
  Future<void> _sendNightAction(String actionType, String? targetUsername) async {
    try {
      print('🌙 Sending night action: $actionType -> $targetUsername');
      await _gameService.nightAction(actionType, targetUsername: targetUsername);
      print('✅ Night action sent successfully');
      
      // به‌روزرسانی اطلاعات بازی
      _loadTableInfo();
    } catch (e) {
      print('❌ Error sending night action: $e');
      // نمایش پیام خطا به کاربر
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(context, 'خطا در ارسال اقدام: $e');
      }
    }
  }

  void _showPlayerSelectionDialog(String title, Function(PlayerSeat) onPlayerSelected) {
    final alivePlayers = _tableInfo!.players.where((player) => player.isAlive).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alivePlayers.length,
            itemBuilder: (context, index) {
              final player = alivePlayers[index];
              final seatNumber = _tableInfo!.players.indexOf(player) + 1;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: player.avatarUrl != null 
                      ? NetworkImage(player.avatarUrl!) 
                      : null,
                  child: player.avatarUrl == null 
                      ? Text(player.username.isNotEmpty ? player.username[0].toUpperCase() : '?')
                      : null,
                ),
                title: Text(player.username),
                subtitle: Text('صندلی $seatNumber'),
                onTap: () {
                  Navigator.pop(context);
                  onPlayerSelected(player);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
            ),
        ],
      ),
    );
  }

  void _onPlayerTap(PlayerSeat player) {
    final seatNumber = _tableInfo!.players.indexOf(player) + 1;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(player.username),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('شماره صندلی: $seatNumber'),
            const SizedBox(height: 8),
            Text('وضعیت: ${player.isAlive ? 'زنده' : 'مرده'}'),
            if (player.isSpeaking) const Text('در حال صحبت'),
            if (player.reactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('واکنش‌ها:'),
              if (player.reactions['likes'] != null && player.reactions['likes']! > 0)
                Text('👍 ${player.reactions['likes']}'),
              if (player.reactions['dislikes'] != null && player.reactions['dislikes']! > 0)
                Text('👎 ${player.reactions['dislikes']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }


  Future<void> _endSpeaking() async {
    try {
      await _gameService.endSpeaking();
      _loadTableInfo();
    } catch (e) {
      _showError('خطا در پایان صحبت: $e');
    }
  }

  Future<void> _challengeSpeaking() async {
    try {
      await _gameService.challengeSpeaking();
      _loadTableInfo();
    } catch (e) {
      _showError('خطا در چالش: $e');
    }
  }

  Future<void> _addReaction(String reactionType) async {
    if (_tableInfo?.currentSpeaker?.id == null) return;
    
    try {
      await _gameService.addSpeakingReaction(reactionType, _tableInfo!.currentSpeaker!.id!);
      _loadTableInfo();
    } catch (e) {
      _showError('خطا در ارسال واکنش: $e');
    }
  }


  void _showError(String message) {
    SnackBarHelper.showErrorSnackBar(context, message);
  }

  void _triggerReactionAnimation(String playerUsername, String reactionType) {
    // Cancel existing animation if any
    if (_reactionAnimations.containsKey(playerUsername)) {
      _reactionAnimations[playerUsername]!.dispose();
    }
    
    // Create new animation controller
    final controller = AnimationController(
      duration: const Duration(milliseconds: 3000), // 3 seconds
      vsync: this,
    );
    
    _reactionAnimations[playerUsername] = controller;
    _playerReactionStates[playerUsername] = reactionType;
    
    // Start animation
    controller.forward().then((_) {
      // Reset after animation completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _playerReactionStates[playerUsername] = '';
          });
        }
      });
    });
    
    setState(() {});
  }

  void _setupReactionCallback() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.setReactionCallback((playerUsername, reactionType) {
      if (mounted) {
        _triggerReactionAnimation(playerUsername, reactionType);
      }
    });
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange),
              SizedBox(width: 8),
              Text('حالت دیباگ'),
            ],
          ),
          content: const Text(
            'آیا می‌خواهید بازی را ریست کنید؟\n\nاین عمل بازی را به حالت لابی برمی‌گرداند (مثل لحظه ورود از لابی به میز) و تمام بازیکنان به حالت آماده نیست برمی‌گردند.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetGameTable();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ریست کن'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetGameTable() async {
    try {
      // نمایش loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('در حال ریست کردن بازی...'),
              ],
            ),
          );
        },
      );

      // ریست کردن بازی از طریق GameProvider
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.resetGame();
      
      // بستن loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // نمایش پیام موفقیت
      SnackBarHelper.showSuccessSnackBar(context, 'بازی با موفقیت ریست شد - بازگشت به لابی');

      // بازگشت به لابی
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/lobby');
      }

    } catch (e) {
      // بستن loading dialog در صورت خطا
      if (mounted) {
        Navigator.pop(context);
      }

      // نمایش خطا
      SnackBarHelper.showErrorSnackBar(context, 'خطا در ریست کردن بازی: $e');
      
      print('❌ Error resetting game: $e');
    }
  }
}

class TablePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown[700]!.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw table edge
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;
    
    canvas.drawCircle(center, radius, paint);
    
    // Draw some decorative lines
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final startX = center.dx + radius * cos(angle);
      final startY = center.dy + radius * sin(angle);
      final endX = center.dx + (radius + 20) * cos(angle);
      final endY = center.dy + (radius + 20) * sin(angle);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
