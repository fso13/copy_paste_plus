import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';
import 'package:copy_paste_plus/services/macos_clipboard_service.dart';
import 'package:copy_paste_plus/services/system_tray_service.dart';
import 'package:copy_paste_plus/services/theme_service.dart';
import 'package:copy_paste_plus/services/update_service.dart';
import 'package:copy_paste_plus/theme/app_theme.dart';
import 'package:copy_paste_plus/views/main_window.dart';
import 'package:copy_paste_plus/views/settings_window.dart';
import 'package:copy_paste_plus/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await themeService.load();
  await updateService.load();

  const windowOptions = WindowOptions(
    size: Size(400, 600),
    center: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.hide();
  });

  runApp(const ClipboardManagerApp());
}

class ClipboardManagerApp extends StatefulWidget {
  const ClipboardManagerApp({super.key});

  @override
  State<ClipboardManagerApp> createState() => _ClipboardManagerAppState();
}

class _ClipboardManagerAppState extends State<ClipboardManagerApp> {
  final SystemTrayService _systemTrayService = SystemTrayService();
  final ClipboardManager _clipboardManager = clipboardManager;
  final HotkeyService _hotkeyService = HotkeyService();
  final ThemeService _themeService = themeService;
  final UpdateService _updateService = updateService;

  bool _showWindow = false;
  bool _showSettings = false;
  bool _updatePromptShown = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _initializeServices();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    await _systemTrayService.initialize();
    await _hotkeyService.initialize(_toggleWindow);

    _systemTrayService.onShowWindow.listen((_) {
      _toggleWindow();
    });

    _systemTrayService.onOpenSettings.listen((_) {
      _openSettings();
    });

    // Delayed so tray/hotkey init settles first.
    Future<void>.delayed(const Duration(seconds: 3), _maybeCheckUpdates);
  }

  Future<void> _maybeCheckUpdates() async {
    if (!mounted || _updateService.mode == UpdateCheckMode.disabled) return;

    try {
      final release = await _updateService.checkForUpdates();
      if (release == null || !mounted || _updatePromptShown) return;
      _updatePromptShown = true;

      if (_updateService.mode == UpdateCheckMode.auto) {
        await _updateService.openUpdate(release);
        return;
      }

      setState(() {
        _showWindow = true;
        _showSettings = false;
      });
      await windowManager.show();
      await windowManager.focus();

      final nav = appNavigatorKey.currentContext;
      if (nav != null) {
        await showUpdateAvailableDialog(
          nav,
          release: release,
          updateService: _updateService,
        );
      }
    } catch (_) {
      // Network / API errors are non-fatal.
    }
  }

  Future<void> _toggleWindow() async {
    final willShow = !_showWindow;
    if (willShow) {
      // Capture before we steal focus — needed for auto-paste.
      await MacOSClipboardService.captureFrontmostApp();
    }

    setState(() {
      _showWindow = willShow;
      _showSettings = false;
    });

    if (_showWindow) {
      await windowManager.show();
      await windowManager.focus();
      await _clipboardManager.ensureControllersActive();
      _clipboardManager.refreshStreams();
    } else {
      await windowManager.hide();
    }
  }

  Future<void> _openSettings() async {
    if (!_showWindow) {
      await MacOSClipboardService.captureFrontmostApp();
    }
    setState(() {
      _showSettings = true;
      _showWindow = true;
    });
    await windowManager.show();
    await windowManager.focus();
  }

  void _closeSettings() {
    setState(() {
      _showSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeService.themeMode,
      home: _showWindow
          ? (_showSettings
              ? SettingsWindow(onClose: _closeSettings)
              : MainWindow(
                  onClose: _toggleWindow,
                  onOpenSettings: _openSettings,
                ))
          : const SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _systemTrayService.dispose();
    _hotkeyService.dispose();
    super.dispose();
  }
}
