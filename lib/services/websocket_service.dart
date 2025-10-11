import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _currentRoom;
  bool _isConnected = false;
  StreamSubscription? _streamSubscription;

  Future<void> connectToRoom(String roomName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      await disconnect();

      // استفاده از آدرس مناسب بر اساس پلتفرم با room_name در مسیر
      final baseUrl = PlatformService.getWebSocketUrl();
      final encodedRoomName = Uri.encodeComponent(roomName);
      final encodedToken = Uri.encodeComponent(token);
      final uri = Uri.parse('$baseUrl/ws/game/$encodedRoomName/?token=$encodedToken');
      print('🔌 Connecting to WebSocket: $uri');
      
      _channel = IOWebSocketChannel.connect(uri);
      _currentRoom = roomName;
      
      // صبر کردن برای اتصال و بررسی وضعیت
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // بررسی وضعیت اتصال
      if (_channel != null) {
        _isConnected = true;
        print('✅ Connected to room: $roomName');
        
        // ارسال پیام اتصال موفق
        sendMessage('connection_established', '');
      } else {
        throw Exception('Failed to establish WebSocket connection');
      }
      
    } catch (e) {
      print('❌ WebSocket connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void sendMessage(String type, dynamic data) {
    if (_channel != null && _isConnected) {
      final message = jsonEncode({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(message);
      print('📤 Sent message: $type - $data');
    } else {
      print('❌ WebSocket not connected');
      throw Exception('WebSocket not connected');
    }
  }

  Stream<dynamic> get messages {
    if (_channel == null) {
      return const Stream.empty();
    }
    
    return _channel!.stream.handleError((error) {
      print('❌ WebSocket stream error: $error');
      _isConnected = false;
    }).map((data) {
      // Keep connection alive by updating timestamp
      print('📨 WebSocket data received: $data');
      return data;
    });
  }

  Future<void> disconnect() async {
    // Cancel stream subscription
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        print('❌ Error closing WebSocket: $e');
      }
      _channel = null;
      _currentRoom = null;
      _isConnected = false;
      print('🔌 Disconnected from WebSocket');
    }
  }

  bool get isConnected => _isConnected && _channel != null;
  String? get currentRoom => _currentRoom;
  
  Future<bool> checkConnection() async {
    if (_channel == null || !_isConnected) {
      return false;
    }
    
    try {
      // Send a ping message to check if connection is alive
      sendMessage('ping', '');
      return true;
    } catch (e) {
      print('❌ Connection check failed: $e');
      _isConnected = false;
      return false;
    }
  }
}