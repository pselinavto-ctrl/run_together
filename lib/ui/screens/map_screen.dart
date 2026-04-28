import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../core/models/settings_model.dart';
import '../../core/services/api_service.dart';
import '../../core/models/runner.dart';
import '../../core/models/run_session.dart';
import '../../core/services/distance_engine.dart';

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
  RunSession? _currentSession;
  List<Runner> _runners = [];
  Timer? _fetchRunnersTimer;
  bool _isLoading = true;
  late final String _myUserId;
  late String _myRunnerName;
  final List<LatLng> _routePoints = [];
  double _currentGroupDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _myUserId = 'runner_${DateTime.now().millisecondsSinceEpoch}';
    print('🗺️ MapScreen init с кодом: ${widget.sessionCode}');
    _initSessionAndLocation();
  }

  Future<void> _initSessionAndLocation() async {
    final settings = Provider.of<SettingsModel>(context, listen: false);
    _myRunnerName = settings.runnerName.trim().isEmpty ? 'Бегун' : settings.runnerName;

    final sessionCode = widget.sessionCode;
    if (sessionCode.isEmpty) {
      _showError('Код группы не найден');
      return; // ✅ Больше не вызываем pop, чтобы не выкидывало
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
      print('🚀 Фоновый сервис запущен для сессии: $sessionCode');
    } catch (e) {
      print('❌ Ошибка запуска сервиса: $e');
    }

    _startFetchingRunners();
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
      setState(() { _currentLocation = newLoc; _isLoading = false; });
      _mapController.move(newLoc, 16.0);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _startFetchingRunners() {
    _fetchRunnersTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchRunnersAndDistance());
  }

  Future<void> _fetchRunnersAndDistance() async {
    if (_currentSession == null) return;
    final settings = Provider.of<SettingsModel>(context, listen: false);
    try {
      final runners = await _api.getRunners(_currentSession!.sessionId);
      setState(() => _runners = runners);
      if (_runners.length >= 2) {
        final dist = await _distanceEngine.checkAndAnnounce(
          runners: _runners, session: _currentSession!, voiceEnabled: settings.voiceEnabled,
        );
        setState(() => _currentGroupDistance = dist);
      } else {
        setState(() => _currentGroupDistance = 0.0);
      }
    } catch (e) {
      print('⚠️ Ошибка обновления бегунов: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  
  void _stopRun() {
    FlutterBackgroundService().invoke('stopRun');
    _fetchRunnersTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _fetchRunnersTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBroken = _currentSession != null && _currentGroupDistance > _currentSession!.maxDistance;
    
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
          PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 4.0, color: Colors.blueAccent)]),
          MarkerLayer(markers: markers),
        ]),
        if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
        Positioned(top: 50, left: 16, right: 16, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
          child: Row(children: [
            ElevatedButton(onPressed: _stopRun, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Завершить')),
            const SizedBox(width: 12),
            Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(isBroken ? Icons.warning_amber : Icons.straighten, color: isBroken ? Colors.orange : Colors.blueAccent, size: 20),
              const SizedBox(width: 6),
              Text(isBroken ? '⚠️ Разрыв: ${_currentGroupDistance.toInt()} м' : 'Дистанция: ${_currentGroupDistance.toInt()} м',
                style: TextStyle(color: isBroken ? Colors.orangeAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ])),
          ]),
        )),
        Positioned(right: 16, bottom: 32, child: FloatingActionButton(onPressed: _requestLocation, child: const Icon(Icons.my_location))),
      ]),
    );
  }
}