import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scenario.dart';
import 'api_interceptor.dart';
import 'platform_service.dart';

class ScenarioService {
  static String get baseUrl => '${PlatformService.getBaseUrl()}/api/game';

  // دریافت لیست تمام سناریوها
  static Future<List<Scenario>> getScenarios() async {
    try {
      final response = await ApiInterceptor.authenticatedRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/scenarios/'),
          headers: await ApiInterceptor.getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Scenario.fromJson(json)).toList();
      } else {
        throw Exception('خطا در دریافت سناریوها: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('خطا در اتصال: $e');
    }
  }

  // دریافت جزئیات یک سناریو خاص
  static Future<Scenario> getScenario(int scenarioId) async {
    try {
      final response = await ApiInterceptor.authenticatedRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/scenarios/$scenarioId/'),
          headers: await ApiInterceptor.getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Scenario.fromJson(data);
      } else {
        throw Exception('خطا در دریافت سناریو: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('خطا در اتصال: $e');
    }
  }

  // دریافت لیست تمام نقش‌ها
  static Future<List<Role>> getRoles() async {
    try {
      final response = await ApiInterceptor.authenticatedRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/roles/'),
          headers: await ApiInterceptor.getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Role.fromJson(json)).toList();
      } else {
        throw Exception('خطا در دریافت نقش‌ها: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('خطا در اتصال: $e');
    }
  }

  // بررسی اینکه آیا تعداد بازیکنان برای سناریو مناسب است
  static bool isPlayerCountValid(Scenario scenario, int playerCount) {
    return playerCount >= scenario.minPlayers && playerCount <= scenario.maxPlayers;
  }

  // دریافت نقش‌های شهروندان در یک سناریو
  static List<Role> getTownRoles(Scenario scenario) {
    return scenario.roles
        .where((role) => role.isTown)
        .toList();
  }

  // دریافت نقش‌های مافیا در یک سناریو
  static List<Role> getMafiaRoles(Scenario scenario) {
    return scenario.roles
        .where((role) => role.isMafia)
        .toList();
  }

  // دریافت نقش‌های خنثی در یک سناریو
  static List<Role> getNeutralRoles(Scenario scenario) {
    return scenario.roles
        .where((role) => role.isNeutral)
        .toList();
  }

  // دریافت نقش‌های ویژه در یک سناریو
  static List<Role> getSpecialRoles(Scenario scenario) {
    return scenario.roles
        .where((role) => role.isSpecial)
        .toList();
  }
}
