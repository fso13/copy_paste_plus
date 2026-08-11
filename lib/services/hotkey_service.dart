import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  static const _prefsKey = 'hotkey_config';

  static HotKey get defaultHotkey => HotKey(
        key: PhysicalKeyboardKey.keyC,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      );

  HotKey _currentHotKey = defaultHotkey;
  Function()? _onHotkeyPressed;

  Future<void> initialize(Function() onHotkeyPressed) async {
    _onHotkeyPressed = onHotkeyPressed;
    await _loadHotkey();
    await _registerHotkey();
    print('HotkeyService initialized: ${_formatHotkey(_currentHotKey)}');
  }

  Future<void> _loadHotkey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final loaded = _decodeHotkey(raw);
      if (loaded != null) {
        _currentHotKey = loaded;
        print('Hotkey loaded from prefs: ${_formatHotkey(_currentHotKey)}');
      }
    } catch (e) {
      print('Failed to load hotkey, using default: $e');
      _currentHotKey = defaultHotkey;
    }
  }

  Future<void> _saveHotkey(HotKey hotkey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encodeHotkey(hotkey));
      print('Hotkey saved: ${_formatHotkey(hotkey)}');
    } catch (e) {
      print('Failed to save hotkey: $e');
    }
  }

  String _encodeHotkey(HotKey hotkey) {
    return jsonEncode({
      'usbHidUsage': hotkey.physicalKey.usbHidUsage,
      'modifiers': (hotkey.modifiers ?? const <HotKeyModifier>[])
          .map(_modifierToName)
          .toList(),
    });
  }

  HotKey? _decodeHotkey(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final usage = map['usbHidUsage'];
    if (usage is! int) return null;

    final modifiersRaw = map['modifiers'];
    final modifiers = <HotKeyModifier>[];
    if (modifiersRaw is List) {
      for (final item in modifiersRaw) {
        final modifier = _modifierFromName(item?.toString());
        if (modifier != null) modifiers.add(modifier);
      }
    }

    if (modifiers.isEmpty) return null;

    return HotKey(
      key: PhysicalKeyboardKey(usage),
      modifiers: modifiers,
    );
  }

  String _modifierToName(HotKeyModifier modifier) {
    switch (modifier) {
      case HotKeyModifier.control:
        return 'control';
      case HotKeyModifier.alt:
        return 'alt';
      case HotKeyModifier.shift:
        return 'shift';
      case HotKeyModifier.meta:
        return 'meta';
    }
  }

  HotKeyModifier? _modifierFromName(String? name) {
    switch (name) {
      case 'control':
        return HotKeyModifier.control;
      case 'alt':
        return HotKeyModifier.alt;
      case 'shift':
        return HotKeyModifier.shift;
      case 'meta':
        return HotKeyModifier.meta;
      default:
        return null;
    }
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
    print(
      'Updating hotkey from ${_formatHotkey(_currentHotKey)} to ${_formatHotkey(newHotkey)}',
    );
    _currentHotKey = newHotkey;
    await _saveHotkey(newHotkey);
    await _registerHotkey();
  }

  HotKey get currentHotkey => _currentHotKey;

  String _formatHotkey(HotKey hotkey) {
    final modifiers = (hotkey.modifiers ?? const <HotKeyModifier>[])
        .map((modifier) {
          switch (modifier) {
            case HotKeyModifier.control:
              return 'Ctrl';
            case HotKeyModifier.alt:
              return 'Alt';
            case HotKeyModifier.shift:
              return 'Shift';
            case HotKeyModifier.meta:
              return 'Cmd';
          }
        })
        .where((element) => element.isNotEmpty)
        .join('+');

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
