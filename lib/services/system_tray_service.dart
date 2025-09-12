// lib/services/system_tray_service.dart
import 'dart:async';
import 'package:system_tray/system_tray.dart';
import 'package:flutter/services.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final StreamController<void> _showWindowController = StreamController.broadcast();

  Stream<void> get onShowWindow => _showWindowController.stream;

  Future<void> initialize() async {
    final AppWindow appWindow = AppWindow();
    
    // Иконка для трея
    final String iconPath = 'assets/AppIcons/appstore.png';
    
    await _systemTray.initSystemTray(
      iconPath: iconPath,
      toolTip: 'Clipboard Manager',
    );

    // Создание меню
    await _menu.buildFrom([
      MenuItemLabel(
        label: 'Показать историю',
        onClicked: (menuItem) {
          _showWindowController.add(null);
        },
      ),
      MenuItemLabel(
        label: 'Настройки',
        onClicked: (menuItem) {
          // Открыть настройки
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Выход',
        onClicked: (menuItem) {
          SystemNavigator.pop();
        },
      ),
    ]);

    await _systemTray.setContextMenu(_menu);
    
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _showWindowController.add(null);
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  void dispose() {
    _showWindowController.close();
  }
}