// lib/models/auth_response.dart
import 'user.dart';

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // این متد ممکنه کمتر استفاده بشه چون داده از دو منبع میاد (login + user/me)
    return AuthResponse(
      user: User.fromJson(json['user']), // اگر سرور یکجا همه چیز رو بفرسته
      accessToken: json['access'],
      refreshToken: json['refresh'],
    );
  }
}