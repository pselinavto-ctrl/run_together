import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/settings_model.dart';
import '../../core/services/api_service.dart';
import '../../core/models/runner.dart';
import '../../core/models/run_session.dart';
import '../../core/services/distance_engine.dart';
import 'splash_screen.dart';
import 'finish_screen.dart';

class MapScreen extends StatefulWidget {
  final String sessionCode;
  const MapScreen({super.key, required this.sessionCode});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Location _locationService = Location();
  final ApiService _api = ApiService();
  final DistanceEngine _distanceEngine = DistanceEngine();

  LatLng? _currentLocation;
  LatLng? _lastLocation;
  RunSession? _currentSession;
  List<Runner> _runners = [];
  Timer? _statusTimer;
  Timer? _routeSyncTimer;
  StreamSubscription<LocationData>? _locationStream;
  bool _isLoading = true;
  bool _hasAutoZoomed = false;
  late final String _myUserId;
  late String _myRunnerName;
  
  final List<LatLng> _routePoints = [];
  int _lastRouteSeq = 0;
  int _myRouteSeq = 0;

  double _myDistance = 0.0;
  double _calories = 0.0;
  int _greenCount = 0;
  int _redCount = 0;
  double _currentGroupDistance = 0.0;

  int _elapsedSeconds = 0;
  bool _isCountdownActive = false;
  int _countdownValue = 3;

  bool _isReassigning = false;

  @override
  void initState() {
    super.initState();
    _myUserId = 'runner_${DateTime.now().millisecondsSinceEpoch}';
    _initSessionAndLocation();
    _startStatusPolling();
    _startLocalTracking();
    _startRouteSync();
  }

  Future<void> _initSessionAndLocation() async {
    final settings = Provider.of<SettingsModel>(context, listen: false);
    _myRunnerName = settings.runnerName.trim().isEmpty ? 'Бегун' : settings.runnerName;

    final sessionCode = widget.sessionCode;
    if (sessionCode.isEmpty) {
      _showError('Код группы не найден');
      return;
    }

    _currentSession = RunSession(
      sessionId: sessionCode,
      mode: settings.useLeaderMode ? 'with_leader' : 'no_leader',
      maxDistance: settings.maxDistance,
      leaderId: null,
      createdAt: DateTime.now(),
    );

    await _requestLocation();

    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      service.invoke('startRun', {
        'sessionId': sessionCode,
        'userId': _myUserId,
        'name': _myRunnerName,
      });
    } catch (e) {
      print('❌ Ошибка запуска сервиса: $e');
    }
  }

  void _startLocalTracking() {
    _locationStream = _locationService.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        final newLoc = LatLng(loc.latitude!, loc.longitude!);

        if (_lastLocation != null && _currentSession?.status == 'active') {
          final delta = Geolocator.distanceBetween(
            _lastLocation!.latitude, _lastLocation!.longitude,
            newLoc.latitude, newLoc.longitude,
          );

          if (delta > 2 && delta < 50) {
            final settings = Provider.of<SettingsModel>(context, listen: false);
            setState(() {
              _myDistance += delta;
              _calories = (_myDistance / 1000) * settings.weight * 1.036;
            });

            if (_routePoints.isEmpty || Geolocator.distanceBetween(
                _routePoints.last.latitude, _routePoints.last.longitude,
                newLoc.latitude, newLoc.longitude) > 5.0) {
              setState(() => _routePoints.add(newLoc));
            }
          }
        }

        setState(() {
          _lastLocation = newLoc;
          _currentLocation = newLoc;
        });
        _mapController.move(newLoc, _mapController.camera.zoom);
      }
    });
  }

  void _startRouteSync() {
    _routeSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_currentSession == null) return;
      final isLeader = _currentSession?.leaderId == null || _currentSession?.leaderId == _myUserId;

      if (isLeader && _currentSession?.status == 'active' && _routePoints.isNotEmpty) {
        final lastPoint = _routePoints.last;
        _myRouteSeq++;
        await _api.uploadRoutePoint(
          sessionId: _currentSession!.sessionId,
          userId: _myUserId,
          lat: lastPoint.latitude,
          lon: lastPoint.longitude,
          sequence: _myRouteSeq,
        );
      }

      final newPoints = await _api.getRoutePoints(
        sessionId: _currentSession!.sessionId,
        lastSeq: _lastRouteSeq,
      );

      if (newPoints.isNotEmpty) {
        setState(() {
          for (var p in newPoints) {
            final pt = LatLng(p['lat'], p['lon']);
            if (_routePoints.isEmpty || Geolocator.distanceBetween(
                _routePoints.last.latitude, _routePoints.last.longitude,
                pt.latitude, pt.longitude) > 2.0) {
              _routePoints.add(pt);
            }
          }
          _lastRouteSeq = newPoints.last['sequence'];
        });
      }
    });
  }

  Future<void> _requestLocation() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) throw 'Геолокация отключена';
      }
      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) throw 'Нет разрешения';
      }
      final loc = await _locationService.getLocation();
      final newLoc = LatLng(loc.latitude!, loc.longitude!);
      setState(() { _currentLocation = newLoc; _lastLocation = newLoc; _isLoading = false; });
      _mapController.move(newLoc, 16.0);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchRunnersAndDistance());
  }

  Future<void> _fetchRunnersAndDistance() async {
    if (_currentSession == null) return;
    final settings = Provider.of<SettingsModel>(context, listen: false);

    try {
      final data = await _api.getRunnersAndSession(_currentSession!.sessionId);
      final runners = data['runners'] as List<Runner>;
      final sessData = data['session'] as Map<String, dynamic>?;

      if (sessData != null) {
        _currentSession = _currentSession!.copyWith(
          status: sessData['status'] ?? 'waiting',
          startTime: sessData['started_at'] != null ? DateTime.parse(sessData['started_at']) : null,
          pausedDuration: sessData['paused_duration'] ?? 0,
          leaderId: sessData['leader_id'],
        );

        if (_currentSession!.status == 'active' && _currentSession!.startTime != null) {
          final diff = DateTime.now().difference(_currentSession!.startTime!).inSeconds;
          if (diff < 3 && !_isCountdownActive) _startCountdown();
          _elapsedSeconds = diff - _currentSession!.pausedDuration;
          if (_elapsedSeconds < 0) _elapsedSeconds = 0;
          if (!_hasAutoZoomed && _currentLocation != null) {
            _hasAutoZoomed = true;
            _mapController.move(_currentLocation!, 17.5);
          }
        }

        // ✅ Авто-смена лидера, если текущий не обновлялся >30 сек
        if (_currentSession!.status == 'active' && !_isReassigning && _currentSession!.leaderId != null) {
          final leader = runners.where((r) => r.userId == _currentSession!.leaderId).firstOrNull;
          if (leader != null && leader.updatedAt != null) {
            // ✅ ИСПРАВЛЕНО: updatedAt уже DateTime, парсить строку не нужно
            final lastUpdate = leader.updatedAt!;
            if (DateTime.now().difference(lastUpdate).inSeconds > 30) {
              _isReassigning = true;
              print('⚠️ Лидер пропал, переназначение...');
              await _api.updateSessionStatus(
                sessionId: _currentSession!.sessionId,
                action: 'reassign_leader',
                userId: _myUserId,
              );
              _isReassigning = false;
            }
          }
        }
      }

      setState(() => _runners = runners);

      if (_currentLocation != null && runners.isNotEmpty && _currentSession != null) {
        int g = 0, r = 0;
        for (var runner in runners) {
          if (runner.userId == _myUserId) continue;
          double dist = Geolocator.distanceBetween(
            _currentLocation!.latitude, _currentLocation!.longitude,
            runner.lat, runner.lon,
          );
          if (dist <= _currentSession!.maxDistance) g++; else r++;
        }
        setState(() { _greenCount = g; _redCount = r; });
      }

      if (_runners.length >= 2) {
        final dist = await _distanceEngine.checkAndAnnounce(
          runners: _runners, session: _currentSession!, voiceEnabled: settings.voiceEnabled,
        );
        setState(() => _currentGroupDistance = dist);
      } else {
        setState(() => _currentGroupDistance = 0.0);
      }
    } catch (e) {
      print('⚠️ Ошибка обновления сессии: $e');
    }
  }

  void _startCountdown() {
    if (!mounted) return;
    setState(() { _isCountdownActive = true; _countdownValue = 3; });
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _countdownValue--);
      if (_countdownValue < 1) {
        timer.cancel();
        setState(() => _isCountdownActive = false);
      }
    });
  }

  Future<void> _controlSession(String action) async {
    final success = await _api.updateSessionStatus(
      sessionId: _currentSession!.sessionId,
      action: action,
      userId: _myUserId,
    );
    if (success) {
      print('✅ Сессия: $action');
      if (action == 'stop') _stopRun();
    } else {
      _showError('Не удалось выполнить действие');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
  );

  Future<void> _stopRun() async {
    FlutterBackgroundService().invoke('stopRun');
    _statusTimer?.cancel();
    _routeSyncTimer?.cancel();
    _locationStream?.cancel();

    await _api.saveRunHistory(
      sessionId: _currentSession!.sessionId,
      userId: _myUserId,
      distance: _myDistance,
      calories: _calories,
      duration: _elapsedSeconds,
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => FinishScreen(
        distance: _myDistance,
        calories: _calories,
        duration: _elapsedSeconds,
        sessionCode: _currentSession!.sessionId,
      )),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _routeSyncTimer?.cancel();
    _locationStream?.cancel();
    super.dispose();
  }

  Widget _statItem(String icon, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBroken = _currentSession != null && _currentGroupDistance > _currentSession!.maxDistance;
    final isLeader = _currentSession?.leaderId == null || _currentSession?.leaderId == _myUserId;
    final status = _currentSession?.status ?? 'waiting';

    final markers = _runners.where((r) => r.userId != _myUserId).map((r) => Marker(
      point: LatLng(r.lat, r.lon), width: 80, height: 80,
      child: Column(children: [
        const Icon(Icons.person_pin_circle, color: Colors.green, size: 40),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30)),
          child: Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    )).toList();

    if (_currentLocation != null) {
      markers.add(Marker(point: _currentLocation!, width: 80, height: 80, child: Column(children: [
        const Icon(Icons.my_location, color: Colors.blue, size: 40),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30)),
          child: Text(_myRunnerName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ])));
    }

    return Scaffold(
      body: Stack(children: [
        FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: _currentLocation ?? const LatLng(55.7558, 37.6176), initialZoom: 16.0), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.run_together'),
          PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5.0, color: Colors.blueAccent)]),
          MarkerLayer(markers: markers),
        ]),
        if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
        
        if (_isCountdownActive)
          Container(color: Colors.black87, child: Center(child: Text('$_countdownValue', style: const TextStyle(color: Colors.greenAccent, fontSize: 120, fontWeight: FontWeight.bold)))),

        Positioned(
          top: 50, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _statItem('⏱️', '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}'),
                  _statItem('📏', '${(_myDistance ~/ 10) * 10} м'),
                  _statItem('🔥', '${_calories.toStringAsFixed(0)} ккал'),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('🟢 В зоне: $_greenCount', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('🔴 Отстали: $_redCount', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))),
                ]),
                const SizedBox(height: 10),
                if (isLeader)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (status == 'waiting')
                      SizedBox(
                        width: 180,
                        child: ElevatedButton(
                          onPressed: () => _controlSession('start'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                          child: const Text('СТАРТ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      )
                    else
                      Row(children: [
                        ElevatedButton(
                          onPressed: status == 'active' ? () => _controlSession('pause') : (status == 'paused' ? () => _controlSession('resume') : null),
                          style: ElevatedButton.styleFrom(backgroundColor: status == 'paused' ? Colors.greenAccent : Colors.orangeAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                          child: Text(status == 'paused' ? 'ДАЛЕЕ' : 'ПАУЗА', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _controlSession('stop'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                          child: const Text('СТОП', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ]),
                  ])
                else
                  Text(
                    status == 'waiting' ? '⏳ Ожидание старта...' : status == 'paused' ? '⏸️ Пауза' : '🏃 Пробежка идёт',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
        Positioned(right: 16, bottom: 32, child: FloatingActionButton(onPressed: _requestLocation, child: const Icon(Icons.my_location))),
      ]),
    );
  }
}