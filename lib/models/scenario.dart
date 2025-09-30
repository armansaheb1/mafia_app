class Scenario {
  final int id;
  final String name;
  final String description;
  final int minPlayers;
  final int maxPlayers;
  final bool isActive;
  final String? image;
  final String? imageUrl;
  final List<Role> roles;

  Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.minPlayers,
    required this.maxPlayers,
    required this.isActive,
    this.image,
    this.imageUrl,
    required this.roles,
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
      roles: (json['roles'] as List? ?? [])
          .map((roleJson) => Role.fromJson(roleJson))
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
      'roles': roles.map((role) => role.toJson()).toList(),
    };
  }

  // Helper methods
  int get roleCount => roles.length;
  int get townRoleCount => roles.where((role) => role.isTown).length;
  int get mafiaRoleCount => roles.where((role) => role.isMafia).length;
  int get neutralRoleCount => roles.where((role) => role.isNeutral).length;
  int get activeRoleCount => roles.where((role) => role.isActive).length;
}


class Role {
  final int id;
  final String name;
  final String displayName;
  final String roleType;
  final String description;
  final String? abilityName;
  final int nightActionOrder;
  final bool isActive;

  Role({
    required this.id,
    required this.name,
    required this.displayName,
    required this.roleType,
    required this.description,
    this.abilityName,
    required this.nightActionOrder,
    required this.isActive,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    print('🔍 Role.fromJson: Parsing role ${json['display_name']}...');
    
    return Role(
      id: (json['id'] as int?) ?? 0,
      name: json['name'] ?? 'Unknown',
      displayName: json['display_name'] ?? 'Unknown',
      roleType: json['role_type'] ?? 'town',
      description: json['description'] ?? '',
      abilityName: json['ability_name'],
      nightActionOrder: json['night_action_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'role_type': roleType,
      'description': description,
      'ability_name': abilityName,
      'night_action_order': nightActionOrder,
      'is_active': isActive,
    };
  }

  // Helper methods
  bool get isTown => roleType == 'town';
  bool get isMafia => roleType == 'mafia';
  bool get isNeutral => roleType == 'neutral';
  bool get isSpecial => roleType == 'special';
  bool get hasNightAction => nightActionOrder > 0;
  bool get hasAbility => abilityName != null && abilityName!.isNotEmpty;
}
