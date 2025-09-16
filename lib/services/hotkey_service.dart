import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  HotKey _currentHotKey = HotKey(
    key: LogicalKeyboardKey.keyC,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  Function()? _onHotkeyPressed;

  Future<void> initialize(Function() onHotkeyPressed) async {
    _onHotkeyPressed = onHotkeyPressed;
    await _registerHotkey();
  }

  Future<void> _registerHotkey() async {
    await hotKeyManager.unregisterAll();
    
    try {
      await hotKeyManager.register(
        _currentHotKey,
        keyDownHandler: (hotKey) {
          print('Hotkey pressed: ${_formatHotkey(_currentHotKey)}');
          _onHotkeyPressed?.call();
        },
      );
      print('Hotkey registered: ${_formatHotkey(_currentHotKey)}');
    } catch (e) {
      print('Error registering hotkey: $e');
      // Повторяем попытку через секунду
      Future.delayed(Duration(seconds: 1), _registerHotkey);
    }
  }

  Future<void> updateHotkey(HotKey newHotkey) async {
    print('Updating hotkey from ${_formatHotkey(_currentHotKey)} to ${_formatHotkey(newHotkey)}');
    _currentHotKey = newHotkey;
    await _registerHotkey();
  }

  HotKey get currentHotkey => _currentHotKey;

  String _formatHotkey(HotKey hotkey) {
    final modifiers = hotkey.modifiers!.map((modifier) {
      switch (modifier) {
        case HotKeyModifier.control: return 'Ctrl';
        case HotKeyModifier.alt: return 'Alt';
        case HotKeyModifier.shift: return 'Shift';
        case HotKeyModifier.meta: return 'Cmd';
        default: return '';
      }
    }).where((element) => element.isNotEmpty).join('+');

    final key = hotkey.key.toString().replaceFirst('KeyCode.', '');
    return '$modifiers${modifiers.isNotEmpty ? '+' : ''}$key';
  }

  void dispose() {
    hotKeyManager.unregisterAll();
  }
}