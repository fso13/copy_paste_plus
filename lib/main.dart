import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';
import 'package:copy_paste_plus/services/system_tray_service.dart';
import 'package:copy_paste_plus/views/main_window.dart';
import 'package:copy_paste_plus/views/settings_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'global.dart';

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
  final ClipboardManager _clipboardManager = clipboardManager; // Синглтон
  final HotkeyService _hotkeyService = HotkeyService();
  
  bool _showWindow = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    print('App initState');
    _initializeServices();
  }

@override
Future<void> _initializeServices() async {
  await _systemTrayService.initialize();
  await _hotkeyService.initialize(_toggleWindow);
  
  _systemTrayService.onShowWindow.listen((_) {
    _toggleWindow();
  });

  print('Services initialized with hotkey');
}

  void _toggleWindow() {
    print('Toggling window. Current state: $_showWindow');
    
    setState(() {
      _showWindow = !_showWindow;
      _showSettings = false;
    });

    if (_showWindow) {
      print('Showing window...');
      windowManager.show();
      windowManager.focus();
      
      // Гарантируем что контроллеры активны
      _clipboardManager.ensureControllersActive();
      _clipboardManager.refreshStreams();
      
    } else {
      print('Hiding window...');
      windowManager.hide();
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

  @override
  Widget build(BuildContext context) {
    print('Building app. Show window: $_showWindow, Show settings: $_showSettings');
    
    return MaterialApp(
      home: _showWindow 
          ? (_showSettings 
              ? SettingsWindow(onClose: _closeSettings)
              : MainWindow(
                  onClose: _toggleWindow,
                  onOpenSettings: _openSettings,
                ))
          : Container(),
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  void dispose() {
    print('App dispose');
    _systemTrayService.dispose();
    _hotkeyService.dispose();
    // Не вызываем dispose у ClipboardManager чтобы сохранить состояние
    super.dispose();
  }
}