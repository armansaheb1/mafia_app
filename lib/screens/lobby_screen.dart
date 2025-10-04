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
        if (mounted) {
          setState(() {
            _isWebSocketConnected = true;
            _connectionError = null;
          });
        }
        
        // گوش دادن به پیام‌های WebSocket
        _webSocketSubscription = _webSocketService.messages.listen(
          _handleWebSocketMessage,
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
        title: const Text('لابی بازی'),
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
        child: Container(
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
            if (_connectionError != null)
              _buildErrorCard(),
            
            // وضعیت آماده‌باش
            _buildReadyStatusCard(),
            
            // دکمه شروع بازی
            _buildStartGameButtonInline(),
            
            // شمارنده شروع بازی
            if (_isCountdownActive)
              _buildCountdownCard(),
            
            // محتوای اصلی
            Expanded(
              child: Column(
                children: [
                  // لیست بازیکنان
                  Expanded(
                    flex: 1,
                    child: _buildPlayersList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // چت
                  Expanded(
                    flex: 1,
                    child: _buildChatSection(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // دکمه خروج از لابی
                  _buildLeaveRoomButton(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard(GameProvider gameProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.meeting_room,
                color: const Color(0xFFFFD700),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                gameProvider.currentRoom?.name ?? 'اتاق',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                icon: Icons.people,
                label: 'بازیکنان',
                value: '${_players.length}/${gameProvider.currentRoom?.maxPlayers ?? 8}',
                color: Colors.green,
              ),
              _buildInfoItem(
                icon: _isWebSocketConnected ? Icons.wifi : Icons.wifi_off,
                label: 'وضعیت',
                value: _isWebSocketConnected ? 'متصل' : 'قطع',
                color: _isWebSocketConnected ? Colors.green : Colors.red,
              ),
              if (!_isWebSocketConnected)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reconnectWebSocket,
                  tooltip: 'تلاش مجدد برای اتصال',
                  color: Colors.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B0000).withOpacity(0.1),
        border: Border.all(color: const Color(0xFF8B0000).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _connectionError!,
              style: const TextStyle(color: Color(0xFFFFD700)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _connectionError = null),
            color: const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B0000).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: _isReady ? const Color(0xFFFFD700) : Colors.white54,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'وضعیت آماده‌باش:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                _isReady ? 'آماده' : 'آماده نیستم',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isReady ? const Color(0xFFFFD700) : Colors.white54,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _isReady,
                onChanged: _isWebSocketConnected ? (value) => _toggleReady() : null,
                activeThumbColor: const Color(0xFFFFD700),
                activeTrackColor: const Color(0xFF8B0000).withOpacity(0.5),
                inactiveThumbColor: const Color(0xFF404040),
                inactiveTrackColor: const Color(0xFF404040).withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.3),
          width: 1,
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
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrentUser 
                              ? const Color(0xFF8B0000).withOpacity(0.2) 
                              : const Color(0xFF404040).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrentUser 
                                ? const Color(0xFFFFD700).withOpacity(0.5) 
                                : const Color(0xFF8B0000).withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: player['is_ready'] == true 
                                ? const Color(0xFFFFD700) 
                                : const Color(0xFF404040),
                            child: Text(
                              (player['username'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF1a1a1a),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            player['username'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                              color: isCurrentUser ? const Color(0xFFFFD700) : Colors.white,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrentUser)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700).withOpacity(0.5),
                                      width: 1,
                                    ),
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
                              const SizedBox(width: 8),
                              Icon(
                                player['is_ready'] == true 
                                    ? Icons.check_circle 
                                    : Icons.radio_button_unchecked,
                                color: player['is_ready'] == true 
                                    ? const Color(0xFFFFD700) 
                                    : Colors.white54,
                                size: 20,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _leaveRoom,
        icon: const Icon(Icons.exit_to_app, size: 20),
        label: const Text(
          'خروج از اتاق',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B0000),
          foregroundColor: const Color(0xFFFFD700),
          elevation: 4,
          shadowColor: const Color(0xFF8B0000).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withOpacity(0.3),
          width: 1,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'پیام خود را بنویسید...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      enabled: _isWebSocketConnected,
                    ),
                    onSubmitted: _isWebSocketConnected ? (_) => _sendChatMessage() : null,
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isWebSocketConnected ? Colors.blue[600] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isWebSocketConnected ? _sendChatMessage : null,
                    tooltip: 'ارسال پیام',
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (!canStart)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withOpacity(0.1),
                border: Border.all(color: const Color(0xFF8B0000).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: const Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'برای شروع بازی حداقل 4 بازیکن آماده نیاز است ($readyPlayers/$totalPlayers)',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canStart && _isWebSocketConnected ? _showStartGameDialog : null,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text(
                canStart ? 'شروع بازی' : 'منتظر بازیکنان...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart ? const Color(0xFF4CAF50) : const Color(0xFF404040),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: canStart ? const Color(0xFF4CAF50).withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'بازی در حال شروع...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '$_countdownSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ثانیه',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
