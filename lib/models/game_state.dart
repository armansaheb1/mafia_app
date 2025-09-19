import 'package:mafia_app/models/player.dart';

class GameState {
  final String phase;
  final int dayNumber;
  final String? winner;
  final List<Player> players;
  final Map<String, dynamic> votes;
  final int phaseTimeRemaining;
  final String? playerRole;

  GameState({
    required this.phase,
    required this.dayNumber,
    this.winner,
    required this.players,
    required this.votes,
    this.phaseTimeRemaining = 0,
    this.playerRole,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      phase: json['phase'] ?? 'waiting',
      dayNumber: json['day_number'] ?? 1,
      winner: json['winner'],
      players: (json['alive_players'] as List? ?? [])
          .map((playerJson) => Player.fromJson(playerJson))
          .toList(),
      votes: Map<String, dynamic>.from(json['votes'] ?? {}),
      phaseTimeRemaining: json['phase_time_remaining'] ?? 0,
      playerRole: json['player_role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase,
      'day_number': dayNumber,
      'winner': winner,
      'alive_players': players.map((player) => player.toJson()).toList(),
      'votes': votes,
      'phase_time_remaining': phaseTimeRemaining,
      'player_role': playerRole,
    };
  }

  GameState copyWith({
    String? phase,
    int? dayNumber,
    String? winner,
    List<Player>? players,
    Map<String, dynamic>? votes,
    int? phaseTimeRemaining,
    String? playerRole,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      dayNumber: dayNumber ?? this.dayNumber,
      winner: winner ?? this.winner,
      players: players ?? this.players,
      votes: votes ?? this.votes,
      phaseTimeRemaining: phaseTimeRemaining ?? this.phaseTimeRemaining,
      playerRole: playerRole ?? this.playerRole,
    );
  }
}