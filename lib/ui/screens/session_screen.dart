import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/settings_model.dart';
import '../../core/services/api_service.dart';
import 'map_screen.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ApiService _api = ApiService();
  bool _isLoading = false;
  String? _createdCode;

  Future<void> _createSession() async {
    final settings = Provider.of<SettingsModel>(context, listen: false);
    setState(() => _isLoading = true);

    final userId = 'runner_${DateTime.now().millisecondsSinceEpoch}';
    final session = await _api.createSession(
      creatorUserId: userId,
      mode: settings.useLeaderMode ? 'with_leader' : 'no_leader',
      maxDistance: settings.maxDistance,
    );

    setState(() => _isLoading = false);

    if (session == null) {
      _showError('Ошибка создания группы. Проверьте интернет.');
      return;
    }

    setState(() => _createdCode = session.sessionId);
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) { _showError('Введите код группы'); return; }
    if (code.length != 6) { _showError('Код должен содержать 6 цифр'); return; }

    setState(() => _isLoading = true);
    final exists = await _api.checkSession(code);
    setState(() => _isLoading = false);

    if (!exists) { _showError('Сессия не найдена. Проверьте код.'); return; }

    final settings = Provider.of<SettingsModel>(context, listen: false);
    await settings.setSessionCode(code);
    print('🔗 Подключение к группе: $code');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MapScreen(sessionCode: code)));
  }

  Future<void> _startRun() async {
    if (_createdCode == null) return;
    final settings = Provider.of<SettingsModel>(context, listen: false);
    await settings.setSessionCode(_createdCode!);
    print('🚀 Старт пробежки с кодом: $_createdCode');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MapScreen(sessionCode: _createdCode!)));
  }

  void _copyCode() {
    if (_createdCode != null) {
      Clipboard.setData(ClipboardData(text: _createdCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Код скопирован!'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Run Together', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Бегите вместе. Оставайтесь рядом.', style: TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 40),

              if (_createdCode == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('СОЗДАТЬ ГРУППУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('ИЛИ', style: TextStyle(color: Colors.white38, fontSize: 14)),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 10),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _joinSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('ПОДКЛЮЧИТЬСЯ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                const Text('Ваш код группы:', style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_createdCode!, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8)),
                      const SizedBox(width: 16),
                      IconButton(icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 28), onPressed: _copyCode),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Отправьте код друзьям, затем нажмите "Начать"', style: TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startRun,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('НАЧАТЬ ПРОБЕЖКУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              if (_isLoading) const Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator(color: Colors.blueAccent)),
            ],
          ),
        ),
      ),
    );
  }
}