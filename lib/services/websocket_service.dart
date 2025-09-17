import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _currentRoom;

  Future<void> connectToRoom(String roomName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      await disconnect();

      // استفاده از آدرس درست - پورت 8000 برای Django
      final uri = Uri.parse('ws://10.0.2.2:8000/ws/game/$roomName/?token=$token');
      print('Connecting to WebSocket: $uri');
      
      _channel = IOWebSocketChannel.connect(uri);
      _currentRoom = roomName;
      
      print('✅ Connected to room: $roomName');
      
    } catch (e) {
      print('❌ WebSocket connection error: $e');
      rethrow;
    }
  }

  void sendMessage(String type, dynamic data) {
    if (_channel != null) {
      final message = jsonEncode({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(message);
      print('📤 Sent message: $type - $data');
    } else {
      print('❌ WebSocket not connected');
    }
  }

  Stream<dynamic> get messages {
    return _channel?.stream ?? const Stream.empty();
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
      _currentRoom = null;
      print('🔌 Disconnected from WebSocket');
    }
  }

  bool get isConnected => _channel != null;
  String? get currentRoom => _currentRoom;
}