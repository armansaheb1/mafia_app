import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/table_info.dart';
import '../services/game_service.dart';

class GameTableScreen extends StatefulWidget {
  const GameTableScreen({super.key});

  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen> {
  final GameService _gameService = GameService();
  GameTableInfo? _tableInfo;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTableInfo();
    });
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadTableInfo();
      }
    });
  }

  Future<void> _loadTableInfo() async {
    try {
      final data = await _gameService.getGameTableInfo();
      
      if (mounted) {
        setState(() {
          _tableInfo = GameTableInfo.fromJson(data);
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have a room first
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.currentRoom == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('میز بازی'),
          backgroundColor: const Color(0xFF1a1a1a),
          foregroundColor: const Color(0xFFFFD700),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'اتاق بازی یافت نشد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'ابتدا وارد یک اتاق شوید',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
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
      return const Scaffold(
        body: Center(
          child: Text('اطلاعات میز یافت نشد'),
        ),
      );
    }

    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Scaffold(
          appBar: _buildAppBar(gameProvider),
          body: _buildTableLayout(gameProvider),
          bottomNavigationBar: _buildControls(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(GameProvider gameProvider) {
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night';
    
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

  Widget _buildTableLayout(GameProvider gameProvider) {
    final gameState = gameProvider.currentGameState;
    final isNightPhase = gameState?.phase == 'night';
    
    return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: _tableInfo!.tableImageUrl != null
                ? DecorationImage(
                    image: NetworkImage(_tableInfo!.tableImageUrl!),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      print('❌ Error loading table image: $exception');
                    },
                  )
                : null,
            color: _tableInfo!.tableImageUrl == null ? Colors.brown[300] : null,
          ),
          child: Stack(
            children: [
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

  Widget _buildPlayerSeat(PlayerSeat player) {
    final screenSize = MediaQuery.of(context).size;
    final x = player.seatPosition.x * screenSize.width;
    final y = player.seatPosition.y * screenSize.height;
    
    // Debug print
    print('🎯 Player: ${player.username}, Position: (${x}, ${y}), Screen: ${screenSize.width}x${screenSize.height}');
    
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: player.isSpeaking 
                      ? [const Color(0xFF8B0000), const Color(0xFF5D0000)] // قرمز مافیا گرادیانت
                      : [const Color(0xFF2C2C2C), const Color(0xFF1a1a1a)], // خاکستری مافیا گرادیانت
                ),
                border: Border.all(
                  color: player.isSpeaking 
                      ? const Color(0xFFFFD700) // طلایی
                      : const Color(0xFF404040), // خاکستری روشن
                  width: player.isSpeaking ? 3 : 2,
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
                    child: player.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              player.avatarUrl!,
                              width: 75,
                              height: 75,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(player.username);
                              },
                            ),
                          )
                        : _buildDefaultAvatar(player.username),
                  ),
                  
                  // شماره صندلی
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      width: 28,
                      height: 28,
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
                  if (player.isSpeaking)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 22,
                        height: 22,
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
            ),
            
            // نام کاربری - چسبیده به دایره
            Transform.translate(
              offset: const Offset(0, -10), // 10 پیکسل بالاتر (5+5)
              child: Container(
                width: 100,
                height: 25,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: player.isSpeaking 
                        ? [const Color(0xFF8B0000).withOpacity(0.6), const Color(0xFF5D0000).withOpacity(0.8)]
                        : [const Color(0xFF2C2C2C).withOpacity(0.6), const Color(0xFF1a1a1a).withOpacity(0.8)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: player.isSpeaking 
                        ? const Color(0xFFFFD700).withOpacity(0.5)
                        : const Color(0xFF404040).withOpacity(0.5),
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
      width: 75,
      height: 75,
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
            Text('عکس میز: ${_tableInfo?.tableImageUrl != null ? 'موجود' : 'ناموجود'}'),
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

  Widget _buildControls() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final gameState = gameProvider.currentGameState;
        final isNightPhase = gameState?.phase == 'night';
        final userRole = gameState?.playerRole;
        
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
              if (_tableInfo!.currentSpeaker != null)
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
      },
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
      height: 50,
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
          height: 55,
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
          height: 50,
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

  void _performNightAction(String action) {
    // TODO: پیاده‌سازی عملیات شب
    switch (action) {
      case 'kill':
        _showPlayerSelectionDialog('انتخاب هدف برای کشتن', (player) {
          // ارسال درخواست کشتن به سرور
          print('کشتن: ${player.username}');
        });
        break;
      case 'heal':
        _showPlayerSelectionDialog('انتخاب بازیکن برای درمان', (player) {
          // ارسال درخواست درمان به سرور
          print('درمان: ${player.username}');
        });
        break;
      case 'investigate':
        _showPlayerSelectionDialog('انتخاب بازیکن برای تحقیق', (player) {
          // ارسال درخواست تحقیق به سرور
          print('تحقیق: ${player.username}');
        });
        break;
      case 'shoot':
        _showPlayerSelectionDialog('انتخاب هدف برای شلیک', (player) {
          // ارسال درخواست شلیک به سرور
          print('شلیک: ${player.username}');
        });
        break;
      case 'observe':
        // مشاهده عمومی - نیازی به انتخاب بازیکن نیست
        print('مشاهده محیط');
        break;
      case 'analyze':
        // تحلیل - نیازی به انتخاب بازیکن نیست
        print('تحلیل وضعیت');
        break;
      case 'rest':
        // استراحت - نیازی به انتخاب بازیکن نیست
        print('استراحت');
        break;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
