// lib/services/api_interceptor.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiInterceptor {
  static Future<http.Response> authenticatedRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    // اولین درخواست
    var response = await requestFn();
    
    // اگر توکن منقضی شده بود (خطای 401)
    if (response.statusCode == 401 && accessToken != null) {
      // سعی در refresh کردن توکن
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken != null) {
        final refreshResponse = await http.post(
          Uri.parse('http://10.0.2.2:8000/api/auth/jwt/refresh/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refreshToken}),
        );
        
        if (refreshResponse.statusCode == 200) {
          final newToken = jsonDecode(refreshResponse.body)['access'];
          await prefs.setString('access_token', newToken);
          
          // دوباره درخواست اصلی را با توکن جدید بزن
          response = await requestFn();
        } else {
          // اگر refresh هم failed، کاربر را به login صفحه هدایت کن
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
          throw Exception('Session expired. Please login again.');
        }
      }
    }
    
    return response;
  }
}