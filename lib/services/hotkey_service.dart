import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  HotKey _currentHotKey = HotKey(
    key: PhysicalKeyboardKey.keyC,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  Function()? _onHotkeyPressed;

  Future<void> initialize(Function() onHotkeyPressed) async {
    _onHotkeyPressed = onHotkeyPressed;
    await _registerHotkey();
    print('HotkeyService initialized: ${_formatHotkey(_currentHotKey)}');
  }

  Future<void> _registerHotkey() async {
    await hotKeyManager.unregisterAll();
    
    try {
      await hotKeyManager.register(
        _currentHotKey,
        keyDownHandler: (hotKey) {
          print('Hotkey pressed: ${_formatHotkey(hotKey)}');
          _onHotkeyPressed?.call();
        },
      );
      print('Hotkey registered: ${_formatHotkey(_currentHotKey)}');
    } catch (e) {
      print('Error registering hotkey: $e');
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

    final key = _getKeyName(hotkey.physicalKey);
    return '$modifiers${modifiers.isNotEmpty ? '+' : ''}$key';
  }

  String _getKeyName(PhysicalKeyboardKey key) {
    final keyString = key.keyLabel;
    
    if (key == PhysicalKeyboardKey.space) return 'Space';
    if (key == PhysicalKeyboardKey.enter) return 'Enter';
    if (key == PhysicalKeyboardKey.escape) return 'Escape';
    if (key == PhysicalKeyboardKey.tab) return 'Tab';
    if (key == PhysicalKeyboardKey.capsLock) return 'CapsLock';
    
    if (keyString.isNotEmpty && keyString.length == 1) {
      return keyString.toUpperCase();
    }
    
    // Функциональные клавиши
    if (key.usbHidUsage >= 0x0007003a && key.usbHidUsage <= 0x00070045) {
      return 'F${key.usbHidUsage - 0x0007003a + 1}';
    }
    
    return key.toString().split('.').last;
  }

  void dispose() {
    hotKeyManager.unregisterAll();
    print('HotkeyService disposed');
  }
}