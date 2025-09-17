// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      
      if (kDebugMode) {
        print('Stored Access Token: $accessToken');
      }
      if (kDebugMode) {
        print('Stored Refresh Token: $refreshToken');
      }

      if (accessToken != null) {
        // یک بررسی ساده‌تر - فقط چک کنیم توکن وجود داره
        // بدون درخواست به سرور برای تست اولیه
        _authData = AuthResponse(
          user: User(id: 0, username: 'temp', email: 'temp'), // کاربر موقت
          accessToken: accessToken,
          refreshToken: refreshToken ?? '',
        );
        
        if (kDebugMode) {
          print('Using stored token without validation');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in checkAuthStatus: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Auth check completed - isLoading: $_isLoading');
      }
    }
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
  
  Future<void> checkStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');
    
    if (kDebugMode) {
      print('=== Storage Check ===');
    }
    if (kDebugMode) {
      print('Access Token in storage: ${accessToken != null}');
    }
    if (kDebugMode) {
      print('Refresh Token in storage: ${refreshToken != null}');
    }
    if (kDebugMode) {
      print('=====================');
    }
  }
}