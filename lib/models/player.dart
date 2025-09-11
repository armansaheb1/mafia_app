// lib/models/player.dart
class Player {
  final int id;
  final int userId;
  final String username;
  final int roomId;
  final String? role;
  final bool isAlive;
  final bool isReady;
  final DateTime joinedAt;

  Player({
    required this.id,
    required this.userId,
    required this.username,
    required this.roomId,
    this.role,
    required this.isAlive,
    required this.isReady,
    required this.joinedAt,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      userId: json['user'],
      username: json['username'],
      roomId: json['room'],
      role: json['role'],
      isAlive: json['is_alive'],
      isReady: json['is_ready'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}