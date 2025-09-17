import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room.dart';
import '../models/player.dart';

class GameService {
  static const String _baseUrl = 'http://10.0.2.2:8000/api/game/';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> checkGameStatus() async {
    final headers = await _getHeaders();
    
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}game/status/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // بازی فعالی وجود ندارد
        return null;
      } else {
        throw Exception('Failed to check game status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking game status: $e');
      return null;
    }
  }

  Future<List<Room>> getRooms() async {
    final headers = await _getHeaders();
    
    print('Sending request to: ${_baseUrl}rooms/');
    print('Headers: $headers');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}rooms/'),
      headers: headers,
    );
    
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final List<dynamic> roomsJson = json.decode(response.body);
      return roomsJson.map((json) => Room.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('احراز هویت ناموفق. لطفاً دوباره وارد شوید.');
    } else {
      throw Exception('خطا در دریافت اتاق‌ها: ${response.statusCode}');
    }
  }

  Future<Room> createRoom(String name, int maxPlayers, bool isPrivate, [String password = '']) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${_baseUrl}rooms/create/'),
      headers: headers,
      body: json.encode({
        'name': name,
        'max_players': maxPlayers,
        'is_private': isPrivate,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return Room.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create room: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> joinRoom(String roomName, [String password = '']) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${_baseUrl}rooms/join/'),
      headers: headers,
      body: json.encode({
        'room_name': roomName,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return {
        'room': Room.fromJson(responseData['room']),
        'player': Player.fromJson(responseData['player']),
      };
    } else {
      throw Exception('Failed to join room: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getLobby(int roomId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${_baseUrl}lobby/$roomId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return {
        'room': Room.fromJson(responseData['room']),
        'players': (responseData['players'] as List)
            .map((playerJson) => Player.fromJson(playerJson))
            .toList(),
      };
    } else {
      throw Exception('Failed to get lobby: ${response.statusCode}');
    }
  }

  Future<void> leaveRoom(int roomId) async {
    final headers = await _getHeaders();
    
    print('Leaving room with ID: $roomId');
    
    final response = await http.post(
      Uri.parse('${_baseUrl}rooms/leave/'),
      headers: headers,
      body: json.encode({'room_id': roomId}),
    );

    print('Leave room response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      print('Successfully left room');
    } else {
      throw Exception('Failed to leave room: ${response.statusCode} - ${response.body}');
    }
  }
}