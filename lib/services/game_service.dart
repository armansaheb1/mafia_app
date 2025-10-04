import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import 'platform_service.dart';

class GameService {
  static String get _baseUrl => '${PlatformService.getBaseUrl()}/api/game/';
  
  final BuildContext _context;
  
  GameService(this._context);

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    print('🔑 GameService._getHeaders: Token = ${token != null ? token.substring(0, 20) + '...' : 'null'}');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> checkGameStatus() async {
    final headers = await _getHeaders();
    
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}status/'),
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
      Uri.parse('${_baseUrl}vote/'),
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
      Uri.parse('${_baseUrl}night-action/'),
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
      Uri.parse('${_baseUrl}end-phase/'),
      headers: headers,
      body: json.encode({'room_id': roomId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to end phase: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getGameInfo() async {
    final headers = await _getHeaders();
    
    // Use room-info endpoint instead of non-existent info endpoint
    final gameProvider = Provider.of<GameProvider>(_context, listen: false);
    final roomId = gameProvider.currentRoom?.id;
    
    if (roomId == null) {
      throw Exception('No current room found');
    }
    
    final response = await http.get(
      Uri.parse('${_baseUrl}rooms/$roomId/info/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Transform room info to game info format
      return {
        'phase': data['current_phase'] ?? 'night', // استفاده از فاز واقعی یا شب
        'day_number': data['day_number'] ?? 1,
        'phase_time_remaining': 300,
        'player_role': 'citizen', // Default role
        'winner': null,
        'alive_players': data['players'] ?? [],
        'votes': {},
      };
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
    print('🔍 GameService.getGameTableInfo: Starting...');
    
    try {
      // Get current room ID from game provider
      final gameProvider = Provider.of<GameProvider>(_context, listen: false);
      final roomId = gameProvider.currentRoom?.id;
      
      print('🔍 GameService.getGameTableInfo: Current room ID: $roomId');
      
      if (roomId == null) {
        throw Exception('No current room found');
      }
      
      // Use the existing room-info endpoint
      final url = '${_baseUrl}rooms/$roomId/info/';
      print('🔍 GameService.getGameTableInfo: Using room-info URL: $url');
      
      final headers = await _getHeaders();
      print('🔍 GameService.getGameTableInfo: Headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      print('🔍 GameService.getGameTableInfo: Response status: ${response.statusCode}');
      print('🔍 GameService.getGameTableInfo: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 GameService.getGameTableInfo: Parsed data: $data');
        
        // Transform the data to match expected format
        return _transformRoomInfoToTableInfo(data);
      } else {
        print('⚠️ GameService.getGameTableInfo: Room-info endpoint failed with status: ${response.statusCode}');
        throw Exception('Room info endpoint failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ GameService.getGameTableInfo: Error: $e');
      throw Exception('Failed to get room info: $e');
    }
  }
  
  Map<String, dynamic> _transformRoomInfoToTableInfo(Map<String, dynamic> roomInfo) {
    print('🔍 GameService._transformRoomInfoToTableInfo: Transforming data...');
    
    // Extract scenario info
    final scenario = roomInfo['scenario'];
    final tableImageUrl = scenario?['table_image_url'];
    final scenarioName = scenario?['name'] ?? 'Unknown Scenario';
    
    print('🔍 GameService._transformRoomInfoToTableInfo: Scenario name: $scenarioName');
    print('🔍 GameService._transformRoomInfoToTableInfo: Table image URL: $tableImageUrl');
    
    // Transform players data
    final players = roomInfo['players'] as List<dynamic>? ?? [];
    print('🔍 GameService._transformRoomInfoToTableInfo: Raw players data: $players');
    
    final transformedPlayers = players.map((player) {
      final seatPosition = player['seat_position'];
      print('🔍 Player ${player['username']}: seat_position = $seatPosition');
      
      // Handle seat_position - it might be a number instead of an object
      Map<String, dynamic> seatPos;
      if (seatPosition is Map) {
        seatPos = Map<String, dynamic>.from(seatPosition);
      } else if (seatPosition is num) {
        // If it's a number, create a circular position based on player index
        final playerIndex = players.indexOf(player);
        final angle = (playerIndex * 360.0 / players.length) * (3.14159 / 180);
        final radius = 0.3;
        seatPos = {
          'x': 0.5 + radius * cos(angle),
          'y': 0.5 + radius * sin(angle),
          'angle': playerIndex * 360.0 / players.length,
        };
      } else {
        // Default position
        seatPos = {'x': 0.5, 'y': 0.5, 'angle': 0.0};
      }
      
      return {
        'id': player['id'],
        'username': player['username'],
        'role': null, // Room info doesn't include roles
        'is_alive': player['is_alive'] ?? true,
        'avatar_url': player['avatar_url'],
        'seat_position': seatPos,
        'is_speaking': false, // No speaking in room info
        'reactions': {'likes': 0, 'dislikes': 0},
      };
    }).toList();
    
    print('🔍 GameService._transformRoomInfoToTableInfo: Transformed ${transformedPlayers.length} players');
    
    // Create speaking queue from players
    final speakingQueue = {
      'spoken_players': [],
      'remaining_players': transformedPlayers.map((p) => p['username']).toList(),
    };
    
    final transformedData = {
      'table_image_url': tableImageUrl,
      'scenario_name': scenarioName,
      'players': transformedPlayers,
      'current_speaker': null,
      'speaking_queue': speakingQueue,
    };
    
    print('🔍 GameService._transformRoomInfoToTableInfo: Final transformed data: $transformedData');
    return transformedData;
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

  Future<Map<String, dynamic>> getGameSettings() async {
    print('⚙️ GameService.getGameSettings() called');
    final headers = await _getHeaders();
    
    try {
      final url = '${_baseUrl}game-settings/';
      print('⚙️ Making GET request to: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      print('⚙️ Response status: ${response.statusCode}');
      print('⚙️ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to get game settings: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error calling game settings API: $e');
      throw Exception('خطا در دریافت تنظیمات بازی: $e');
    }
  }

  Future<Map<String, dynamic>> resetGame() async {
    print('🔄 GameService.resetGame() called');
    final headers = await _getHeaders();
    print('🔄 Headers: $headers');
    print('🔄 Authorization header: ${headers['Authorization']?.substring(0, 30)}...');
    
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