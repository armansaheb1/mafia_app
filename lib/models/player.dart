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
    print('🔍 Player.fromJson: Parsing player ${json['username']}...');
    print('  - role field: ${json['role']} (type: ${json['role'].runtimeType})');
    
    // Handle role field - it might be a string or a map
    Role? role;
    if (json['role'] != null) {
      if (json['role'] is String) {
        // If role is a string, create a simple Role object
        role = Role(
          id: 0,
          name: json['role'].toLowerCase().replaceAll(' ', '_'),
          displayName: json['role'],
          roleType: 'unknown',
          description: '',
          abilityName: null,
          nightActionOrder: 0,
          isActive: true,
        );
      } else if (json['role'] is Map<String, dynamic>) {
        // If role is a map, parse it normally
        role = Role.fromJson(json['role']);
      }
    }
    
    return Player(
      id: (json['id'] as int?) ?? 0,
      userId: (json['user'] as int?) ?? 0,
      username: json['username'] ?? 'Unknown',
      roomId: (json['room'] as int?) ?? 0,
      role: role,
      isAlive: json['is_alive'] ?? true,
      isReady: json['is_ready'] ?? false,
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : DateTime.now(),
      votesReceived: (json['votes_received'] as int?) ?? 0,
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