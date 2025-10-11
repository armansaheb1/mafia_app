import '../models/scenario.dart';
import '../models/player.dart';
import 'role_ability_service.dart';

class GameLogicService {
  // تخصیص نقش‌ها بر اساس سناریو
  static List<Player> assignRoles(List<Player> players, Scenario scenario) {
    if (players.length < scenario.minPlayers || players.length > scenario.maxPlayers) {
      throw Exception('تعداد بازیکنان مناسب نیست');
    }

    // ایجاد لیست نقش‌ها بر اساس سناریو
    List<Role> rolesToAssign = [];
    for (final role in scenario.roles) {
      // هر نقش یک بار اضافه می‌شود (چون دیگر count نداریم)
      rolesToAssign.add(role);
    }

    // بررسی تعداد نقش‌ها
    if (rolesToAssign.length != players.length) {
      throw Exception('تعداد نقش‌ها با تعداد بازیکنان مطابقت ندارد');
    }

    // مخلوط کردن نقش‌ها
    rolesToAssign.shuffle();

    // تخصیص نقش‌ها به بازیکنان
    List<Player> updatedPlayers = [];
    for (int i = 0; i < players.length; i++) {
      updatedPlayers.add(players[i].copyWith(role: rolesToAssign[i]));
    }

    return updatedPlayers;
  }

  // بررسی شرایط برد
  static String? checkWinCondition(List<Player> players) {
    final alivePlayers = players.where((p) => p.isAlive).toList();
    final mafiaPlayers = alivePlayers.where((p) => p.role?.isMafia == true).toList();
    final townPlayers = alivePlayers.where((p) => p.role?.isTown == true).toList();
    final neutralPlayers = alivePlayers.where((p) => p.role?.isNeutral == true).toList();

    // برد مافیا
    if (mafiaPlayers.length >= townPlayers.length) {
      return 'mafia';
    }

    // برد شهروندان
    if (mafiaPlayers.isEmpty) {
      return 'town';
    }

    // برد نقش‌های خنثی (اگر فقط آن‌ها باقی مانده باشند)
    if (townPlayers.isEmpty && mafiaPlayers.isEmpty && neutralPlayers.isNotEmpty) {
      return 'neutral';
    }

    return null; // بازی ادامه دارد
  }

  // دریافت بازیکنان بر اساس نوع نقش
  static List<Player> getPlayersByRoleType(List<Player> players, String roleType) {
    return players.where((p) => p.role?.roleType == roleType).toList();
  }

  // دریافت بازیکنان زنده
  static List<Player> getAlivePlayers(List<Player> players) {
    return players.where((p) => p.isAlive).toList();
  }

  // دریافت بازیکنان مرده
  static List<Player> getDeadPlayers(List<Player> players) {
    return players.where((p) => !p.isAlive).toList();
  }

  // دریافت بازیکنان مافیا زنده
  static List<Player> getAliveMafiaPlayers(List<Player> players) {
    return players.where((p) => p.isAlive && p.role?.isMafia == true).toList();
  }

  // دریافت بازیکنان شهر زنده
  static List<Player> getAliveTownPlayers(List<Player> players) {
    return players.where((p) => p.isAlive && p.role?.isTown == true).toList();
  }

  // دریافت بازیکنان با توانایی خاص
  static List<Player> getPlayersWithAbility(List<Player> players, String ability) {
    return players.where((p) => 
      p.isAlive && 
      p.role != null && 
      p.role!.abilityName == ability
    ).toList();
  }

  // دریافت بازیکنان که می‌توانند در شب عمل کنند
  static List<Player> getNightActionPlayers(List<Player> players) {
    return players.where((p) => 
      p.isAlive && 
      p.role != null && 
      RoleAbilityService.canActAtNight(p.role!)
    ).toList();
  }

  // دریافت بازیکنان که می‌توانند در روز عمل کنند
  static List<Player> getDayActionPlayers(List<Player> players) {
    return players.where((p) => 
      p.isAlive && 
      p.role != null && 
      RoleAbilityService.canActAtDay(p.role!)
    ).toList();
  }

  // محاسبه رای‌ها
  static Map<String, int> calculateVotes(List<Player> players, Map<String, String> votes) {
    Map<String, int> voteCount = {};
    
    for (final player in players) {
      if (player.isAlive && votes.containsKey(player.username)) {
        final votedFor = votes[player.username]!;
        voteCount[votedFor] = (voteCount[votedFor] ?? 0) + 1;
        
        // رای دو برابر برای شهردار
        if (player.role?.abilityName == 'double_vote') {
          voteCount[votedFor] = (voteCount[votedFor] ?? 0) + 1;
        }
      }
    }
    
    return voteCount;
  }

  // دریافت بازیکن با بیشترین رای
  static String? getMostVotedPlayer(Map<String, int> voteCount) {
    if (voteCount.isEmpty) return null;
    
    String mostVoted = voteCount.keys.first;
    int maxVotes = voteCount[mostVoted]!;
    
    for (final entry in voteCount.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        mostVoted = entry.key;
      }
    }
    
    return mostVoted;
  }

  // بررسی اینکه آیا بازیکن می‌تواند عمل کند
  static bool canPlayerAct(Player player, String action) {
    if (!player.isAlive || player.role == null) return false;
    
    switch (action) {
      case 'kill':
        return RoleAbilityService.canKill(player.role!);
      case 'heal':
        return RoleAbilityService.canHeal(player.role!);
      case 'investigate':
        return RoleAbilityService.canInvestigate(player.role!);
      case 'vote':
        return player.role!.abilityName == 'vote';
      case 'speak':
        return player.role!.abilityName == 'speak';
      default:
        return false;
    }
  }

  // دریافت اطلاعات بازی
  static Map<String, dynamic> getGameInfo(List<Player> players) {
    final alivePlayers = getAlivePlayers(players);
    final mafiaPlayers = getAliveMafiaPlayers(players);
    final townPlayers = getAliveTownPlayers(players);
    final neutralPlayers = alivePlayers.where((p) => p.role?.isNeutral == true).toList();
    
    return {
      'total_players': players.length,
      'alive_players': alivePlayers.length,
      'mafia_count': mafiaPlayers.length,
      'town_count': townPlayers.length,
      'neutral_count': neutralPlayers.length,
      'winner': checkWinCondition(players),
    };
  }
}
