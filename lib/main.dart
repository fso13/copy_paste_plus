// lib/main.dart
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';
import 'package:copy_paste_plus/services/system_tray_service.dart';
import 'package:copy_paste_plus/views/main_window.dart';
import 'package:copy_paste_plus/views/settings_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 600),
    center: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.hide();
  });

  runApp(ClipboardManagerApp());
}

class ClipboardManagerApp extends StatefulWidget {
  const ClipboardManagerApp({super.key});

  @override
  _ClipboardManagerAppState createState() => _ClipboardManagerAppState();
}

class _ClipboardManagerAppState extends State<ClipboardManagerApp> {
  final SystemTrayService _systemTrayService = SystemTrayService();
  final ClipboardManager _clipboardManager = ClipboardManager();
  final HotkeyService _hotkeyService = HotkeyService();
  
  bool _showWindow = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _systemTrayService.initialize();
    await _clipboardManager.initialize();
    
    await _hotkeyService.initialize(() {
      _handleHotkeyPress();
    });

    _systemTrayService.onShowWindow.listen((_) {
      _toggleWindow();
    });
  }

  void _handleHotkeyPress() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        await _clipboardManager.forceAddItem(clipboardData.text!);
      }
    } catch (e) {
      print('Error getting clipboard data on hotkey: $e');
    }

    _toggleWindow();
  }

  void _toggleWindow() async {
    setState(() {
      _showWindow = !_showWindow;
      _showSettings = false;
    });

    if (_showWindow) {
      await windowManager.show();
      await windowManager.focus();
      
      // Обновляем данные при открытии окна
      _clipboardManager.refreshStreams();
    } else {
      await windowManager.hide();
    }
  }

  void _openSettings() {
    setState(() {
      _showSettings = true;
      _showWindow = true;
    });
    windowManager.show();
    windowManager.focus();
  }

  void _closeSettings() {
    setState(() {
      _showSettings = false;
    });
  }

  Widget _buildCurrentScreen() {
    if (_showSettings) {
      return SettingsWindow(
        onClose: _closeSettings,
      );
    } else {
      return MainWindow(
        onClose: _toggleWindow,
        onOpenSettings: _openSettings,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clipboard Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: _showWindow ? _buildCurrentScreen() : Container(),
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  void dispose() {
    _systemTrayService.dispose();
    _hotkeyService.dispose();
    _clipboardManager.dispose();
    super.dispose();
  }
}