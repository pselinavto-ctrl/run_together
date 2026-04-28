import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/runner.dart';
import '../models/run_session.dart';

class ApiService {
  static const String baseUrl = 'https://partsview.ru/run_together/api';
  final http.Client client;
  ApiService({http.Client? client}) : client = client ?? http.Client();

  Future<bool> updateLocation({
    required String userId,
    required String sessionId,
    required String name,
    required double lat,
    required double lon,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/update_location.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
          'name': name,
          'lat': lat,
          'lon': lon,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки координат: $e');
      return false;
    }
  }

  Future<List<Runner>> getRunners(String sessionId) async {
    try {
      final url = Uri.parse('$baseUrl/get_locations.php?session_id=$sessionId');
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['runners'] != null) {
          final List runnersJson = data['runners'] as List;
          return runnersJson
              .map((json) => Runner.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Ошибка получения бегунов: $e');
      return [];
    }
  }

  Future<RunSession?> createSession({
    required String creatorUserId,
    required String mode,
    required double maxDistance,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/create_session.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'creator_user_id': creatorUserId,
          'mode': mode,
          'max_distance': maxDistance,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['session'] != null) {
          return RunSession.fromJson(data['session'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка создания сессии: $e');
      return null;
    }
  }

  // ✅ НОВЫЙ: Проверка существования сессии
  Future<bool> checkSession(String sessionId) async {
    try {
      final url = Uri.parse('$baseUrl/check_session.php?session_id=$sessionId');
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка проверки сессии: $e');
      return false;
    }
  }
}