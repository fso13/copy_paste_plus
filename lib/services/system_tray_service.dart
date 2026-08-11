import 'dart:async';
import 'dart:io';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final StreamController<void> _showWindowController =
      StreamController.broadcast();
  final StreamController<void> _openSettingsController =
      StreamController.broadcast();

  Stream<void> get onShowWindow => _showWindowController.stream;
  Stream<void> get onOpenSettings => _openSettingsController.stream;

  Future<void> initialize() async {
    try {
      await _systemTray.initSystemTray(
        iconPath: 'assets/AppIcons/appstore.png',
        toolTip: 'CopyPastePlus',
      );

      await _menu.buildFrom([
        MenuItemLabel(
          label: 'Показать',
          onClicked: (menuItem) {
            _showWindowController.add(null);
          },
        ),
        MenuItemLabel(
          label: 'Настройки',
          onClicked: (menuItem) {
            _openSettingsController.add(null);
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Выход',
          onClicked: (menuItem) async {
            await windowManager.destroy();
            exit(0);
          },
        ),
      ]);

      await _systemTray.setContextMenu(_menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == 'click') {
          _showWindowController.add(null);
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
  }
}
