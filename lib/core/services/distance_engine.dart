import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../models/runner.dart';
import '../models/run_session.dart';

class DistanceEngine {
  final FlutterTts _tts = FlutterTts();

  bool _isBroken = false;
  bool _isSpeaking = false;

  DateTime _lastTtsTime =
      DateTime.now().subtract(const Duration(seconds: 60));

  static const _ttsCooldown = Duration(seconds: 30);

  DistanceEngine() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  /// Главный метод
  Future<double> checkAndAnnounce({
    required List<Runner> runners,
    required RunSession session,
    required bool voiceEnabled,
  }) async {
    if (runners.length < 2) return 0.0;

    final maxDistance = _calculateMaxDistance(runners, session);
    final now = DateTime.now();

    final cooldownPassed =
        now.difference(_lastTtsTime) > _ttsCooldown;

    /// 🔴 ГРУППА РАЗОРВАНА
    if (maxDistance > session.maxDistance &&
        !_isBroken &&
        cooldownPassed) {
      _isBroken = true;
      _lastTtsTime = now;

      if (voiceEnabled) {
        await _safeSpeak(
          'Группа растянулась на ${maxDistance.toInt()} метров',
        );
      }
    }

    /// 🟢 ГРУППА ВМЕСТЕ
    else if (maxDistance <= session.maxDistance &&
        _isBroken &&
        cooldownPassed) {
      _isBroken = false;
      _lastTtsTime = now;

      if (voiceEnabled) {
        await _safeSpeak('Группа снова вместе');
      }
    }

    return maxDistance;
  }

  /// 📏 Расчёт дистанции
  double _calculateMaxDistance(
      List<Runner> runners, RunSession session) {
    if (session.mode == 'with_leader' &&
        session.leaderId != null) {
      final leader = runners.firstWhere(
        (r) => r.userId == session.leaderId,
        orElse: () => runners.first,
      );

      double maxDist = 0.0;

      for (var r in runners) {
        final dist = _distanceBetween(
          leader.lat,
          leader.lon,
          r.lat,
          r.lon,
        );

        if (dist > maxDist) maxDist = dist;
      }

      return maxDist;
    }

    /// без лидера
    double maxDist = 0.0;

    for (int i = 0; i < runners.length; i++) {
      for (int j = i + 1; j < runners.length; j++) {
        final dist = _distanceBetween(
          runners[i].lat,
          runners[i].lon,
          runners[j].lat,
          runners[j].lon,
        );

        if (dist > maxDist) maxDist = dist;
      }
    }

    return maxDist;
  }

  /// 📐 Реальный расчёт расстояния
  double _distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(
      lat1,
      lon1,
      lat2,
      lon2,
    );
  }

  /// 🔊 Безопасная озвучка
  Future<void> _safeSpeak(String text) async {
    if (_isSpeaking) return;

    _isSpeaking = true;

    await _tts.stop(); // на всякий случай
    await _tts.speak(text);
  }
}