import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  final api = ApiService();

  String? sessionId;
  String? userId;
  String? name;

  service.on('startRun').listen((event) {
    if (event != null) {
      sessionId = event['sessionId'] as String?;
      userId = event['userId'] as String?;
      name = event['name'] as String? ?? 'Бегун';
      print('🟢 Background Service: старт сессии $sessionId, имя: $name');
    }
  });

  service.on('stopRun').listen((event) {
    print('🔴 Background Service: остановка');
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 3), (timer) async {
    if (sessionId == null || userId == null) return;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // ✅ Низкая точность + без таймаута = стабильно в фоне на MIUI
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      await api.updateLocation(
        userId: userId!,
        sessionId: sessionId!,
        name: name!,
        lat: position.latitude,
        lon: position.longitude,
      );
      print('📍 BG: координаты отправлены (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})');
    } catch (e) {
      // Логируем только реальные ошибки, не спамим таймаутами
      if (!e.toString().contains('TimeoutException')) {
        print('❌ BG ошибка: $e');
      }
    }
  });
}