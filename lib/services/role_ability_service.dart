import '../models/scenario.dart';

class RoleAbilityService {
  // بررسی اینکه آیا نقش می‌تواند در شب عمل کند
  static bool canActAtNight(Role role) {
    return role.abilities.containsKey('kill') ||
           role.abilities.containsKey('investigate') ||
           role.abilities.containsKey('heal') ||
           role.abilities.containsKey('snipe') ||
           role.abilities.containsKey('fake_investigation');
  }

  // بررسی اینکه آیا نقش می‌تواند در روز عمل کند
  static bool canActAtDay(Role role) {
    return role.abilities.containsKey('vote') ||
           role.abilities.containsKey('speak') ||
           role.abilities.containsKey('revenge_kill');
  }

  // بررسی اینکه آیا نقش یک بار در بازی می‌تواند عمل کند
  static bool isOneShot(Role role) {
    return role.abilities['one_shot'] == true;
  }

  // بررسی اینکه آیا نقش می‌تواند کشتن کند
  static bool canKill(Role role) {
    return role.abilities.containsKey('kill') ||
           role.abilities.containsKey('snipe');
  }

  // بررسی اینکه آیا نقش می‌تواند درمان کند
  static bool canHeal(Role role) {
    return role.abilities.containsKey('heal') ||
           role.abilities.containsKey('heal_mafia');
  }

  // بررسی اینکه آیا نقش می‌تواند بررسی کند
  static bool canInvestigate(Role role) {
    return role.abilities.containsKey('investigate') ||
           role.abilities.containsKey('fake_investigation');
  }

  // بررسی اینکه آیا نقش در برابر بررسی مصون است
  static bool isImmuneToInvestigation(Role role) {
    return role.abilities['immune_to_investigation'] == true;
  }

  // بررسی اینکه آیا نقش انتقام می‌گیرد
  static bool hasRevengeKill(Role role) {
    return role.abilities['revenge_kill'] == true;
  }

  // بررسی اینکه آیا نقش خودکشی می‌کند اگر اشتباه عمل کند
  static bool suicideIfWrong(Role role) {
    return role.abilities['suicide_if_wrong'] == true;
  }

  // بررسی اینکه آیا نقش برنده می‌شود اگر اعدام شود
  static bool winsIfLynched(Role role) {
    return role.abilities['win_if_lynched'] == true;
  }

  // بررسی اینکه آیا نقش فراماسون‌ها را می‌شناسد
  static bool knowsMasons(Role role) {
    return role.abilities['know_masons'] == true;
  }

  // دریافت توضیح توانایی‌های نقش
  static String getAbilityDescription(Role role) {
    List<String> abilities = [];
    
    if (role.abilities['vote'] == true) {
      abilities.add('رای‌دهی');
    }
    if (role.abilities['speak'] == true) {
      abilities.add('صحبت کردن');
    }
    if (role.abilities['kill'] == true) {
      abilities.add('کشتن');
    }
    if (role.abilities['investigate'] == true) {
      abilities.add('بررسی کردن');
    }
    if (role.abilities['heal'] == true) {
      abilities.add('درمان کردن');
    }
    if (role.abilities['snipe'] == true) {
      abilities.add('شلیک کردن');
    }
    if (role.abilities['one_shot'] == true) {
      abilities.add('یک بار در بازی');
    }
    if (role.abilities['immune_to_investigation'] == true) {
      abilities.add('مصون از بررسی');
    }
    if (role.abilities['revenge_kill'] == true) {
      abilities.add('انتقام کشی');
    }
    if (role.abilities['fake_investigation'] == true) {
      abilities.add('بررسی جعلی');
    }
    if (role.abilities['know_masons'] == true) {
      abilities.add('شناخت فراماسون‌ها');
    }
    if (role.abilities['win_if_lynched'] == true) {
      abilities.add('برد با اعدام');
    }
    
    return abilities.join('، ');
  }

  // دریافت رنگ نقش بر اساس نوع
  static String getRoleColor(Role role) {
    switch (role.roleType) {
      case 'town':
        return 'blue';
      case 'mafia':
        return 'red';
      case 'neutral':
        return 'orange';
      case 'special':
        return 'purple';
      default:
        return 'grey';
    }
  }

  // دریافت آیکون نقش
  static String getRoleIcon(Role role) {
    switch (role.name) {
      case 'citizen':
        return '👤';
      case 'detective':
        return '🔍';
      case 'doctor':
        return '⚕️';
      case 'sniper':
        return '🎯';
      case 'professional':
        return '💼';
      case 'hidden_cop':
        return '🕵️';
      case 'mason':
        return '🏛️';
      case 'godfather':
        return '👑';
      case 'nato':
        return '⚔️';
      case 'lawyer':
        return '⚖️';
      case 'mafia':
        return '🔫';
      case 'serial_killer':
        return '🔪';
      case 'jester':
        return '🤡';
      default:
        return '❓';
    }
  }
}
