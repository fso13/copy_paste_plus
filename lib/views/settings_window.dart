import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsWindow extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsWindow({required this.onClose});

  @override
  _SettingsWindowState createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  final ClipboardManager _clipboardManager = clipboardManager;
  late int _maxItems;
  bool _launchAtStartup = false;

  @override
  void initState() {
    super.initState();
    _maxItems = _clipboardManager.maxItems;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _launchAtStartup = prefs.getBool('auto_start_enabled') ?? false;
    setState(() {});
  }

  Future<void> _setAutoStartEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start_enabled', enabled);
    setState(() => _launchAtStartup = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Запуск при старте системы'),
            trailing: Switch(
              value: _launchAtStartup,
              onChanged: _setAutoStartEnabled,
            ),
          ),
          ListTile(
            title: const Text('Максимум элементов истории'),
            subtitle: Slider(
              value: _maxItems.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              onChanged: (value) {
                setState(() => _maxItems = value.toInt());
              },
              onChangeEnd: (value) {
                _clipboardManager.setMaxItems(value.toInt());
              },
            ),
            trailing: Text('$_maxItems'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _clipboardManager.debugPrintState();
            },
            child: const Text('Отладочная информация'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Очистка истории
              clipboardManager.clearHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[100],
            ),
            child: const Text('Очистить историю'),
          ),
        ],
      ),
    );
  }
}