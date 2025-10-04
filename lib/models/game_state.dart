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
    print('🔍 GameState.fromJson: Parsing JSON...');
    
    // Debug each field
    final phase = json['phase'] ?? 'night'; // استفاده از شب به جای waiting
    print('  - phase: $phase');
    
    final dayNumberRaw = json['day_number'];
    final dayNumber = (dayNumberRaw as int?) ?? 1;
    print('  - day_number: $dayNumberRaw -> $dayNumber');
    
    final winner = json['winner'];
    print('  - winner: $winner');
    
    final alivePlayersRaw = json['alive_players'];
    final players = (alivePlayersRaw as List? ?? [])
        .map((playerJson) => Player.fromJson(playerJson))
        .toList();
    print('  - alive_players: ${players.length} players');
    
    final votes = Map<String, dynamic>.from(json['votes'] ?? {});
    print('  - votes: $votes');
    
    final phaseTimeRemainingRaw = json['phase_time_remaining'];
    final phaseTimeRemaining = (phaseTimeRemainingRaw as int?) ?? 0;
    print('  - phase_time_remaining: $phaseTimeRemainingRaw -> $phaseTimeRemaining');
    
    final playerRole = json['player_role'];
    print('  - player_role: $playerRole');
    
    return GameState(
      phase: phase,
      dayNumber: dayNumber,
      winner: winner,
      players: players,
      votes: votes,
      phaseTimeRemaining: phaseTimeRemaining,
      playerRole: playerRole,
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