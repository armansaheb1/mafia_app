import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../services/websocket_service.dart';
import '../utils/snackbar_helper.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final WebSocketService _webSocketService = WebSocketService();
  
  bool _isReady = false;
  bool _isDisposed = false;
  bool _isWebSocketConnected = false;
  String? _connectionError;
  List<Map<String, dynamic>> _players = [];
  final List<Map<String, String>> _chatMessages = [];
  StreamSubscription? _webSocketSubscription;
  
  // Countdown variables
  int _countdownSeconds = 0;
  bool _isCountdownActive = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _setupWebSocket();
    
    // Check if countdown should start automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndStartCountdown();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if countdown should start automatically when players change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndStartCountdown();
      }
    });
  }

  Future<void> _setupWebSocket() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final room = gameProvider.currentRoom;
    
    if (room == null) {
      _showError('اتاقی یافت نشد');
      return;
    }

    try {
      print('🔌 Connecting to WebSocket for room: ${room.name}');
      
      // Cancel any existing subscription
      await _webSocketSubscription?.cancel();
      _webSocketSubscription = null;
      
      await _webSocketService.connectToRoom(room.name);
      
      if (_webSocketService.isConnected) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isWebSocketConnected = true;
            _connectionError = null;
          });
        }
        
        // گوش دادن به پیام‌های WebSocket
        _webSocketSubscription = _webSocketService.messages.listen(
          (message) {
            if (mounted && !_isDisposed) {
              _handleWebSocketMessage(message);
            }
          },
          onError: (error) {
            print('❌ WebSocket stream error: $error');
            if (mounted && !_isDisposed) {
              setState(() {
                _isWebSocketConnected = false;
                _connectionError = 'خطا در اتصال: $error';
              });
            }
          },
          onDone: () {
            print('🔌 WebSocket connection closed');
            if (mounted && !_isDisposed) {
              setState(() {
                _isWebSocketConnected = false;
                _connectionError = 'اتصال قطع شد';
              });
            }
          },
        );
        
        print('✅ WebSocket connected successfully');
      } else {
        throw Exception('WebSocket connection failed');
      }
      
    } catch (e) {
      print('❌ WebSocket connection failed: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isWebSocketConnected = false;
          _connectionError = 'خطا در اتصال: $e';
        });
      }
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      print('📨 Received WebSocket message: $message');
      
      final data = jsonDecode(message);
      final type = data['type'];
      
      switch (type) {
        case 'lobby_state':
          _handleLobbyState(data);
          break;
          
        case 'lobby_update':
          _handleLobbyUpdate(data);
          break;
          
        case 'player_ready':
          _handlePlayerReady(data);
          break;
          
        case 'chat_message':
          _handleChatMessage(data);
          break;
          
        case 'connection_established':
          print('✅ Connection established message received');
          if (mounted) {
            setState(() {
              _isWebSocketConnected = true;
              _connectionError = null;
            });
          }
          break;
          
        case 'countdown_start':
          _handleCountdownStart(data);
          break;
          
        case 'countdown_update':
          _handleCountdownUpdate(data);
          break;
          
        case 'countdown_cancelled':
          _handleCountdownCancelled(data);
          break;
          
        case 'game_started':
          _handleGameStarted(data);
          break;
          
        default:
          print('⚠️ Unknown message type: $type');
      }
      
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }

  void _handleLobbyState(Map<String, dynamic> data) {
    print('📋 Handling lobby_state: $data');
    if (mounted) {
      setState(() {
        _players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      });
    }
    print('✅ Updated players list: ${_players.length} players');
  }

  void _handleLobbyUpdate(Map<String, dynamic> data) {
    print('📋 Handling lobby_update: $data');
    if (mounted) {
      setState(() {
        _players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      });
    }
    
    if (data.containsKey('message')) {
      _addChatMessage('سیستم', data['message']);
    }
    print('✅ Updated players list: ${_players.length} players');
    
    // Check if countdown should start automatically after lobby update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndStartCountdown();
      }
    });
  }

  void _handlePlayerReady(Map<String, dynamic> data) {
    final username = data['username'];
    final isReady = data['is_ready'];
    
    if (mounted) {
      setState(() {
        final playerIndex = _players.indexWhere((p) => p['username'] == username);
        if (playerIndex != -1) {
          _players[playerIndex]['is_ready'] = isReady;
        }
      });
    }
    
    _addChatMessage('سیستم', '$username ${isReady ? 'آماده' : 'آماده نیست'} شد');
    
    // Check if countdown should start automatically after player ready status change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartCountdown();
    });
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    final username = data['username'];
    final message = data['message'];
    _addChatMessage(username, message);
  }

  void _addChatMessage(String username, String message) {
    if (mounted) {
      setState(() {
        _chatMessages.add({
          'username': username,
          'message': message,
          'timestamp': DateTime.now().toString(),
        });
      });
    }
    _scrollChatToBottom();
  }

  void _handleCountdownStart(Map<String, dynamic> data) {
    final seconds = data['seconds'] as int;
    final message = data['message'] as String;
    
    if (mounted) {
      setState(() {
        _countdownSeconds = seconds;
        _isCountdownActive = true;
      });
    }
    
    _addChatMessage('سیستم', message);
    _startCountdownTimer();
  }

  void _handleCountdownUpdate(Map<String, dynamic> data) {
    final seconds = data['seconds'] as int;
    final message = data['message'] as String;
    
    if (mounted) {
      setState(() {
        _countdownSeconds = seconds;
      });
    }
    
    _addChatMessage('سیستم', message);
  }

  void _handleCountdownCancelled(Map<String, dynamic> data) {
    final message = data['message'] as String;
    
    if (mounted) {
      setState(() {
        _isCountdownActive = false;
        _countdownSeconds = 0;
      });
    }
    
    _addChatMessage('سیستم', message);
    _stopCountdownTimer();
  }

  void _handleGameStarted(Map<String, dynamic> data) {
    final message = data['message'] as String;
    _addChatMessage('سیستم', message);
    
    // Stop countdown timer
    _stopCountdownTimer();
    
    if (mounted) {
      setState(() {
        _isCountdownActive = false;
        _countdownSeconds = 0;
      });
    }
    
    // Navigate to game table screen immediately
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/game-table');
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;
    
    if (_isWebSocketConnected) {
      _webSocketService.sendMessage('chat_message', _chatController.text.trim());
      _addChatMessage('شما', _chatController.text.trim());
      _chatController.clear();
    } else {
      _showError('اتصال برقرار نیست');
    }
  }

  void _toggleReady() {
    if (_isDisposed || !_isWebSocketConnected) return;
    
    if (mounted) {
      setState(() {
        _isReady = !_isReady;
      });
    }
    
    _webSocketService.sendMessage('player_ready', '');
  }

  Future<void> _leaveRoom() async {
    try {
      _showSnackBar('در حال خروج از اتاق...');
      
      // Disconnect WebSocket before leaving
      await _webSocketService.disconnect();
      
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.leaveRoom();
      
      if (mounted && !_isDisposed) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      _showError('خطا در خروج از اتاق: $e');
    }
  }

  void _reconnectWebSocket() {
    if (mounted) {
      setState(() {
        _connectionError = null;
      });
    }
    _setupWebSocket();
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _connectionError = message;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted && !_isDisposed) {
      SnackBarHelper.showInfoSnackBar(context, message);
    }
  }

  void _startCountdownTimer() {
    _stopCountdownTimer(); // Stop any existing timer
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isCountdownActive && _countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
        
        if (_countdownSeconds <= 0) {
          _stopCountdownTimer();
          _startGameAfterCountdown();
        }
      } else {
        _stopCountdownTimer();
      }
    });
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _startGameAfterCountdown() {
    print('🎮 Starting game after countdown...');
    
    // ارسال پیام WebSocket برای شروع بازی
    _webSocketService.sendMessage('start_game', '');
    
    // اضافه کردن پیام به چت
    _addChatMessage('سیستم', 'بازی شروع شد!');
    
    // Navigate to game table screen
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/game-table');
    }
  }

  void _checkAndStartCountdown() {
    if (!mounted) return; // Check if widget is still mounted
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final players = gameProvider.currentPlayers;
    
    if (players.length >= 4) {
      final readyPlayers = players.where((player) => player.isReady).length;
      if (readyPlayers >= 4 && !_isCountdownActive) {
        // Start countdown automatically
        _startAutoCountdown();
      }
    }
  }

  void _startAutoCountdown() {
    if (!mounted) return; // Check if widget is still mounted
    
    setState(() {
      _countdownSeconds = 5; // 5 seconds countdown
      _isCountdownActive = true;
    });
    
    _addChatMessage('سیستم', 'همه بازیکنان آماده هستند! بازی در 5 ثانیه شروع می‌شود...');
    _startCountdownTimer();
    
    // Start the game after countdown
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isCountdownActive) {
        _startGame();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Cancel WebSocket subscription
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    
    // Stop countdown timer
    _stopCountdownTimer();
    
    _chatController.dispose();
    _scrollController.dispose();
    
    // Only disconnect if we're actually leaving the room
    // Don't disconnect on widget disposal as it might be temporary
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          gameProvider.currentRoom?.name ?? 'لابی بازی',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1a1a1a),
        foregroundColor: const Color(0xFFFFD700),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveRoom,
            tooltip: 'خروج از اتاق',
            color: const Color(0xFFFFD700),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a1a1a),
                    Color(0xFF2C2C2C),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // اطلاعات اتاق
                  _buildRoomInfoCard(gameProvider),
                  
                  // نمایش خطای اتصال
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _connectionError != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _buildErrorCard(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  
                  // وضعیت آماده‌باش
                  _buildReadyStatusCard(),
                  
                  // دکمه شروع بازی
                  _buildStartGameButtonInline(),
                  
                  // محتوای اصلی
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive layout based on screen height
                        final isSmallScreen = constraints.maxHeight < 600;
                        final isMediumScreen = constraints.maxHeight >= 600 && constraints.maxHeight < 800;
                        
                        return Column(
                          children: [
                            // لیست بازیکنان
                            Expanded(
                              flex: isSmallScreen ? 3 : (isMediumScreen ? 4 : 3),
                              child: _buildPlayersList(),
                            ),
                            
                            SizedBox(height: isSmallScreen ? 6 : 12),
                            
                            // چت
                            Expanded(
                              flex: isSmallScreen ? 3 : (isMediumScreen ? 4 : 3),
                              child: _buildChatSection(),
                            ),
                            
                            SizedBox(height: isSmallScreen ? 6 : 12),
                            
                            // دکمه خروج از لابی
                            _buildLeaveRoomButton(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Timer overlay
            if (_isCountdownActive)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: _buildCountdownCard(),
                          ),
                        ),
                      ),
                      // Close button (optional - only show if countdown is not critical)
                      if (_countdownSeconds > 3)
                        Positioned(
                          top: 50,
                          right: 20,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: 0.7,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isCountdownActive = false;
                                  _countdownSeconds = 0;
                                });
                                _stopCountdownTimer();
                              },
                              tooltip: 'بستن تایمر',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard(GameProvider gameProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2C2C),
            const Color(0xFF3C3C3C),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: Colors.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${_players.length}/${gameProvider.currentRoom?.maxPlayers ?? 8}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                _isWebSocketConnected ? Icons.wifi : Icons.wifi_off,
                color: _isWebSocketConnected ? Colors.green : Colors.red,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isWebSocketConnected ? 'متصل' : 'قطع',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isWebSocketConnected ? Colors.green : Colors.red,
                ),
              ),
              if (!_isWebSocketConnected) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _reconnectWebSocket,
                  tooltip: 'تلاش مجدد برای اتصال',
                  color: Colors.blue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildErrorCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B0000).withOpacity(0.15),
            const Color(0xFFDC143C).withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.6),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: const Color(0xFFFFD700),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _connectionError!,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _connectionError = null),
              color: const Color(0xFFFFD700),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2C2C),
            const Color(0xFF3C3C3C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isReady 
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : const Color(0xFF8B0000).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isReady 
                ? const Color(0xFFFFD700).withOpacity(0.2)
                : const Color(0xFF8B0000).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isReady 
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isReady 
                        ? const Color(0xFFFFD700)
                        : Colors.white54,
                    width: 2,
                  ),
                ),
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 500),
                  turns: _isReady ? 0.0 : 0.25,
                  child: Icon(
                    Icons.check_circle_outline,
                    color: _isReady ? const Color(0xFFFFD700) : Colors.white54,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'وضعیت آماده‌باش:',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isReady ? const Color(0xFFFFD700) : Colors.white54,
                ),
                child: Text(_isReady ? 'آماده' : 'آماده نیستم'),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isReady ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Switch(
                  value: _isReady,
                  onChanged: _isWebSocketConnected ? (value) => _toggleReady() : null,
                  thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFFFFD700);
                    }
                    return const Color(0xFF404040);
                  }),
                  trackColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF8B0000).withOpacity(0.6);
                    }
                    return const Color(0xFF404040).withOpacity(0.3);
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2C2C),
            const Color(0xFF3C3C3C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: const Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                Text(
                  'بازیکنان اتاق (${_players.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _players.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'هیچ بازیکنی در اتاق نیست',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _players.length,
                    itemBuilder: (context, index) {
                      final player = _players[index];
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final currentUser = authProvider.authData?.user;
                      final isCurrentUser = player['username'] == (currentUser?.username ?? '');
                      final isReady = player['is_ready'] == true;
                      
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isCurrentUser 
                                ? [
                                    const Color(0xFF8B0000).withOpacity(0.3),
                                    const Color(0xFFDC143C).withOpacity(0.2),
                                  ]
                                : [
                                    const Color(0xFF404040).withOpacity(0.4),
                                    const Color(0xFF505050).withOpacity(0.3),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentUser 
                                ? const Color(0xFFFFD700).withOpacity(0.6)
                                : const Color(0xFF8B0000).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isCurrentUser 
                                  ? const Color(0xFFFFD700).withOpacity(0.2)
                                  : Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: isReady ? [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ] : null,
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: isReady 
                                  ? const Color(0xFFFFD700) 
                                  : const Color(0xFF404040),
                              child: Text(
                                (player['username'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF1a1a1a),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          title: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                              color: isCurrentUser ? const Color(0xFFFFD700) : Colors.white,
                              fontSize: 16,
                            ),
                            child: Text(player['username'] ?? 'Unknown'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrentUser)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFFD700).withOpacity(0.3),
                                        const Color(0xFFFFD700).withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700).withOpacity(0.6),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD700).withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'شما',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFFFD700),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  isReady ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isReady 
                                      ? const Color(0xFFFFD700) 
                                      : Colors.white54,
                                  size: 24,
                                  key: ValueKey(isReady),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRoomButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _leaveRoom,
          icon: const Icon(Icons.exit_to_app, size: 22),
          label: const Text(
            'خروج از اتاق',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000),
            foregroundColor: const Color(0xFFFFD700),
            elevation: 6,
            shadowColor: const Color(0xFF8B0000).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2C2C),
            const Color(0xFF3C3C3C),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat, color: const Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'چت اتاق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'هیچ پیامی وجود ندارد',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'اولین پیام را ارسال کنید!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      final isSystemMessage = message['username'] == 'سیستم';
                      final isMyMessage = message['username'] == 'شما';
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Row(
                          mainAxisAlignment: isMyMessage 
                              ? MainAxisAlignment.end 
                              : MainAxisAlignment.start,
                          children: [
                            if (!isMyMessage && !isSystemMessage)
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF8B0000).withOpacity(0.3),
                                child: Text(
                                  (message['username'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSystemMessage
                                      ? const Color(0xFF8B0000).withOpacity(0.3)
                                      : isMyMessage
                                          ? const Color(0xFFFFD700).withOpacity(0.2)
                                          : const Color(0xFF404040).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSystemMessage
                                        ? const Color(0xFF8B0000).withOpacity(0.5)
                                        : isMyMessage
                                            ? const Color(0xFFFFD700).withOpacity(0.3)
                                            : const Color(0xFF8B0000).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isSystemMessage)
                                      Text(
                                        message['username'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isMyMessage ? const Color(0xFFFFD700) : Colors.white70,
                                        ),
                                      ),
                                    Text(
                                      message['message'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSystemMessage ? const Color(0xFFFFD700) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B0000).withOpacity(0.1),
                  const Color(0xFFDC143C).withOpacity(0.05),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF8B0000).withOpacity(0.3),
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _isWebSocketConnected 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isWebSocketConnected 
                            ? const Color(0xFF8B0000).withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _chatController,
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        enabled: _isWebSocketConnected,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      onSubmitted: _isWebSocketConnected ? (_) => _sendChatMessage() : null,
                      maxLines: null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: _isWebSocketConnected 
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF4CAF50),
                              const Color(0xFF2E7D32),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey[600]!,
                              Colors.grey[700]!,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _isWebSocketConnected ? [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isWebSocketConnected ? _sendChatMessage : null,
                    tooltip: 'ارسال پیام',
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartGameButtonInline() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.authData?.user;
    
    final isHost = gameProvider.isRoomHost(currentUser?.username ?? '');
    
    // Use _players from WebSocket instead of gameProvider.currentPlayers
    final readyPlayers = _players.where((p) => p['is_ready'] == true).length;
    final totalPlayers = _players.length;
    final canStart = readyPlayers >= 4;

    // Only show button to host
    if (!isHost) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Status info card
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: !canStart
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B0000).withOpacity(0.15),
                          const Color(0xFFDC143C).withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF8B0000).withOpacity(0.4),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B0000).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: const Color(0xFFFFD700),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'برای شروع بازی حداقل 4 بازیکن آماده نیاز است ($readyPlayers/$totalPlayers)',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          
          const SizedBox(height: 12),
          
          // Start game button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: canStart ? [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ] : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canStart && _isWebSocketConnected ? _showStartGameDialog : null,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    canStart ? Icons.play_arrow : Icons.hourglass_empty,
                    size: 24,
                    key: ValueKey(canStart),
                  ),
                ),
                label: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  child: Text(
                    canStart ? 'شروع بازی' : 'منتظر بازیکنان...',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canStart ? const Color(0xFF4CAF50) : const Color(0xFF404040),
                  foregroundColor: Colors.white,
                  elevation: canStart ? 6 : 2,
                  shadowColor: canStart ? const Color(0xFF4CAF50).withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showStartGameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Row(
          children: [
            Icon(Icons.play_arrow, color: const Color(0xFFFFD700)),
            const SizedBox(width: 8),
            const Text(
              'شروع بازی',
              style: TextStyle(color: Color(0xFFFFD700)),
            ),
          ],
        ),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید بازی را شروع کنید؟',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لغو',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('شروع بازی'),
          ),
        ],
      ),
    );
  }

  Future<void> _startGame() async {
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.startGame();
      
      // Navigate to game table screen after successful start
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/game-table');
      }
    } catch (e) {
      _showError('خطا در شروع بازی: $e');
    }
  }

  Widget _buildCountdownCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final padding = isSmallScreen ? 16.0 : 20.0;
        final circleSize = isSmallScreen ? 100.0 : 120.0;
        final fontSize = isSmallScreen ? 28.0 : 36.0;
        final largeFontSize = isSmallScreen ? 32.0 : 40.0;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50),
            const Color(0xFF2E7D32),
            const Color(0xFF1B5E20),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.6),
            blurRadius: 25,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedRotation(
                  duration: const Duration(seconds: 2),
                  turns: _countdownSeconds / 10.0,
                  child: Icon(
                    Icons.timer,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'بازی در حال شروع...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Circular progress indicator with countdown
          Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              
              // Progress circle
              SizedBox(
                width: circleSize,
                height: circleSize,
                child: CircularProgressIndicator(
                  value: _countdownSeconds / 5.0, // Assuming 5 second countdown
                  strokeWidth: isSmallScreen ? 4 : 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              
              // Countdown number with animation
              AnimatedScale(
                scale: _countdownSeconds <= 3 ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _countdownSeconds <= 3 ? Colors.red[100] : Colors.white,
                    fontSize: _countdownSeconds <= 3 ? largeFontSize : fontSize,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text('$_countdownSeconds'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status text with animation
          AnimatedOpacity(
            opacity: _countdownSeconds <= 3 ? 0.8 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              _countdownSeconds <= 3 ? 'تقریباً شروع شد!' : 'ثانیه باقی مانده',
              style: TextStyle(
                color: _countdownSeconds <= 3 ? Colors.red[100] : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Pulsing dots animation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 600 + (index * 200)),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(
                    _countdownSeconds <= 3 ? 0.8 : 0.6,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
      },
    );
  }
}
