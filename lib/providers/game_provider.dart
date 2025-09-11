// lib/providers/game_provider.dart
import 'package:flutter/foundation.dart';
import '../services/game_service.dart';
import '../models/room.dart';
import '../models/player.dart';

class GameProvider with ChangeNotifier {
  final GameService _gameService = GameService();
  List<Room> _rooms = [];
  Room? _currentRoom;
  List<Player> _currentPlayers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Room> get rooms => _rooms;
  Room? get currentRoom => _currentRoom;
  List<Player> get currentPlayers => _currentPlayers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRooms() async {
    setLoading(true);
    try {
      _errorMessage = null;
      _rooms = await _gameService.getRooms();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> createRoom(String name, int maxPlayers, bool isPrivate, [String password = '']) async {
    setLoading(true);
    try {
      _errorMessage = null;
      _currentRoom = await _gameService.createRoom(name, maxPlayers, isPrivate, password);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> joinRoom(String roomName, [String password = '']) async {
    setLoading(true);
    try {
      _errorMessage = null;
      final result = await _gameService.joinRoom(roomName, password);
      _currentRoom = result['room'] as Room;
      // می‌توانید player فعلی را هم ذخیره کنید اگر نیاز باشد
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> fetchLobby(int roomId) async {
    setLoading(true);
    try {
      _errorMessage = null;
      final result = await _gameService.getLobby(roomId);
      _currentRoom = result['room'] as Room;
      _currentPlayers = result['players'] as List<Player>;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearRoom() {
    _currentRoom = null;
    _currentPlayers = [];
    notifyListeners();
  }
}