import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/settings_model.dart';
import '../../core/services/api_service.dart';
import 'map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;

  void _openSettingsMenu(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => SettingsBottomSheet(
        onCreateGroup: () async => await _createGroup(bottomSheetContext),
        onJoinGroup: (String code) async => await _joinGroup(bottomSheetContext, code),
      ),
    );
  }

  Future<void> _createGroup(BuildContext bottomSheetContext) async {
    final settings = Provider.of<SettingsModel>(context, listen: false);

    if (settings.runnerName.trim().isEmpty) {
      Navigator.pop(bottomSheetContext);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала введите ваше имя!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = 'runner_${DateTime.now().millisecondsSinceEpoch}';
      final session = await _api.createSession(
        creatorUserId: userId,
        mode: settings.useLeaderMode ? 'with_leader' : 'no_leader',
        maxDistance: settings.maxDistance,
      );

      if (!context.mounted) return;
      setState(() => _isLoading = false);

      if (session == null) {
        Navigator.pop(bottomSheetContext);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка создания группы. Проверьте интернет.'), backgroundColor: Colors.red),
        );
        return;
      }

      // ✅ Сохраняем код асинхронно
      await settings.setSessionCode(session.sessionId);

      // ✅ Безопасно закрываем меню и показываем диалог после завершения анимации
      Navigator.pop(bottomSheetContext);
      if (!context.mounted) return;

      Future.microtask(() {
        if (context.mounted) {
          print('🟢 [DEBUG] Показ диалога с кодом: ${session.sessionId}');
          _showCodeDialog(context, session.sessionId);
        }
      });

    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(bottomSheetContext);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCodeDialog(BuildContext parentContext, String code) {
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Группа создана!', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Отправьте этот код друзьям:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(code, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.greenAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        // ✅ Используем живой parentContext для SnackBar
                        if (parentContext.mounted) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text('Код скопирован!'), duration: Duration(seconds: 1)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('🚀 [DEBUG] Нажата кнопка НАЧАТЬ ПРОБЕЖКУ, код: $code');
                Navigator.pop(dialogContext);
                // ✅ Навигация через живой parentContext
                if (parentContext.mounted) {
                  Navigator.pushReplacement(
                    parentContext,
                    MaterialPageRoute(builder: (_) => MapScreen(sessionCode: code)),
                  );
                }
              },
              child: const Text('НАЧАТЬ ПРОБЕЖКУ', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinGroup(BuildContext bottomSheetContext, String code) async {
    if (code.isEmpty || code.length != 6) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный 6-значный код'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exists = await _api.checkSession(code);
      if (!context.mounted) return;
      setState(() => _isLoading = false);

      if (!exists) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Группа не найдена. Проверьте код.'), backgroundColor: Colors.red),
        );
        return;
      }

      final settings = Provider.of<SettingsModel>(context, listen: false);
      await settings.setSessionCode(code);

      Navigator.pop(bottomSheetContext);
      if (!context.mounted) return;

      print('🚀 [DEBUG] Подключение к группе: $code');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MapScreen(sessionCode: code)),
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка подключения: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1E1E2C), Colors.black],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _openSettingsMenu(context),
                icon: const Icon(Icons.menu),
                label: const Text('МЕНЮ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

// ======================== НИЖНЕЕ МЕНЮ ========================
class SettingsBottomSheet extends StatefulWidget {
  final VoidCallback onCreateGroup;
  final Function(String) onJoinGroup;

  const SettingsBottomSheet({
    super.key,
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsModel>(context, listen: false);
      _nameController.text = settings.runnerName;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsModel>(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Text('Настройки и Вход', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                onChanged: (val) => settings.setRunnerName(val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ваше имя',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.person, color: Colors.blueAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Макс. дистанция', style: TextStyle(color: Colors.white70)),
                  Text('${settings.maxDistance.toInt()} м', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  IconButton(onPressed: settings.decreaseDistance, icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: settings.maxDistance,
                        min: 50,
                        max: 2000,
                        divisions: 39,
                        onChanged: (v) => settings.setMaxDistance(v),
                      ),
                    ),
                  ),
                  IconButton(onPressed: settings.increaseDistance, icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent)),
                ],
              ),

              SwitchListTile(title: const Text('Режим с лидером', style: TextStyle(color: Colors.white)), value: settings.useLeaderMode, onChanged: settings.toggleLeaderMode, activeColor: Colors.blueAccent),
              SwitchListTile(title: const Text('Голосовые подсказки', style: TextStyle(color: Colors.white)), value: settings.voiceEnabled, onChanged: settings.toggleVoice, activeColor: Colors.blueAccent),

              const Divider(color: Colors.white24, thickness: 1, height: 30),

              const Text('Вход в группу', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onCreateGroup,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('СОЗДАТЬ ГРУППУ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 15),
              const Center(child: Text('ИЛИ', style: TextStyle(color: Colors.white38))),
              const SizedBox(height: 15),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
                decoration: InputDecoration(hintText: '000000', hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 5), counterText: '', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onJoinGroup(_codeController.text),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('ПОДКЛЮЧИТЬСЯ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть', style: TextStyle(color: Colors.white54)))),
            ],
          ),
        );
      },
    );
  }
}