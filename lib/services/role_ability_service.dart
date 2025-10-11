import 'package:flutter/material.dart';
import '../models/scenario.dart';

class RoleAbilityService {
  // بررسی اینکه آیا نقش می‌تواند در شب عمل کند
  static bool canActAtNight(Role role) {
    return role.abilityName == 'kill' ||
           role.abilityName == 'investigate' ||
           role.abilityName == 'heal' ||
           role.abilityName == 'snipe' ||
           role.abilityName == 'fake_investigation' ||
           role.abilityName == 'protect' ||
           role.abilityName == 'professional_shoot' ||
           role.abilityName == 'bulletproof_investigate' ||
           role.abilityName == 'mafia_heal' ||
           role.abilityName == 'mafia_consult';
  }

  // بررسی اینکه آیا نقش می‌تواند در روز عمل کند
  static bool canActAtDay(Role role) {
    return role.abilityName == 'vote' ||
           role.abilityName == 'speak' ||
           role.abilityName == 'revenge_kill' ||
           role.abilityName == 'mayor_power' ||
           role.abilityName == 'silence';
  }

  // بررسی اینکه آیا نقش یک بار در بازی می‌تواند عمل کند
  static bool isOneShot(Role role) {
    return role.abilityName == 'mayor_power' ||
           role.abilityName == 'professional_shoot' ||
           role.abilityName == 'bulletproof_investigate';
  }

  // بررسی اینکه آیا نقش می‌تواند کشتن کند
  static bool canKill(Role role) {
    return role.abilityName == 'kill' ||
           role.abilityName == 'snipe' ||
           role.abilityName == 'professional_shoot';
  }

  // بررسی اینکه آیا نقش می‌تواند درمان کند
  static bool canHeal(Role role) {
    return role.abilityName == 'heal' ||
           role.abilityName == 'mafia_heal';
  }

  // بررسی اینکه آیا نقش می‌تواند تحقیق کند
  static bool canInvestigate(Role role) {
    return role.abilityName == 'investigate' ||
           role.abilityName == 'bulletproof_investigate';
  }

  // بررسی اینکه آیا نقش می‌تواند محافظت کند
  static bool canProtect(Role role) {
    return role.abilityName == 'protect';
  }

  // بررسی اینکه آیا نقش می‌تواند سکوت کند
  static bool canSilence(Role role) {
    return role.abilityName == 'silence';
  }

  // بررسی اینکه آیا نقش می‌تواند قدرت شهردار استفاده کند
  static bool canUseMayorPower(Role role) {
    return role.abilityName == 'mayor_power';
  }

  // بررسی اینکه آیا نقش می‌تواند شلیک حرفه‌ای کند
  static bool canProfessionalShoot(Role role) {
    return role.abilityName == 'professional_shoot';
  }

  // بررسی اینکه آیا نقش می‌تواند تحقیق از مردگان کند
  static bool canInvestigateDead(Role role) {
    return role.abilityName == 'bulletproof_investigate';
  }

  // بررسی اینکه آیا نقش می‌تواند درمان مافیا کند
  static bool canMafiaHeal(Role role) {
    return role.abilityName == 'mafia_heal';
  }

  // بررسی اینکه آیا نقش می‌تواند مشورت مافیا کند
  static bool canMafiaConsult(Role role) {
    return role.abilityName == 'mafia_consult';
  }

  // دریافت نوع قابلیت
  static String getAbilityType(Role role) {
    switch (role.abilityName) {
      case 'kill':
      case 'snipe':
      case 'professional_shoot':
        return 'kill';
      case 'heal':
      case 'mafia_heal':
        return 'heal';
      case 'investigate':
      case 'bulletproof_investigate':
        return 'investigate';
      case 'protect':
        return 'protect';
      case 'silence':
        return 'silence';
      case 'mayor_power':
        return 'mayor_power';
      case 'mafia_consult':
        return 'mafia_consult';
      default:
        return 'none';
    }
  }

  // دریافت ترتیب اجرای قابلیت در شب
  static int getNightOrder(Role role) {
    return role.nightActionOrder;
  }

  // بررسی اینکه آیا نقش قابلیت خاصی دارد
  static bool hasAbility(Role role, String abilityName) {
    return role.abilityName == abilityName;
  }

  // دریافت تمام قابلیت‌های نقش
  static List<String> getRoleAbilities(Role role) {
    if (role.abilityName != null && role.abilityName!.isNotEmpty) {
      return [role.abilityName!];
    }
    return [];
  }

  // بررسی اینکه آیا نقش می‌تواند در فاز خاصی عمل کند
  static bool canActInPhase(Role role, String phase) {
    switch (phase) {
      case 'night':
        return canActAtNight(role);
      case 'day':
        return canActAtDay(role);
      default:
        return false;
    }
  }

  // بررسی اینکه آیا نقش می‌تواند چندین بار عمل کند
  static bool canActMultipleTimes(Role role) {
    return role.abilityName == 'heal' ||
           role.abilityName == 'investigate' ||
           role.abilityName == 'kill' ||
           role.abilityName == 'mafia_consult' ||
           role.abilityName == 'mafia_heal';
  }

  // بررسی اینکه آیا نقش می‌تواند خودش را هدف قرار دهد
  static bool canTargetSelf(Role role) {
    return role.abilityName == 'heal' ||
           role.abilityName == 'mafia_heal';
  }

  // بررسی اینکه آیا نقش می‌تواند مردگان را هدف قرار دهد
  static bool canTargetDead(Role role) {
    return role.abilityName == 'bulletproof_investigate';
  }

  // دریافت آیکون نقش
  static IconData getRoleIcon(Role role) {
    switch (role.abilityName) {
      case 'mayor_power':
        return Icons.account_balance;
      case 'heal':
        return Icons.medical_services;
      case 'investigate':
        return Icons.search;
      case 'kill':
        return Icons.dangerous;
      case 'snipe':
        return Icons.gps_fixed;
      case 'protect':
        return Icons.shield;
      case 'silence':
        return Icons.volume_off;
      case 'professional_shoot':
        return Icons.sports_esports;
      case 'bulletproof_investigate':
        return Icons.visibility;
      case 'mafia_heal':
        return Icons.healing;
      case 'mafia_consult':
        return Icons.group;
      default:
        return Icons.person;
    }
  }

  // دریافت توضیحات قابلیت
  static String getAbilityDescription(Role role) {
    switch (role.abilityName) {
      case 'mayor_power':
        return 'قدرت شهردار: می‌تواند دور دوم رأی‌گیری را ملغی کند یا بازیکنی را مستقیماً حذف کند';
      case 'heal':
        return 'درمان: می‌تواند هر شب یک نفر را از شلیک نجات دهد';
      case 'investigate':
        return 'تحقیق: می‌تواند هر شب یک نفر را بررسی کند';
      case 'kill':
        return 'کشتن: می‌تواند هر شب یک نفر را بکشد';
      case 'snipe':
        return 'تیراندازی: می‌تواند از راه دور شلیک کند';
      case 'protect':
        return 'محافظت: می‌تواند از یک نفر محافظت کند';
      case 'silence':
        return 'سکوت: می‌تواند قدرت مکالمه بازیکنی را بگیرد';
      case 'professional_shoot':
        return 'شلیک حرفه‌ای: می‌تواند مافیا را بکشد اما با شلیک اشتباه می‌میرد';
      case 'bulletproof_investigate':
        return 'تحقیق جان‌سخت: می‌تواند از مردگان تحقیق کند';
      case 'mafia_heal':
        return 'درمان مافیا: می‌تواند از شلیک حرفه‌ای محافظت کند';
      case 'mafia_consult':
        return 'مشورت مافیا: می‌تواند با اعضای مافیا مشورت کند';
      default:
        return 'بدون قابلیت خاص';
    }
  }
}