import 'dart:async';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final StreamController<void> _showWindowController = StreamController.broadcast();

  Stream<void> get onShowWindow => _showWindowController.stream;

  Future<void> initialize() async {
    try {
      // Инициализируем системный трей
      await _systemTray.initSystemTray(
        iconPath: 'assets/AppIcons/appstore.png', // Убедитесь что файл существует в assets/
        toolTip: 'Clipboard Manager',
      );

      // Создаем меню
      await _menu.buildFrom([
        MenuItemLabel(
          label: 'Показать Clipboard Manager',
          onClicked: (menuItem) {
            _showWindowController.add(null);
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Настройки',
          onClicked: (menuItem) {
            _showWindowController.add(null);
            // Открываем настройки через задержку
            Future.delayed(Duration(milliseconds: 100), () {
              _showWindowController.add(null); // Двойной вызов для настройок
            });
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Выход',
          onClicked: (menuItem) {
            windowManager.close();
          },
        ),
      ]);

      // Устанавливаем контекстное меню
      await _systemTray.setContextMenu(_menu);

      // Обработчик клика по иконке в трее
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
  }
}