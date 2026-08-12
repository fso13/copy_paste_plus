import 'dart:async';

import 'package:copy_paste_plus/utils/app_exit.dart';
import 'package:system_tray/system_tray.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final StreamController<void> _showWindowController =
      StreamController.broadcast();
  final StreamController<void> _openSettingsController =
      StreamController.broadcast();
  final StreamController<void> _toggleWindowController =
      StreamController.broadcast();

  /// Force-show the main window (tray menu «Показать»).
  Stream<void> get onShowWindow => _showWindowController.stream;

  /// Open settings (tray menu «Настройки»).
  Stream<void> get onOpenSettings => _openSettingsController.stream;

  /// Toggle show/hide (left-click on tray icon).
  Stream<void> get onToggleWindow => _toggleWindowController.stream;

  Future<void> initialize() async {
    try {
      await _systemTray.initSystemTray(
        iconPath: 'assets/AppIcons/appstore.png',
        toolTip: 'CopyPastePlus',
      );

      await _menu.buildFrom([
        MenuItemLabel(
          label: 'Показать',
          onClicked: (_) => _showWindowController.add(null),
        ),
        MenuItemLabel(
          label: 'Настройки',
          onClicked: (_) => _openSettingsController.add(null),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Завершить',
          onClicked: (_) async {
            await quitAppCompletely();
          },
        ),
      ]);

      await _systemTray.setContextMenu(_menu);

      // macOS: context menu is not shown automatically — pop it up on
      // right-click. Left-click toggles the panel (common for menu-bar apps).
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _toggleWindowController.add(null);
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      print('System tray initialized successfully');
    } catch (e) {
      print('Error initializing system tray: $e');
    }
  }

  void dispose() {
    _showWindowController.close();
    _openSettingsController.close();
    _toggleWindowController.close();
  }
}
