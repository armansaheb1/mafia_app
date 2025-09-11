// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthResponse? _authData;
  String? _errorMessage;
  bool _isLoading = true;

  AuthResponse? get authData => _authData;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _authData != null;
  bool get isLoading => _isLoading;

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    if (accessToken != null) {
      try {
        // بررسی معتبر بودن توکن با گرفتن اطلاعات کاربر
        final response = await http.get(
          Uri.parse('http://10.0.2.2:8000/api/auth/users/me/'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          _authData = AuthResponse(
            user: User.fromJson(userData),
            accessToken: accessToken,
            refreshToken: prefs.getString('refresh_token') ?? '',
          );
        }
      } catch (e) {
        // اگر توکن معتبر نیست، حذفش کن
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    try {
      _errorMessage = null;
      _authData = await _authService.login(username, password);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // اضافه کردن متد register
  Future<void> register(String username, String email, String password, String rePassword) async {
    try {
      _errorMessage = null;
      _authData = await _authService.register(username, email, password, rePassword);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    
    _authData = null;
    notifyListeners();
  }
}