// lib/models/room.dart
import 'scenario.dart';

class Room {
  final int id;
  final String name;
  final String hostName;
  final int maxPlayers;
  final int currentPlayers;
  final bool isPrivate;
  final String status;
  final DateTime createdAt;
  final Scenario? scenario;

  Room({
    required this.id,
    required this.name,
    required this.hostName,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.isPrivate,
    required this.status,
    required this.createdAt,
    this.scenario,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      hostName: json['host_name'],
      maxPlayers: json['max_players'],
      currentPlayers: json['current_players'],
      isPrivate: json['is_private'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      scenario: json['scenario'] != null ? Scenario.fromJson(json['scenario']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host_name': hostName,
      'max_players': maxPlayers,
      'current_players': currentPlayers,
      'is_private': isPrivate,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'scenario': scenario?.toJson(),
    };
  }
}