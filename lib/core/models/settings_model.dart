import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel extends ChangeNotifier {
  bool _useLeaderMode = false;
  double _maxDistance = 500.0;
  bool _voiceEnabled = true;
  String _runnerName = '';
  String _sessionCode = '';

  bool get useLeaderMode => _useLeaderMode;
  double get maxDistance => _maxDistance;
  bool get voiceEnabled => _voiceEnabled;
  String get runnerName => _runnerName;
  String get sessionCode => _sessionCode;

  SettingsModel() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _useLeaderMode = prefs.getBool('use_leader_mode') ?? false;
    _maxDistance = prefs.getDouble('max_distance') ?? 500.0;
    _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
    _runnerName = prefs.getString('runner_name') ?? '';
    _sessionCode = prefs.getString('session_code') ?? '';
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_leader_mode', _useLeaderMode);
    await prefs.setDouble('max_distance', _maxDistance);
    await prefs.setBool('voice_enabled', _voiceEnabled);
    await prefs.setString('runner_name', _runnerName);
    await prefs.setString('session_code', _sessionCode);
  }

  Future<void> toggleLeaderMode(bool value) async {
    _useLeaderMode = value;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> increaseDistance() async {
    _maxDistance += 50;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> decreaseDistance() async {
    if (_maxDistance > 50) _maxDistance -= 50;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> toggleVoice(bool value) async {
    _voiceEnabled = value;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> setRunnerName(String name) async {
    _runnerName = name;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> setSessionCode(String code) async {
    _sessionCode = code.trim();
    await _saveToPrefs();
    notifyListeners();
  }

  // ✅ Добавлено для плавной работы слайдера дистанции
  Future<void> setMaxDistance(double value) async {
    _maxDistance = value;
    await _saveToPrefs();
    notifyListeners();
  }
}