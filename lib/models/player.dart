import 'scenario.dart';

class Player {
  final int id;
  final int userId;
  final String username;
  final int roomId;
  final Role? role;
  bool isAlive;
  bool isReady;
  final DateTime joinedAt;
  final int votesReceived;
  final bool isProtected;
  final Map<String, dynamic> specialActionsUsed;

  Player({
    required this.id,
    required this.userId,
    required this.username,
    required this.roomId,
    this.role,
    required this.isAlive,
    required this.isReady,
    required this.joinedAt,
    required this.votesReceived,
    required this.isProtected,
    required this.specialActionsUsed,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      userId: json['user'],
      username: json['username'],
      roomId: json['room'],
      role: json['role'] != null ? Role.fromJson(json['role']) : null,
      isAlive: json['is_alive'],
      isReady: json['is_ready'],
      joinedAt: DateTime.parse(json['joined_at']),
      votesReceived: json['votes_received'] ?? 0,
      isProtected: json['is_protected'] ?? false,
      specialActionsUsed: Map<String, dynamic>.from(json['special_actions_used'] ?? {}),
    );
  }

  // اضافه کردن متد toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'username': username,
      'room': roomId,
      'role': role?.toJson(),
      'is_alive': isAlive,
      'is_ready': isReady,
      'joined_at': joinedAt.toIso8601String(),
      'votes_received': votesReceived,
      'is_protected': isProtected,
      'special_actions_used': specialActionsUsed,
    };
  }

  Player copyWith({
    int? id,
    int? userId,
    String? username,
    int? roomId,
    Role? role,
    bool? isAlive,
    bool? isReady,
    DateTime? joinedAt,
    int? votesReceived,
    bool? isProtected,
    Map<String, dynamic>? specialActionsUsed,
  }) {
    return Player(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      roomId: roomId ?? this.roomId,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      isReady: isReady ?? this.isReady,
      joinedAt: joinedAt ?? this.joinedAt,
      votesReceived: votesReceived ?? this.votesReceived,
      isProtected: isProtected ?? this.isProtected,
      specialActionsUsed: specialActionsUsed ?? this.specialActionsUsed,
    );
  }
}