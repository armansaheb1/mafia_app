// game_models.dart

class Role {
  final int id;
  final String name;
  final String type;
  final String description;
  final bool isActive;

  Role({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.isActive,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'is_active': isActive,
    };
  }
}

class Game {
  final int id;
  final int roomId;
  final int scenarioId;
  final String currentPhase;
  final int currentDay;
  final DateTime phaseStartTime;
  final DateTime? phaseEndTime;
  final String? winner;
  final DateTime createdAt;
  final List<GamePlayer> gamePlayers;

  Game({
    required this.id,
    required this.roomId,
    required this.scenarioId,
    required this.currentPhase,
    required this.currentDay,
    required this.phaseStartTime,
    this.phaseEndTime,
    this.winner,
    required this.createdAt,
    required this.gamePlayers,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      roomId: json['room'],
      scenarioId: json['scenario'],
      currentPhase: json['current_phase'],
      currentDay: json['current_day'],
      phaseStartTime: DateTime.parse(json['phase_start_time']),
      phaseEndTime: json['phase_end_time'] != null 
          ? DateTime.parse(json['phase_end_time']) 
          : null,
      winner: json['winner'],
      createdAt: DateTime.parse(json['created_at']),
      gamePlayers: (json['game_players'] as List? ?? [])
          .map((playerJson) => GamePlayer.fromJson(playerJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room': roomId,
      'scenario': scenarioId,
      'current_phase': currentPhase,
      'current_day': currentDay,
      'phase_start_time': phaseStartTime.toIso8601String(),
      'phase_end_time': phaseEndTime?.toIso8601String(),
      'winner': winner,
      'created_at': createdAt.toIso8601String(),
      'game_players': gamePlayers.map((player) => player.toJson()).toList(),
    };
  }

  bool get isActive => currentPhase != 'finished';
  int get alivePlayersCount => gamePlayers.where((p) => p.isAlive).length;
  int get mafiaCount => gamePlayers.where((p) => p.isMafia && p.isAlive).length;
  int get townCount => gamePlayers.where((p) => p.isTown && p.isAlive).length;
}

class GamePlayer {
  final int id;
  final int gameId;
  final int playerId;
  final Role role;
  final bool isAlive;
  final bool isProtected;
  final String? killedBy;
  final DateTime? killedAt;
  final bool revealedRole;

  GamePlayer({
    required this.id,
    required this.gameId,
    required this.playerId,
    required this.role,
    required this.isAlive,
    required this.isProtected,
    this.killedBy,
    this.killedAt,
    required this.revealedRole,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      id: json['id'],
      gameId: json['game'],
      playerId: json['player'],
      role: Role.fromJson(json['role']),
      isAlive: json['is_alive'],
      isProtected: json['is_protected'],
      killedBy: json['killed_by'],
      killedAt: json['killed_at'] != null 
          ? DateTime.parse(json['killed_at']) 
          : null,
      revealedRole: json['revealed_role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game': gameId,
      'player': playerId,
      'role': role.toJson(),
      'is_alive': isAlive,
      'is_protected': isProtected,
      'killed_by': killedBy,
      'killed_at': killedAt?.toIso8601String(),
      'revealed_role': revealedRole,
    };
  }

  bool get isMafia => role.type == 'mafia';
  bool get isTown => role.type == 'town';
  bool get isNeutral => role.type == 'neutral';
}

class NightAction {
  final int id;
  final int gameId;
  final int actorId;
  final int? targetId;
  final String actionType;
  final int dayNumber;
  final bool success;
  final Map<String, dynamic> resultData;
  final DateTime createdAt;

  NightAction({
    required this.id,
    required this.gameId,
    required this.actorId,
    this.targetId,
    required this.actionType,
    required this.dayNumber,
    required this.success,
    required this.resultData,
    required this.createdAt,
  });

  factory NightAction.fromJson(Map<String, dynamic> json) {
    return NightAction(
      id: json['id'],
      gameId: json['game'],
      actorId: json['actor'],
      targetId: json['target'],
      actionType: json['action_type'],
      dayNumber: json['day_number'],
      success: json['success'],
      resultData: Map<String, dynamic>.from(json['result_data'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game': gameId,
      'actor': actorId,
      'target': targetId,
      'action_type': actionType,
      'day_number': dayNumber,
      'success': success,
      'result_data': resultData,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class DayVote {
  final int id;
  final int gameId;
  final int voterId;
  final int? targetId;
  final int dayNumber;
  final bool isChallenge;
  final DateTime createdAt;

  DayVote({
    required this.id,
    required this.gameId,
    required this.voterId,
    this.targetId,
    required this.dayNumber,
    required this.isChallenge,
    required this.createdAt,
  });

  factory DayVote.fromJson(Map<String, dynamic> json) {
    return DayVote(
      id: json['id'],
      gameId: json['game'],
      voterId: json['voter'],
      targetId: json['target'],
      dayNumber: json['day_number'],
      isChallenge: json['is_challenge'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game': gameId,
      'voter': voterId,
      'target': targetId,
      'day_number': dayNumber,
      'is_challenge': isChallenge,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class GamePhase {
  final int id;
  final int gameId;
  final String phaseType;
  final int dayNumber;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isActive;

  GamePhase({
    required this.id,
    required this.gameId,
    required this.phaseType,
    required this.dayNumber,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.isActive,
  });

  factory GamePhase.fromJson(Map<String, dynamic> json) {
    return GamePhase(
      id: json['id'],
      gameId: json['game'],
      phaseType: json['phase_type'],
      dayNumber: json['day_number'],
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time']) 
          : null,
      durationSeconds: json['duration_seconds'],
      isActive: json['is_active'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game': gameId,
      'phase_type': phaseType,
      'day_number': dayNumber,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'is_active': isActive,
    };
  }

  bool get isFinished => endTime != null;
}
