import 'package:flutter/material.dart';
import 'splash_screen.dart';

class FinishScreen extends StatelessWidget {
  final double distance;
  final double calories;
  final int duration;
  final String sessionCode;

  const FinishScreen({
    super.key,
    required this.distance,
    required this.calories,
    required this.duration,
    required this.sessionCode,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
              const SizedBox(height: 20),
              const Text('Пробежка завершена!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    _statRow('📏 Дистанция', '${(distance ~/ 10) * 10} м'),
                    const SizedBox(height: 16),
                    _statRow('⏱️ Время', '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'),
                    const SizedBox(height: 16),
                    _statRow('🔥 Калории', '${calories.toStringAsFixed(0)} ккал'),
                    const SizedBox(height: 16),
                    _statRow('🔑 Код группы', sessionCode),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('НА ГЛАВНУЮ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }
}