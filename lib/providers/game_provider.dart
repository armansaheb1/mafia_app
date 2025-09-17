import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/game_service.dart';
import '../services/websocket_service.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../models/game_state.dart';

class GameProvider with ChangeNotifier {
  final GameService _gameService = GameService();
  final WebSocketService _webSocketService = WebSocketService();
  
  List<Room> _rooms = [];
  Room? _currentRoom;
  List<Player> _currentPlayers = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isWebSocketConnected = false;
  GameState? _currentGameState;
  String? _currentPhase;
  String? _userRole;
  bool _hasVoted = false;
  bool _hasNightAction = false;
  final List<Map<String, String>> _chatMessages = [];
  SharedPreferences? _prefs;

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
        print('✅ Loaded game state: Room=$roomName, Phase=$phase');
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
      print('💾 Saved game state: Room=${_currentRoom!.name}, Phase=$_currentPhase');
    } catch (e) {
      print('❌ Error saving game state: $e');
    }
  }

  Future<void> _clearSavedGameState() async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.remove('last_room');
      await _prefs!.remove('last_phase');
      print('🧹 Cleared saved game state');
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
      final rooms = await _gameService.getRooms();
      _setRooms(rooms);
    } catch (e) {
      _setErrorMessage(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createRoom(String name, int maxPlayers, bool isPrivate, [String password = '']) async {
    _setLoading(true);
    try {
      _setErrorMessage(null);
      final room = await _gameService.createRoom(name, maxPlayers, isPrivate, password);
      _setCurrentRoom(room);
      
      _addPlayer(Player(
        id: 0,
        userId: 0,
        username: room.hostName,
        roomId: room.id,
        isAlive: true,
        isReady: true,
        joinedAt: DateTime.now(),
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
      
      final result = await _gameService.joinRoom(roomName, password);
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
      final result = await _gameService.getLobby(roomId);
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
      _setWebSocketConnected(true);
      
      _webSocketService.messages.listen((message) {
        _handleWebSocketMessage(message);
      });
      
    } catch (e) {
      _setErrorMessage('اتصال به اتاق ناموفق بود: $e');
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

      print('📨 WebSocket: $type - $messageData');

      switch (type) {
        case 'player_joined':
          _addPlayer(Player(
            id: 0,
            userId: 0,
            username: username,
            roomId: _currentRoom?.id ?? 0,
            isAlive: true,
            isReady: false,
            joinedAt: DateTime.now(),
          ));
          _addChatMessage('سیستم', '$username به اتاق پیوست');
          break;
          
        case 'player_left':
          _removePlayer(username);
          _addChatMessage('سیستم', '$username اتاق را ترک کرد');
          break;
          
        case 'player_ready':
          _togglePlayerReady(username);
          final status = _currentPlayers.firstWhere((p) => p.username == username).isReady ? 'آماده' : 'آماده نیست';
          _addChatMessage('سیستم', '$username $status شد');
          break;

        case 'chat_message':
          _addChatMessage(username, messageData);
          break;

        case 'game_started':
          _handleGameStarted(messageData);
          break;

        case 'phase_changed':
          _handlePhaseChanged(messageData);
          break;

        case 'player_died':
          _updatePlayerStatus(username, false);
          _addChatMessage('سیستم', '$username کشته شد!');
          break;

        case 'player_healed':
          _updatePlayerStatus(username, true);
          _addChatMessage('سیستم', '$username درمان شد!');
          break;

        case 'vote_received':
          _setHasVoted(true);
          break;

        case 'night_action_received':
          _setHasNightAction(true);
          break;

        case 'game_ended':
          _setCurrentPhase('finished');
          _addChatMessage('سیستم', 'بازی تمام شد! برنده: ${messageData['winner']}');
          break;

        case 'role_assigned':
          _setUserRole(messageData['role']);
          _addChatMessage('سیستم', 'نقش شما: ${_getRoleName(messageData['role'])}');
          break;

        case 'error':
          _setErrorMessage(messageData);
          _addChatMessage('خطا', messageData);
          break;
      }
      
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }

  void _handleGameStarted(dynamic messageData) {
    _setCurrentPhase('night');
    _setUserRole(messageData['role']);
    _setHasNightAction(false);
    _setHasVoted(false);
    _addChatMessage('سیستم', 'بازی شروع شد! نقش شما: ${_getRoleName(messageData['role'])}');
    
    for (var player in _currentPlayers) {
      if (player.role == null) {
        final testRole = _assignTestRole(player.username);
        _updatePlayerRole(player.username, testRole);
      }
    }
  }

  void _handlePhaseChanged(dynamic messageData) {
    _setCurrentPhase(messageData['phase']);
    _setHasNightAction(false);
    _setHasVoted(false);
    _addChatMessage('سیستم', 'فاز تغییر کرد: ${_getPhaseName(messageData['phase'])}');
  }

  void sendReadyStatus() {
    _webSocketService.sendMessage('player_ready', '');
  }

  void sendChatMessage(String message) {
    _webSocketService.sendMessage('chat_message', message);
    _addChatMessage('شما', message);
  }

  void sendVote(String targetUsername) {
    _webSocketService.sendMessage('vote', targetUsername);
    _setHasVoted(true);
  }

  void sendNightAction(String actionType, String targetUsername) {
    _webSocketService.sendMessage('night_action', {
      'action_type': actionType,
      'target': targetUsername,
    });
    _setHasNightAction(true);
  }

  void startGame() {
    if (canStartGame()) {
      _webSocketService.sendMessage('start_game', '');
    }
  }

  Future<void> leaveRoom() async {
    try {
      if (_currentRoom != null) {
        await _gameService.leaveRoom(_currentRoom!.id);
      }
    } catch (e) {
      print('❌ Error in leaveRoom API call: $e');
    } finally {
      await _webSocketService.disconnect();
      _cleanup();
    }
  }

  void _cleanup() {
    _setWebSocketConnected(false);
    _clearGameState();
  }

  Future<void> checkActiveGame() async {
    try {
      _setLoading(true);
      final gameStatus = await _gameService.checkGameStatus();
      
      if (gameStatus != null) {
        final room = Room.fromJson(gameStatus['room']);
        final gameState = GameState.fromJson(gameStatus['game_state']);
        
        _setCurrentRoom(room);
        _setCurrentGameState(gameState);
        _setCurrentPhase(gameState.phase);
        
        if (gameState.phase == 'finished') {
          _addChatMessage('سیستم', 'بازی قبلاً به پایان رسیده بود');
          _clearGameState();
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

  void _setCurrentPhase(String? phase) {
    _currentPhase = phase;
    notifyListeners();
    _saveGameState();
  }

  void _setUserRole(String? role) {
    _userRole = role;
    notifyListeners();
  }

  void _setHasVoted(bool voted) {
    _hasVoted = voted;
    notifyListeners();
  }

  void _setHasNightAction(bool hasAction) {
    _hasNightAction = hasAction;
    notifyListeners();
  }

  void _addPlayer(Player player) {
    _currentPlayers.add(player);
    notifyListeners();
    _checkAutoStart();
  }

  void _removePlayer(String username) {
    _currentPlayers.removeWhere((player) => player.username == username);
    notifyListeners();
  }

  void _togglePlayerReady(String username) {
    final index = _currentPlayers.indexWhere((p) => p.username == username);
    if (index != -1) {
      _currentPlayers[index] = _currentPlayers[index].copyWith(
        isReady: !_currentPlayers[index].isReady,
      );
      notifyListeners();
      _checkAutoStart();
    }
  }
  
  void returnToLobby() {
    _setCurrentPhase('waiting');
    _setHasNightAction(false);
    _setHasVoted(false);
    _addChatMessage('سیستم', 'بازگشت به لابی');
  }

  void _updatePlayerStatus(String username, bool isAlive) {
    final index = _currentPlayers.indexWhere((p) => p.username == username);
    if (index != -1) {
      _currentPlayers[index] = _currentPlayers[index].copyWith(isAlive: isAlive);
      notifyListeners();
    }
  }

  void _updatePlayerRole(String username, String role) {
    final index = _currentPlayers.indexWhere((p) => p.username == username);
    if (index != -1) {
      _currentPlayers[index] = _currentPlayers[index].copyWith(role: role);
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

  void _checkAutoStart() {
    if (canStartGame() && isRoomHost(_currentPlayers.first.username)) {
      Future.delayed(const Duration(seconds: 3), () {
        if (canStartGame()) {
          startGame();
        }
      });
    }
  }

  // ========== Helper Methods ==========
  Player? getCurrentPlayer(String username) {
    final index = _currentPlayers.indexWhere((p) => p.username == username);
    return index != -1 ? _currentPlayers[index] : null;
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

  bool isRoomHost(String username) {
    return _currentRoom?.hostName == username;
  }

  bool canStartGame() {
    return _currentPlayers.length >= 4 &&
           _currentPlayers.every((player) => player.isReady) &&
           (_currentPhase == null || _currentPhase == 'waiting');
  }

  String _getPhaseName(String? phase) {
    switch (phase) {
      case 'night': return 'شب';
      case 'day': return 'روز';
      case 'voting': return 'رای‌گیری';
      case 'finished': return 'پایان بازی';
      default: return 'در انتظار';
    }
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'mafia': return 'مافیا';
      case 'detective': return 'کارآگاه';
      case 'doctor': return 'دکتر';
      case 'citizen': return 'شهروند';
      default: return 'نقش نامشخص';
    }
  }

  String _assignTestRole(String username) {
    final roles = ['mafia', 'detective', 'doctor', 'citizen'];
    final index = _currentPlayers.indexWhere((p) => p.username == username) % roles.length;
    return roles[index];
  }

  void testStartGame() {
    _setCurrentPhase('night');
    _setUserRole('mafia');
    
    for (var player in _currentPlayers) {
      _updatePlayerRole(player.username, _assignTestRole(player.username));
    }
    
    _addChatMessage('سیستم', 'بازی تستی شروع شد!');
  }
}