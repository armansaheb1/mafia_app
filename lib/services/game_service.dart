import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room.dart';
import '../models/player.dart';
import 'platform_service.dart';

class GameService {
  static String get _baseUrl => '${PlatformService.getBaseUrl()}/api/game/';

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

  Future<Room> createRoom(String name, int maxPlayers, bool isPrivate, [String password = '', int? scenarioId]) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${_baseUrl}rooms/create/'),
      headers: headers,
      body: json.encode({
        'name': name,
        'max_players': maxPlayers,
        'is_private': isPrivate,
        'password': password,
        if (scenarioId != null) 'scenario': scenarioId,
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
      'room_name': roomName,  // نه 'room_name'
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

  // API های جدید برای بازی
  Future<void> vote(String targetUsername, {String voteType = 'lynch'}) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}game/vote/'),
      headers: headers,
      body: json.encode({
        'target_username': targetUsername,
        'vote_type': voteType,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to vote: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> nightAction(String actionType, {String? targetUsername}) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}game/night-action/'),
      headers: headers,
      body: json.encode({
        'action_type': actionType,
        'target_username': targetUsername,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to perform night action: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> endPhase(int roomId) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}game/end-phase/'),
      headers: headers,
      body: json.encode({'room_id': roomId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to end phase: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getGameInfo() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('${_baseUrl}game/info/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get game info: ${response.statusCode} - ${response.body}');
    }
  }

  // API های سیستم صحبت
  Future<Map<String, dynamic>> startSpeaking() async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}speaking/start/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to start speaking: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> endSpeaking() async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}speaking/end/'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to end speaking: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> challengeSpeaking() async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}speaking/challenge/'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to challenge speaking: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> respondToChallenge(bool accepted) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}speaking/respond-challenge/'),
      headers: headers,
      body: json.encode({'accepted': accepted}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to respond to challenge: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> addSpeakingReaction(String reactionType, int speakingTurnId) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}speaking/reaction/'),
      headers: headers,
      body: json.encode({
        'reaction_type': reactionType,
        'speaking_turn_id': speakingTurnId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add reaction: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getSpeakingQueue() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('${_baseUrl}speaking/queue/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get speaking queue: ${response.statusCode} - ${response.body}');
    }
  }

  // API میز بازی
  Future<Map<String, dynamic>> getGameTableInfo() async {
    final headers = await _getHeaders();
    
    // ابتدا سعی کن از API جدید استفاده کن
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}rooms/table-info/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('⚠️ Room table info failed, trying game table info: $e');
    }
    
    // اگر API جدید کار نکرد، از API قدیمی استفاده کن
    final response = await http.get(
      Uri.parse('${_baseUrl}game/table-info/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get table info: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> startGame(int roomId) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('${_baseUrl}rooms/start/'),
      headers: headers,
      body: json.encode({'room_id': roomId}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to start game: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> resetGame() async {
    print('🔄 GameService.resetGame() called');
    final headers = await _getHeaders();
    print('🔄 Headers: $headers');
    
    try {
      final url = '${_baseUrl}reset/';
      print('🔄 Making POST request to: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );
      print('🔄 Response status: ${response.statusCode}');
      print('🔄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'],
          'game_info': responseData['game_info'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Reset failed',
        };
      }
    } catch (e) {
      print('❌ Error calling reset API: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

}