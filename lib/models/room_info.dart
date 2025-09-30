class RoomInfo {
  final String roomName;
  final String roomStatus;
  final int maxPlayers;
  final int currentPlayers;
  final List<PlayerInfo> players;
  final ScenarioInfo? scenario;

  RoomInfo({
    required this.roomName,
    required this.roomStatus,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.players,
    this.scenario,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      roomName: json['room_name'] ?? '',
      roomStatus: json['room_status'] ?? 'waiting',
      maxPlayers: json['max_players'] ?? 8,
      currentPlayers: json['current_players'] ?? 0,
      players: (json['players'] as List<dynamic>?)
          ?.map((playerJson) => PlayerInfo.fromJson(playerJson))
          .toList() ?? [],
      scenario: json['scenario'] != null 
          ? ScenarioInfo.fromJson(json['scenario']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_name': roomName,
      'room_status': roomStatus,
      'max_players': maxPlayers,
      'current_players': currentPlayers,
      'players': players.map((player) => player.toJson()).toList(),
      'scenario': scenario?.toJson(),
    };
  }
}

class PlayerInfo {
  final int id;
  final String username;
  final bool isAlive;
  final bool isReady;
  final int seatPosition;
  final String? avatarUrl;
  final bool isMicrophoneOn;
  final bool canHearOthers;
  final bool canSpeakToOthers;

  PlayerInfo({
    required this.id,
    required this.username,
    required this.isAlive,
    required this.isReady,
    required this.seatPosition,
    this.avatarUrl,
    required this.isMicrophoneOn,
    required this.canHearOthers,
    required this.canSpeakToOthers,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      isAlive: json['is_alive'] ?? true,
      isReady: json['is_ready'] ?? false,
      seatPosition: json['seat_position'] ?? 0,
      avatarUrl: json['avatar_url'],
      isMicrophoneOn: json['is_microphone_on'] ?? false,
      canHearOthers: json['can_hear_others'] ?? false,
      canSpeakToOthers: json['can_speak_to_others'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'is_alive': isAlive,
      'is_ready': isReady,
      'seat_position': seatPosition,
      'avatar_url': avatarUrl,
      'is_microphone_on': isMicrophoneOn,
      'can_hear_others': canHearOthers,
      'can_speak_to_others': canSpeakToOthers,
    };
  }
}

class ScenarioInfo {
  final String name;
  final String? imageUrl;
  final String? tableImageUrl;

  ScenarioInfo({
    required this.name,
    this.imageUrl,
    this.tableImageUrl,
  });

  factory ScenarioInfo.fromJson(Map<String, dynamic> json) {
    return ScenarioInfo(
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      tableImageUrl: json['table_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image_url': imageUrl,
      'table_image_url': tableImageUrl,
    };
  }
}