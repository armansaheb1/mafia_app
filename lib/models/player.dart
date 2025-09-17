class Player {
  final int id;
  final int userId;
  final String username;
  final int roomId;
  final String? role;
  bool isAlive;
  bool isReady;
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

  // اضافه کردن متد toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'username': username,
      'room': roomId,
      'role': role,
      'is_alive': isAlive,
      'is_ready': isReady,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  Player copyWith({
    int? id,
    int? userId,
    String? username,
    int? roomId,
    String? role,
    bool? isAlive,
    bool? isReady,
    DateTime? joinedAt,
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
    );
  }
}