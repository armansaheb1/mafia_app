// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mafia_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import 'platform_service.dart';

class AuthService {
  static String get _baseUrl => '${PlatformService.getBaseUrl()}/api/auth/';

  Future<AuthResponse> register(String username, String email, String password, String rePassword) async {
  final response = await http.post(
    Uri.parse('${_baseUrl}users/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'email': email,
        'password': password,
        're_password': rePassword, // <-- اضافه شدن
      }),
    );

    if (response.statusCode == 201) {
      // ثبت‌نام موفق، حالا باید کاربر رو auto-login کنیم یا فقط پیام موفقیت بدیم؟
      // برای سادگی، می‌تونیم مستقیماً درخواست login بدیم
      return login(username, password);
    } else {
      throw Exception('ثبت‌نام失败: ${response.statusCode} - ${response.body}');
    }
  }

  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}jwt/create/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String accessToken = responseData['access'];
      final String refreshToken = responseData['refresh'];

      // ذخیره توکن‌ها - حتماً await کنید
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);

      if (kDebugMode) {
        print('Tokens saved successfully!');
      }
      if (kDebugMode) {
        print('Access Token: $accessToken');
      }
      if (kDebugMode) {
        print('Refresh Token: $refreshToken');
      }
      // گرفتن اطلاعات کاربر
      final userResponse = await http.get(
        Uri.parse('${_baseUrl}users/me/'),
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        return AuthResponse(
          user: User.fromJson(userData),
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        throw Exception('Failed to fetch user data: ${userResponse.statusCode}');
      }
    } else {
      throw Exception('ورود失败: ${response.statusCode} - ${response.body}');
    }
  }


  Future<void> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}jwt/refresh/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'refresh': refreshToken,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String newAccessToken = responseData['access'];
      
      await prefs.setString('access_token', newAccessToken);
    } else {
      // اگر refresh token هم منقضی شده، کاربر باید دوباره لاگین کند
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      throw Exception('Token refresh failed: ${response.statusCode}');
    }
  }
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}