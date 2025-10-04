import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/game_service.dart';
import '../services/websocket_service.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../models/game_state.dart';

class GameProvider with ChangeNotifier {
  GameService? _gameService;
  final WebSocketService _webSocketService = WebSocketService();
  
  List<Room> _rooms = [];
  Room? _currentRoom;
  List<Player> _currentPlayers = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _gameSettings;
  bool _isWebSocketConnected = false;
  GameState? _currentGameState;
  String? _currentPhase;
  String? _userRole;
  bool _hasVoted = false;
  bool _hasNightAction = false;
  final List<Map<String, String>> _chatMessages = [];
  SharedPreferences? _prefs;
  Timer? _gameTimer;
  
  // Callback for reaction animations
  Function(String playerUsername, String reactionType)? _onReactionReceived;

  List<Room> get rooms => _rooms;
  Room? get currentRoom => _currentRoom;
  List<Player> get currentPlayers => _currentPlayers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isWebSocketConnected => _isWebSocketConnected;
  GameState? get currentGameState => _currentGameState;
  String? get currentPhase => _currentPhase;
  String? get userRole => _userRole;
  bool get hasVoted => _hasVoted;
  bool get hasNightAction => _hasNightAction;
  List<Map<String, String>> get chatMessages => _chatMessages;

  void initializeGameService(BuildContext context) {
    _gameService = GameService(context);
  }
  
  GameService get _gameServiceOrThrow {
    if (_gameService == null) throw Exception('GameService not initialized');
    return _gameService!;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadGameState();
  }

  Future<void> _loadGameState() async {
    if (_prefs == null) return;
    
    try {
      final roomName = _prefs!.getString('last_room');
      final phase = _prefs!.getString('last_phase');
      
      if (roomName != null && phase != null) {
        _currentPhase = phase;
      }
    } catch (e) {
      print('❌ Error loading game state: $e');
    }
  }

  Future<void> _saveGameState() async {
    if (_prefs == null || _currentRoom == null || _currentPhase == null) return;
    
    try {
      await _prefs!.setString('last_room', _currentRoom!.name);
      await _prefs!.setString('last_phase', _currentPhase!);
    } catch (e) {
      print('❌ Error saving game state: $e');
    }
  }

  Future<void> _clearSavedGameState() async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.remove('last_room');
      await _prefs!.remove('last_phase');
    } catch (e) {
      print('❌ Error clearing saved game state: $e');
    }
  }

  void _clearGameState() {
    _currentRoom = null;
    _currentGameState = null;
    _currentPhase = null;
    _userRole = null;
    _hasVoted = false;
    _hasNightAction = false;
    _chatMessages.clear();
    notifyListeners();
    
    _clearSavedGameState();
  }

  Future<void> fetchRooms() async {
    _setLoading(true);
    try {
      _setErrorMessage(null);
      final rooms = await _gameServiceOrThrow.getRooms();
      _setRooms(rooms);
    } catch (e) {
      _setErrorMessage(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createRoom(String name, int maxPlayers, bool isPrivate, [String password = '', int? scenarioId]) async {
    _setLoading(true);
    try {
      _setErrorMessage(null);
      final room = await _gameServiceOrThrow.createRoom(name, maxPlayers, isPrivate, password, scenarioId);
      _setCurrentRoom(room);
      
      _addPlayer(Player(
        id: 0,
        userId: 0,
        username: room.hostName,
        roomId: room.id,
        isAlive: true,
        isReady: true,
        joinedAt: DateTime.now(),
        votesReceived: 0,
        isProtected: false,
        specialActionsUsed: {},
      ));
      
    } catch (e) {
      _setErrorMessage(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> joinRoom(String roomName, [String password = '']) async {
    _setLoading(true);
    try {
      _setErrorMessage(null);
      
      if (_currentRoom != null) {
        await leaveRoom();
      }
      
      final result = await _gameServiceOrThrow.joinRoom(roomName, password);
      final room = result['room'] as Room;
      final player = result['player'] as Player;
      
      _setCurrentRoom(room);
      _addPlayer(player);
      
    } catch (e) {
      _setErrorMessage(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchLobby(int roomId) async {
    _setLoading(true);
    try {
      _setErrorMessage(null);
      final result = await _gameServiceOrThrow.getLobby(roomId);
      _setCurrentRoom(result['room'] as Room);
      _setCurrentPlayers(result['players'] as List<Player>);
    } catch (e) {
      _setErrorMessage(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> connectToWebSocket(String roomName) async {
    try {
      _setLoading(true);
      
      await _webSocketService.connectToRoom(roomName);
      _setWebSocketConnected(_webSocketService.isConnected);
      
      if (_webSocketService.isConnected) {
        _webSocketService.messages.listen(
          (message) {
            _handleWebSocketMessage(message);
          },
          onError: (error) {
            print('❌ WebSocket listener error: $error');
            _handleTemporaryDisconnect(); // استفاده از disconnect موقت
            _setErrorMessage('اتصال WebSocket قطع شد: $error');
            
            // تلاش برای اتصال مجدد بعد از 3 ثانیه
            Timer(const Duration(seconds: 3), () {
              if (_currentRoom != null && !_isWebSocketConnected) {
                print('🔄 Attempting to reconnect to WebSocket...');
                connectToWebSocket(_currentRoom!.name).catchError((e) {
                  print('❌ Reconnection failed: $e');
                });
              }
            });
          },
        );
      } else {
        throw Exception('WebSocket connection failed');
      }
      
    } catch (e) {
      _setErrorMessage('اتصال به اتاق ناموفق بود: $e');
      _setWebSocketConnected(false);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      final messageData = data['data'] ?? data['message'];
      final username = data['username'];

      switch (type) {
        case 'lobby_state':
        case 'lobby_update':
          _handleLobbyUpdate(data);
          break;
          
        case 'player_ready':
          _handlePlayerReady(data);
          break;
          
        case 'chat_message':
          _addChatMessage(username, messageData);
          break;

        case 'error':
          _setErrorMessage(messageData);
          _addChatMessage('خطا', messageData);
          break;

        case 'vote_cast':
          _addChatMessage('سیستم', '${data['voter']} به ${data['target']} رای داد');
          break;

        case 'night_action_taken':
          _addChatMessage('سیستم', '${data['player']} اقدام ${data['action_type']} انجام داد');
          break;

        case 'phase_ended':
          _handlePhaseEnded(data);
          break;

        case 'game_started':
          _handleGameStarted(data);
          break;
          
        case 'game_reset':
          _handleGameReset(data);
          break;
          
        case 'speaking_reaction_added':
          _handleSpeakingReaction(data);
          break;
      }
      
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }

  void _handleLobbyUpdate(Map<String, dynamic> data) {
    try {
      final players = data['players'] as List<dynamic>;
      final playersList = players.map((playerData) => Player.fromJson(playerData)).toList();
      _setCurrentPlayers(playersList);
      
      if (data.containsKey('message')) {
        _addChatMessage('سیستم', data['message']);
      }
    } catch (e) {
      print('❌ Error handling lobby update: $e');
    }
  }

  void _handlePlayerReady(Map<String, dynamic> data) {
    try {
      final username = data['username'];
      final isReady = data['is_ready'];
      final players = data['players'] as List<dynamic>;
      
      _updatePlayerReadyStatus(username, isReady);
      _setCurrentPlayers(players.map((p) => Player.fromJson(p)).toList());
      
      _addChatMessage('سیستم', '$username ${isReady ? 'آماده' : 'آماده نیست'} شد');
    } catch (e) {
      print('❌ Error handling player ready: $e');
    }
  }

  void sendReadyStatus() {
    _webSocketService.sendMessage('player_ready', '');
  }

  void sendChatMessage(String message) {
    _webSocketService.sendMessage('chat_message', message);
    _addChatMessage('شما', message);
  }

  Future<void> sendVote(String targetUsername, {String voteType = 'lynch'}) async {
    try {
      await _gameServiceOrThrow.vote(targetUsername, voteType: voteType);
      _webSocketService.sendMessage('vote', targetUsername);
    } catch (e) {
      _setErrorMessage('خطا در ارسال رای: $e');
    }
  }

  Future<void> sendNightAction(String actionType, {String? targetUsername}) async {
    try {
      await _gameServiceOrThrow.nightAction(actionType, targetUsername: targetUsername);
      _webSocketService.sendMessage('night_action', {
        'action_type': actionType,
        'target': targetUsername,
      });
    } catch (e) {
      _setErrorMessage('خطا در انجام اقدام شب: $e');
    }
  }

  Future<void> endPhase() async {
    if (_currentRoom == null) return;
    
    try {
      await _gameServiceOrThrow.endPhase(_currentRoom!.id);
      _webSocketService.sendMessage('end_phase', '');
    } catch (e) {
      _setErrorMessage('خطا در پایان فاز: $e');
    }
  }

  Future<void> startGame() async {
    if (_currentRoom == null) return;
    
    try {
      _setLoading(true);
      final result = await _gameServiceOrThrow.startGame(_currentRoom!.id);
      
      // Update game state with the response
      if (result.containsKey('game_state')) {
        final gameStateData = result['game_state'];
        _setCurrentPhase(gameStateData['phase']);
        _addChatMessage('سیستم', 'بازی شروع شد!');
        
        // Start game timer
        _startGameTimer();
      }
      
    } catch (e) {
      _setErrorMessage('خطا در شروع بازی: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshGameInfo() async {
    try {
      print('🔄 GameProvider: Refreshing game info...');
      final gameInfo = await _gameServiceOrThrow.getGameInfo();
      print('📊 GameProvider: Received game info: $gameInfo');
      
      // Debug each field individually
      print('🔍 Debugging JSON fields:');
      print('  - phase: ${gameInfo['phase']} (type: ${gameInfo['phase'].runtimeType})');
      print('  - day_number: ${gameInfo['day_number']} (type: ${gameInfo['day_number'].runtimeType})');
      print('  - phase_time_remaining: ${gameInfo['phase_time_remaining']} (type: ${gameInfo['phase_time_remaining'].runtimeType})');
      print('  - player_role: ${gameInfo['player_role']} (type: ${gameInfo['player_role'].runtimeType})');
      print('  - winner: ${gameInfo['winner']} (type: ${gameInfo['winner'].runtimeType})');
      print('  - alive_players: ${gameInfo['alive_players']} (type: ${gameInfo['alive_players'].runtimeType})');
      
      final gameState = GameState.fromJson(gameInfo);
      print('📊 GameProvider: Parsed game state:');
      print('  - phase: ${gameState.phase}');
      print('  - phaseTimeRemaining: ${gameState.phaseTimeRemaining}');
      print('  - playerRole: ${gameState.playerRole}');
      
      _setCurrentGameState(gameState);
      _setCurrentPhase(gameState.phase);
      
      // Update user role from game state
      if (gameState.playerRole != null) {
        _userRole = gameState.playerRole;
        print('📊 GameProvider: Updated user role to: $_userRole');
      }
      
      print('✅ GameProvider: Game state updated successfully');
    } catch (e) {
      print('❌ Error refreshing game info: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRoom?.status == 'in_progress') {
        // فقط برای بررسی نوبت صحبت تایمر داریم
        // refreshGameInfo(); // حذف شده تا فاز از WebSocket حفظ شود
      } else {
        timer.cancel();
      }
    });
  }

  void _stopGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  void returnToLobby() {
    _setCurrentPhase('waiting');
    _addChatMessage('سیستم', 'بازگشت به لابی');
  }

  bool canPerformNightAction() {
    return _currentPhase == 'night' && 
           _userRole != null && 
           _userRole != 'citizen' && 
           !_hasNightAction;
  }

  bool canVote() {
    return _currentPhase == 'day' && !_hasVoted;
  }

  bool canStartGame() {
    if (_currentRoom == null) return false;
    
    // Check if there are at least 4 ready players
    final readyPlayers = _currentPlayers.where((player) => player.isReady).length;
    return readyPlayers >= 4;
  }

  Future<void> leaveRoom() async {
    try {
      if (_currentRoom != null) {
        await _gameServiceOrThrow.leaveRoom(_currentRoom!.id);
      }
    } catch (e) {
      print('❌ Error in leaveRoom API call: $e');
    } finally {
      await _webSocketService.disconnect();
      _cleanup();
    }
  }

  // متد اضافی برای cleanup کامل هنگام بستن اپ
  Future<void> forceCleanup() async {
    try {
      await _webSocketService.disconnect();
    } catch (e) {
      print('❌ Error in force cleanup: $e');
    } finally {
      _cleanup();
    }
  }

  void _cleanup() {
    _stopGameTimer();
    _setWebSocketConnected(false);
    _clearGameState();
    _clearSavedGameState();
  }

  // متد برای disconnect موقت (بدون پاک کردن game state)
  void _handleTemporaryDisconnect() {
    _stopGameTimer();
    _setWebSocketConnected(false);
    // فقط تایمر را متوقف می‌کنیم، game state را پاک نمی‌کنیم
  }

  Future<void> checkActiveGame() async {
    try {
      _setLoading(true);
      final gameStatus = await _gameServiceOrThrow.checkGameStatus();
      
      if (gameStatus != null) {
        final room = Room.fromJson(gameStatus['room']);
        final gameState = GameState.fromJson(gameStatus['game_state']);
        
        _setCurrentRoom(room);
        _setCurrentGameState(gameState);
        _setCurrentPhase(gameState.phase);
        
        if (gameState.phase == 'finished') {
          _addChatMessage('سیستم', 'بازی قبلاً به پایان رسیده بود');
          _clearGameState();
        } else {
          // اگر بازی فعال است، WebSocket connection برقرار کن
          print('🎮 Active game found, connecting to WebSocket...');
          try {
            await connectToWebSocket(room.name);
            print('✅ WebSocket connected for active game');
          } catch (e) {
            print('⚠️ Could not connect to WebSocket for active game: $e');
            // ادامه می‌دهیم حتی اگر WebSocket وصل نشود
          }
        }
      } else {
        _clearGameState();
      }
    } catch (e) {
      print('❌ Error checking active game: $e');
      _clearGameState();
    } finally {
      _setLoading(false);
    }
  }

  // ========== Safe State Setters ==========
  void _setRooms(List<Room> rooms) {
    _rooms = rooms;
    notifyListeners();
  }

  void _setCurrentRoom(Room? room) {
    _currentRoom = room;
    notifyListeners();
    _saveGameState();
  }

  void _setCurrentPlayers(List<Player> players) {
    _currentPlayers = players;
    notifyListeners();
  }
  
  // Public method to set current players (for external access)
  void setCurrentPlayers(List<Player> players) {
    _setCurrentPlayers(players);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _setWebSocketConnected(bool connected) {
    _isWebSocketConnected = connected;
    notifyListeners();
  }

  void _setCurrentGameState(GameState? gameState) {
    _currentGameState = gameState;
    notifyListeners();
  }

  // Public method to set game state (for basic game state creation)
  void setCurrentGameState(GameState? gameState) {
    _setCurrentGameState(gameState);
  }

  void _setCurrentPhase(String? phase) {
    _currentPhase = phase;
    notifyListeners();
    _saveGameState();
  }

  // Public method to set phase (for basic game state creation)
  void setCurrentPhase(String? phase) {
    _setCurrentPhase(phase);
  }

  void _addPlayer(Player player) {
    if (!_currentPlayers.any((p) => p.username == player.username)) {
      _currentPlayers.add(player);
      notifyListeners();
    }
  }

  void _updatePlayerReadyStatus(String username, bool isReady) {
    final index = _currentPlayers.indexWhere((p) => p.username == username);
    if (index != -1) {
      _currentPlayers[index] = _currentPlayers[index].copyWith(isReady: isReady);
      notifyListeners();
    }
  }


  void _addChatMessage(String username, String message) {
    _chatMessages.add({
      'username': username,
      'message': message,
      'timestamp': DateTime.now().toString(),
    });
    notifyListeners();
  }

  void _handlePhaseEnded(Map<String, dynamic> data) {
    try {
      final gameInfo = data['game_info'] as Map<String, dynamic>;
      final gameState = GameState.fromJson(gameInfo);
      
      _setCurrentGameState(gameState);
      _setCurrentPhase(gameState.phase);
      
      if (gameState.winner != null) {
        _addChatMessage('سیستم', 'بازی تمام شد! برنده: ${gameState.winner}');
        _setCurrentPhase('finished');
      } else {
        _addChatMessage('سیستم', 'فاز ${gameState.phase} شروع شد');
      }
    } catch (e) {
      print('❌ Error handling phase ended: $e');
    }
  }

  void _handleGameStarted(Map<String, dynamic> data) {
    try {
      final message = data['message'] as String;
      
      // Check if we have game_info (new format) or game_state (old format)
      Map<String, dynamic>? gameData;
      if (data.containsKey('game_info')) {
        gameData = data['game_info'] as Map<String, dynamic>;
      } else if (data.containsKey('game_state')) {
        gameData = data['game_state'] as Map<String, dynamic>;
      }
      
      _addChatMessage('سیستم', message);
      
      if (gameData != null) {
        _setCurrentPhase(gameData['phase']);
        // Update game state if available
        if (gameData.containsKey('phase')) {
          _setCurrentGameState(GameState.fromJson(gameData));
        }
      }
      
      // Start game timer
      _startGameTimer();
      
      // Only refresh game info if we don't have complete game data from WebSocket
      if (gameData == null || !gameData.containsKey('phase')) {
        refreshGameInfo();
      }
      
      // Notify listeners that game has started (for navigation)
      notifyListeners();
    } catch (e) {
      print('❌ Error handling game started: $e');
    }
  }

  void _handleGameReset(Map<String, dynamic> data) {
    try {
      print('🔄 Handling game reset WebSocket message');
      
      final message = data['message'] as String;
      final gameInfo = data['game_info'] as Map<String, dynamic>;
      
      // ریست کردن وضعیت محلی
      _currentGameState = null;
      _hasVoted = false;
      _hasNightAction = false;
      _chatMessages.clear();
      
      // لغو تایمرها
      _gameTimer?.cancel();
      _gameTimer = null;
      
      // به‌روزرسانی اطلاعات جدید
      _currentPhase = gameInfo['phase'];
      _currentGameState = GameState.fromJson(gameInfo);
      
      // نمایش پیام سیستم
      _addChatMessage('سیستم', message);
      
      // شروع تایمر جدید
      _startGameTimer();
      
      // اطلاع به listeners
      notifyListeners();
      
      print('✅ Game reset handled successfully: phase=$_currentPhase');
      
    } catch (e) {
      print('❌ Error handling game reset: $e');
    }
  }

  void _handleSpeakingReaction(Map<String, dynamic> data) {
    try {
      final player = data['player'] as String;
      final targetPlayer = data['target_player'] as String;
      final reactionType = data['reaction_type'] as String;
      
      print('🎭 Speaking reaction received: $player -> $targetPlayer ($reactionType)');
      
      // Add chat message
      final reactionText = reactionType == 'like' ? '👍 لایک' : '👎 دیسلایک';
      _addChatMessage('سیستم', '$player $reactionText کرد $targetPlayer');
      
      // Trigger animation callback if set
      if (_onReactionReceived != null) {
        _onReactionReceived!(targetPlayer, reactionType);
      }
    } catch (e) {
      print('❌ Error handling speaking reaction: $e');
    }
  }

  void setReactionCallback(Function(String playerUsername, String reactionType)? callback) {
    _onReactionReceived = callback;
  }

  // ========== Debug Methods ==========
  Future<void> resetGame() async {
    try {
      print('🔄 resetGame() called - Starting reset process...');
      print('🔄 Calling reset game API...');
      
      // فراخوانی API ریست بازی
      final response = await _gameServiceOrThrow.resetGame();
      print('🔄 Reset API response: $response');
      
      if (response['success'] == true) {
        print('✅ Game reset API successful');
        
        // ریست کردن وضعیت محلی
        _currentGameState = null;
        _currentPhase = null;
        _userRole = null;
        _hasVoted = false;
        _hasNightAction = false;
        _chatMessages.clear();
        
        // لغو تایمرها
        _gameTimer?.cancel();
        _gameTimer = null;
        
        // پاک کردن اطلاعات ذخیره شده
        if (_prefs != null) {
          await _prefs!.remove('current_phase');
          await _prefs!.remove('user_role');
          await _prefs!.remove('game_state');
        }
        
        // به‌روزرسانی اطلاعات بازی از response
        if (response['game_info'] != null) {
          final gameInfo = response['game_info'];
          _currentPhase = gameInfo['phase'];
          _currentGameState = GameState.fromJson(gameInfo);
          print('🎮 Updated game state from API: phase=$_currentPhase');
        }
        
        // اطلاع به listeners
        notifyListeners();
        
        print('✅ Game reset completed successfully');
        
      } else {
        throw Exception('Reset API failed: ${response['message'] ?? 'Unknown error'}');
      }
      
    } catch (e) {
      print('❌ Error resetting game: $e');
      rethrow;
    }
  }

  // ========== Helper Methods ==========
  bool isRoomHost(String username) {
    return _currentRoom?.hostName == username;
  }
}