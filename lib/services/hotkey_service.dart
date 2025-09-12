// lib/services/hotkey_service.dart
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

  bool _isInitialized = false;
  Function()? _currentCallback;

  Future<void> initialize(Function() onHotkeyPressed) async {
    _currentCallback = onHotkeyPressed;
    
    if (_isInitialized) {
      await _reRegisterHotkey();
      return;
    }
    
    await _registerHotkey();
    _isInitialized = true;
  }

  Future<void> _registerHotkey() async {
    await hotKeyManager.unregisterAll();
    
    try {
      await hotKeyManager.register(
        _currentHotKey,
        keyDownHandler: (hotKey) {
          print('Hotkey pressed: ${_formatHotkey(_currentHotKey)}');
          _currentCallback?.call();
        },
      );
      print('Hotkey registered: ${_formatHotkey(_currentHotKey)}');
    } catch (e) {
      print('Error registering hotkey: $e');
    }
  }

  Future<void> _reRegisterHotkey() async {
    await hotKeyManager.unregisterAll();
    await _registerHotkey();
  }

  Future<void> updateHotkey(HotKey newHotkey) async {
    print('Updating hotkey from ${_formatHotkey(_currentHotKey)} to ${_formatHotkey(newHotkey)}');
    _currentHotKey = newHotkey;
    await _reRegisterHotkey();
  }

  HotKey get currentHotkey => _currentHotKey;

  Future<void> temporaryUnregister() async {
    await hotKeyManager.unregisterAll();
    print('Hotkey temporarily unregistered');
  }

  Future<void> reRegister() async {
    await _reRegisterHotkey();
  }

  String _formatHotkey(HotKey hotkey) {
    final modifiers = hotkey.modifiers!.map((modifier) {
      switch (modifier) {
        case KeyModifier.control: return 'Ctrl';
        case KeyModifier.alt: return 'Alt';
        case KeyModifier.shift: return 'Shift';
        case KeyModifier.meta: return 'Cmd';
        default: return '';
      }
    }).where((element) => element.isNotEmpty).join('+');

    final key = hotkey.key.toString().replaceFirst('KeyCode.', '');
    return '$modifiers${modifiers.isNotEmpty ? '+' : ''}$key';
  }

  void dispose() {
    hotKeyManager.unregisterAll();
    _isInitialized = false;
    _currentCallback = null;
    print('Hotkey service disposed');
  }
}