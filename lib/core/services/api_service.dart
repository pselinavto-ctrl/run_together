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

  // ✅ Управление статусом сессии (старт/пауза/стоп)
  Future<bool> updateSessionStatus({
    required String sessionId,
    required String action,
    required String userId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/update_session_status.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'action': action,
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления статуса сессии: $e');
      return false;
    }
  }

  // ✅ Возвращает бегунов + метаданные сессии
  Future<Map<String, dynamic>> getRunnersAndSession(String sessionId) async {
    try {
      final url = Uri.parse('$baseUrl/get_locations.php?session_id=$sessionId');
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List runnersJson = data['runners'] as List? ?? [];
          final runners = runnersJson
              .map((json) => Runner.fromJson(json as Map<String, dynamic>))
              .toList();
          final sessionData = data['session'] as Map<String, dynamic>?;
          return {'runners': runners, 'session': sessionData};
        }
      }
      return {'runners': [], 'session': null};
    } catch (e) {
      print('❌ Ошибка получения данных сессии: $e');
      return {'runners': [], 'session': null};
    }
  }

  // ✅ Загрузка точки маршрута
  Future<bool> uploadRoutePoint({
    required String sessionId,
    required String userId,
    required double lat,
    required double lon,
    required int sequence,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/upload_route_point.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'user_id': userId,
          'lat': lat,
          'lon': lon,
          'sequence': sequence,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки точки маршрута: $e');
      return false;
    }
  }

  // ✅ Получение новых точек маршрута
  Future<List<Map<String, dynamic>>> getRoutePoints({
    required String sessionId,
    required int lastSeq,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/get_route_points.php?session_id=$sessionId&last_seq=$lastSeq');
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['points'] != null) {
          return List<Map<String, dynamic>>.from(data['points']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Ошибка загрузки маршрута: $e');
      return [];
    }
  }

  // ✅ Сохранение истории пробежки
  Future<bool> saveRunHistory({
    required String sessionId,
    required String userId,
    required double distance,
    required double calories,
    required int duration,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/save_run_history.php');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'user_id': userId,
          'distance': distance,
          'calories': calories,
          'duration': duration,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка сохранения истории: $e');
      return false;
    }
  }
}