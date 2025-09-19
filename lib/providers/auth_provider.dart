// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/platform_service.dart';
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
        // Validate token by making a request to get user info
        try {
          final userResponse = await http.get(
            Uri.parse('${PlatformService.getBaseUrl()}/api/auth/users/me/'),
            headers: <String, String>{
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          );

          if (userResponse.statusCode == 200) {
            final userData = jsonDecode(userResponse.body);
            _authData = AuthResponse(
              user: User.fromJson(userData),
              accessToken: accessToken,
              refreshToken: refreshToken ?? '',
            );
            
            if (kDebugMode) {
              print('Token validation successful');
            }
          } else if (userResponse.statusCode == 401 && refreshToken != null) {
            // Token expired, try to refresh
            try {
              final refreshResponse = await http.post(
                Uri.parse('${PlatformService.getBaseUrl()}/api/auth/jwt/refresh/'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'refresh': refreshToken}),
              );
              
              if (refreshResponse.statusCode == 200) {
                final newToken = jsonDecode(refreshResponse.body)['access'];
                await prefs.setString('access_token', newToken);
                
                // Get user info with new token
                final userResponse = await http.get(
                  Uri.parse('${PlatformService.getBaseUrl()}/api/auth/users/me/'),
                  headers: <String, String>{
                    'Authorization': 'Bearer $newToken',
                    'Content-Type': 'application/json',
                  },
                );
                
                if (userResponse.statusCode == 200) {
                  final userData = jsonDecode(userResponse.body);
                  _authData = AuthResponse(
                    user: User.fromJson(userData),
                    accessToken: newToken,
                    refreshToken: refreshToken,
                  );
                  
                  if (kDebugMode) {
                    print('Token refreshed successfully');
                  }
                } else {
                  _clearAuthData();
                }
              } else {
                _clearAuthData();
              }
            } catch (e) {
              if (kDebugMode) {
                print('Token refresh failed: $e');
              }
              _clearAuthData();
            }
          } else {
            _clearAuthData();
          }
        } catch (e) {
          if (kDebugMode) {
            print('Token validation failed: $e');
          }
          _clearAuthData();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in checkAuthStatus: $e');
      }
      _clearAuthData();
    } finally {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Auth check completed - isLoading: $_isLoading');
      }
    }
  }

  void _clearAuthData() {
    _authData = null;
    _errorMessage = null;
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