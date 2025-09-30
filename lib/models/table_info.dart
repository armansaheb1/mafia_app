// lib/models/table_info.dart

class SeatPosition {
  final double x; // موقعیت X (0.0 تا 1.0)
  final double y; // موقعیت Y (0.0 تا 1.0)
  final double angle; // زاویه (درجه)

  SeatPosition({
    required this.x,
    required this.y,
    required this.angle,
  });

  factory SeatPosition.fromJson(Map<String, dynamic> json) {
    return SeatPosition(
      x: (json['x'] ?? 0.5).toDouble(),
      y: (json['y'] ?? 0.5).toDouble(),
      angle: (json['angle'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'angle': angle,
    };
  }
}

class PlayerSeat {
  final int id;
  final String username;
  final String? role;
  final bool isAlive;
  final String? avatarUrl;
  final SeatPosition seatPosition;
  final bool isSpeaking;
  final Map<String, int> reactions; // {'likes': 5, 'dislikes': 2}

  PlayerSeat({
    required this.id,
    required this.username,
    this.role,
    required this.isAlive,
    this.avatarUrl,
    required this.seatPosition,
    required this.isSpeaking,
    required this.reactions,
  });

  factory PlayerSeat.fromJson(Map<String, dynamic> json) {
    return PlayerSeat(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      isAlive: json['is_alive'] ?? true,
      avatarUrl: json['avatar_url'],
      seatPosition: SeatPosition.fromJson(json['seat_position'] ?? {}),
      isSpeaking: json['is_speaking'] ?? false,
      reactions: Map<String, int>.from(json['reactions'] ?? {}),
    );
  }
  
  // Factory method that takes currentSpeaker into account
  factory PlayerSeat.fromJsonWithSpeaker(Map<String, dynamic> json, String? currentSpeakerUsername) {
    return PlayerSeat(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      isAlive: json['is_alive'] ?? true,
      avatarUrl: json['avatar_url'],
      seatPosition: SeatPosition.fromJson(json['seat_position'] ?? {}),
      isSpeaking: json['is_speaking'] ?? (currentSpeakerUsername == json['username']),
      reactions: Map<String, int>.from(json['reactions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'is_alive': isAlive,
      'avatar_url': avatarUrl,
      'seat_position': seatPosition.toJson(),
      'is_speaking': isSpeaking,
      'reactions': reactions,
    };
  }
}

class GameTableInfo {
  final String? tableImageUrl;
  final String scenarioName;
  final List<PlayerSeat> players;
  final CurrentSpeaker? currentSpeaker;
  final SpeakingQueue speakingQueue;

  GameTableInfo({
    this.tableImageUrl,
    required this.scenarioName,
    required this.players,
    this.currentSpeaker,
    required this.speakingQueue,
  });

  factory GameTableInfo.fromJson(Map<String, dynamic> json) {
    final currentSpeaker = json['current_speaker'] != null
        ? CurrentSpeaker.fromJson(json['current_speaker'])
        : null;
    
    return GameTableInfo(
      tableImageUrl: json['table_image_url'],
      scenarioName: json['scenario_name'] ?? '',
      players: (json['players'] as List<dynamic>? ?? [])
          .map((playerJson) => PlayerSeat.fromJsonWithSpeaker(
                playerJson, 
                currentSpeaker?.username
              ))
          .toList(),
      currentSpeaker: currentSpeaker,
      speakingQueue: SpeakingQueue.fromJson(json['speaking_queue'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'table_image_url': tableImageUrl,
      'scenario_name': scenarioName,
      'players': players.map((player) => player.toJson()).toList(),
      'current_speaker': currentSpeaker?.toJson(),
      'speaking_queue': speakingQueue.toJson(),
    };
  }
}

class CurrentSpeaker {
  final int? id;
  final String? username;
  final int timeRemaining;
  final bool isChallenged;

  CurrentSpeaker({
    this.id,
    this.username,
    required this.timeRemaining,
    required this.isChallenged,
  });

  factory CurrentSpeaker.fromJson(Map<String, dynamic> json) {
    return CurrentSpeaker(
      id: json['id'],
      username: json['username'],
      timeRemaining: json['time_remaining'] ?? 0,
      isChallenged: json['is_challenged'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'time_remaining': timeRemaining,
      'is_challenged': isChallenged,
    };
  }
}

class SpeakingQueue {
  final List<String> spokenPlayers;
  final List<String> remainingPlayers;

  SpeakingQueue({
    required this.spokenPlayers,
    required this.remainingPlayers,
  });

  factory SpeakingQueue.fromJson(Map<String, dynamic> json) {
    return SpeakingQueue(
      spokenPlayers: List<String>.from(json['spoken_players'] ?? []),
      remainingPlayers: List<String>.from(json['remaining_players'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spoken_players': spokenPlayers,
      'remaining_players': remainingPlayers,
    };
  }
}
