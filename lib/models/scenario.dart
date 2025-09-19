class Scenario {
  final int id;
  final String name;
  final String description;
  final int minPlayers;
  final int maxPlayers;
  final bool isActive;
  final String? image;
  final String? imageUrl;
  final List<ScenarioRole> scenarioRoles;

  Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.minPlayers,
    required this.maxPlayers,
    required this.isActive,
    this.image,
    this.imageUrl,
    required this.scenarioRoles,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      minPlayers: json['min_players'],
      maxPlayers: json['max_players'],
      isActive: json['is_active'],
      image: json['image'],
      imageUrl: json['image_url'],
      scenarioRoles: (json['scenario_roles'] as List? ?? [])
          .map((roleJson) => ScenarioRole.fromJson(roleJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'is_active': isActive,
      'image': image,
      'image_url': imageUrl,
      'scenario_roles': scenarioRoles.map((role) => role.toJson()).toList(),
    };
  }
}

class ScenarioRole {
  final int id;
  final Role role;
  final int count;
  final bool isRequired;

  ScenarioRole({
    required this.id,
    required this.role,
    required this.count,
    required this.isRequired,
  });

  factory ScenarioRole.fromJson(Map<String, dynamic> json) {
    return ScenarioRole(
      id: json['id'],
      role: Role.fromJson(json['role']),
      count: json['count'],
      isRequired: json['is_required'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toJson(),
      'count': count,
      'is_required': isRequired,
    };
  }
}

class Role {
  final int id;
  final String name;
  final String displayName;
  final String roleType;
  final String description;
  final Map<String, dynamic> abilities;

  Role({
    required this.id,
    required this.name,
    required this.displayName,
    required this.roleType,
    required this.description,
    required this.abilities,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      roleType: json['role_type'],
      description: json['description'],
      abilities: Map<String, dynamic>.from(json['abilities'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'role_type': roleType,
      'description': description,
      'abilities': abilities,
    };
  }

  // Helper methods
  bool get isTown => roleType == 'town';
  bool get isMafia => roleType == 'mafia';
  bool get isNeutral => roleType == 'neutral';
  bool get isSpecial => roleType == 'special';
}
