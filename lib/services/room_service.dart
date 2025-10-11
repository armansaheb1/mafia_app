import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room_info.dart';
import 'auth_service.dart';

class RoomService {
  final AuthService _authService = AuthService();
  static const String baseUrl = 'http://172.20.10.10:8000/api/game';

  Future<Map<String, dynamic>> _makeRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    http.Response response;
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        response = await http.get(uri, headers: headers);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Request failed');
    }
  }

  Future<RoomInfo> getRoomInfo({int? roomId}) async {
    if (roomId == null) {
      // Try to get the current user's room
      final rooms = await getRooms();
      if (rooms.isEmpty) {
        throw Exception('No rooms available');
      }
      // For now, use the first available room
      roomId = rooms.first['id'];
    }
    
    final data = await _makeRequest('/rooms/$roomId/info/');
    return RoomInfo.fromJson(data);
  }

  Future<void> toggleReady({int? roomId}) async {
    if (roomId == null) {
      final rooms = await getRooms();
      if (rooms.isEmpty) {
        throw Exception('No rooms available');
      }
      roomId = rooms.first['id'];
    }
    await _makeRequest('/rooms/$roomId/toggle-ready/', method: 'POST');
  }

  Future<void> toggleMicrophone({int? roomId}) async {
    if (roomId == null) {
      final rooms = await getRooms();
      if (rooms.isEmpty) {
        throw Exception('No rooms available');
      }
      roomId = rooms.first['id'];
    }
    await _makeRequest('/rooms/$roomId/toggle-microphone/', method: 'POST');
  }

  Future<void> updateSeatPosition({int? roomId, required int position}) async {
    if (roomId == null) {
      final rooms = await getRooms();
      if (rooms.isEmpty) {
        throw Exception('No rooms available');
      }
      roomId = rooms.first['id'];
    }
    await _makeRequest(
      '/rooms/$roomId/update-seat/',
      method: 'POST',
      body: {'seat_position': position},
    );
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    final data = await _makeRequest('/rooms/');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required int maxPlayers,
    bool isPrivate = false,
    String? password,
    int? scenarioId,
  }) async {
    return await _makeRequest(
      '/rooms/create/',
      method: 'POST',
      body: {
        'name': name,
        'max_players': maxPlayers,
        'is_private': isPrivate,
        if (password != null) 'password': password,
        if (scenarioId != null) 'scenario': scenarioId,
      },
    );
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomName,
    String? password,
  }) async {
    return await _makeRequest(
      '/rooms/join/',
      method: 'POST',
      body: {
        'room_name': roomName,
        if (password != null) 'password': password,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getScenarios() async {
    final data = await _makeRequest('/scenarios/');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> getScenario(int scenarioId) async {
    return await _makeRequest('/scenarios/$scenarioId/');
  }
}