import 'package:mafia_app/models/player.dart';

class GameState {
  final String phase;
  final int dayNumber;
  final String? winner;
  final List<Player> players;
  final Map<String, dynamic> votes;

  GameState({
    required this.phase,
    required this.dayNumber,
    this.winner,
    required this.players,
    required this.votes,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      phase: json['phase'] ?? 'waiting',
      dayNumber: json['day_number'] ?? 1,
      winner: json['winner'],
      players: (json['players'] as List? ?? [])
          .map((playerJson) => Player.fromJson(playerJson))
          .toList(),
      votes: Map<String, dynamic>.from(json['votes'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase,
      'day_number': dayNumber,
      'winner': winner,
      'players': players.map((player) => player.toJson()).toList(),
      'votes': votes,
    };
  }
}