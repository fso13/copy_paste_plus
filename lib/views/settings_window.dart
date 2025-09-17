import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';

class SettingsWindow extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsWindow({required this.onClose});

  @override
  _SettingsWindowState createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  final ClipboardManager _clipboardManager = ClipboardManager();
  final HotkeyService _hotkeyService = HotkeyService();
  
  late int _maxItems;
  bool _launchAtStartup = false;
  bool _isRecording = false;
  String _currentHotkeyDescription = '';
  
  // Переменные для записи комбинации
  final List<HotKeyModifier> _recordedModifiers = [];
  PhysicalKeyboardKey? _recordedKey;
  final FocusNode _recordingFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _maxItems = _clipboardManager.maxItems;
    _loadSettings();
    _updateHotkeyDescription();
  }

  @override
  void dispose() {
    _recordingFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _launchAtStartup = prefs.getBool('auto_start_enabled') ?? false;
    setState(() {});
  }

  Future<void> _setAutoStartEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start_enabled', enabled);
    setState(() => _launchAtStartup = enabled);
  }

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
    
    if (keyString.isNotEmpty && keyString.length == 1) {
      return keyString.toUpperCase();
    }
    
    return key.toString().split('.').last;
  }

  void _updateHotkeyDescription() {
    _currentHotkeyDescription = _formatHotkey(_hotkeyService.currentHotkey);
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedModifiers.clear();
      _recordedKey = null;
    });
    
    // Запрашиваем фокус для захвата клавиш
    FocusScope.of(context).requestFocus(_recordingFocusNode);
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    
    // Возвращаем фокус
    _recordingFocusNode.unfocus();
  }

  void _saveRecordedHotkey() {
    if (_recordedKey != null && _recordedModifiers.isNotEmpty) {
      final newHotkey = HotKey(key: _recordedKey!, modifiers: _recordedModifiers);
      _applyNewHotkey(newHotkey);
    } else {
      // Показываем ошибку если комбинация неполная
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите полную комбинацию (модификаторы + клавиша)')),
      );
    }
  }

  void _applyNewHotkey(HotKey newHotkey) async {
    await _hotkeyService.updateHotkey(newHotkey);
    
    setState(() {
      _updateHotkeyDescription();
      _isRecording = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Горячие клавиши изменены: ${_formatHotkey(newHotkey)}')),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_isRecording || event is! KeyDownEvent) return;

    final physicalKey = event.physicalKey;

    // Обрабатываем модификаторы
    if (_isModifierKey(physicalKey)) {
      _handleModifierKey(physicalKey, true);
      return;
    }

    // Обрабатываем обычные клавиши
    if (!_isModifierKey(physicalKey)) {
      setState(() {
        _recordedKey = physicalKey;
      });
    }

    _updateRecordingStatus();
  }

  bool _isModifierKey(PhysicalKeyboardKey key) {
    return key == PhysicalKeyboardKey.controlLeft ||
           key == PhysicalKeyboardKey.controlRight ||
           key == PhysicalKeyboardKey.shiftLeft ||
           key == PhysicalKeyboardKey.shiftRight ||
           key == PhysicalKeyboardKey.altLeft ||
           key == PhysicalKeyboardKey.altRight ||
           key == PhysicalKeyboardKey.metaLeft ||
           key == PhysicalKeyboardKey.metaRight;
  }

  void _handleModifierKey(PhysicalKeyboardKey physicalKey, bool isPressed) {
    final modifier = _physicalKeyToModifier(physicalKey);
    if (modifier == null) return;

    setState(() {
      if (isPressed && !_recordedModifiers.contains(modifier)) {
        _recordedModifiers.add(modifier);
      } else if (!isPressed) {
        _recordedModifiers.remove(modifier);
      }
    });

    _updateRecordingStatus();
  }

  HotKeyModifier? _physicalKeyToModifier(PhysicalKeyboardKey physicalKey) {
    switch (physicalKey) {
      case PhysicalKeyboardKey.controlLeft:
      case PhysicalKeyboardKey.controlRight:
        return HotKeyModifier.control;
      case PhysicalKeyboardKey.shiftLeft:
      case PhysicalKeyboardKey.shiftRight:
        return HotKeyModifier.shift;
      case PhysicalKeyboardKey.altLeft:
      case PhysicalKeyboardKey.altRight:
        return HotKeyModifier.alt;
      case PhysicalKeyboardKey.metaLeft:
      case PhysicalKeyboardKey.metaRight:
        return HotKeyModifier.meta;
      default:
        return null;
    }
  }

  void _updateRecordingStatus() {
    setState(() {});
  }

  String _getRecordingStatus() {
    if (!_isRecording) return '';

    final modifiers = _recordedModifiers.map(_modifierToString).join('+');
    final key = _recordedKey != null ? _getKeyName(_recordedKey!) : '...';

    if (modifiers.isEmpty && _recordedKey == null) {
      return 'Нажмите сочетание клавиш';
    } else if (modifiers.isNotEmpty && _recordedKey == null) {
      return '$modifiers + ...';
    } else if (modifiers.isEmpty && _recordedKey != null) {
      return 'Добавьте модификаторы (Ctrl, Alt, Shift, Cmd)';
    } else {
      return '$modifiers + $key';
    }
  }

  String _modifierToString(HotKeyModifier modifier) {
    switch (modifier) {
      case HotKeyModifier.control: return 'Ctrl';
      case HotKeyModifier.alt: return 'Alt';
      case HotKeyModifier.shift: return 'Shift';
      case HotKeyModifier.meta: return 'Cmd';
      default: return '';
    }
  }

  void _resetToDefaultHotkey() async {
    final defaultHotkey = HotKey(
      key: PhysicalKeyboardKey.keyC,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    );
    await _hotkeyService.updateHotkey(defaultHotkey);
    setState(() {
      _updateHotkeyDescription();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Горячие клавиши сброшены на Cmd+Shift+C')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingStatus = _getRecordingStatus();

    return KeyboardListener(
      focusNode: _recordingFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Настройки'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onClose,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Настройки горячих клавиш
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Горячие клавиши',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Сочетание для открытия приложения'),
                    const SizedBox(height: 16),
                    
                    // Текущая горячая клавиша
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isRecording 
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isRecording ? Colors.blue : Colors.grey[300]!,
                          width: _isRecording ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _isRecording ? recordingStatus : _currentHotkeyDescription,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isRecording ? Colors.blue : Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_isRecording) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Нажмите модификаторы (Ctrl, Alt, Shift, Cmd) затем основную клавишу',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (!_isRecording) 
                      ElevatedButton(
                        onPressed: _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Изменить сочетание'),
                      )
                    else
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _saveRecordedHotkey,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Сохранить'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _stopRecording,
                            child: const Text('Отменить'),
                          ),
                        ],
                      ),
                    
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _resetToDefaultHotkey,
                      child: const Text('Сбросить на Cmd+Shift+C'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Остальные настройки...
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Настройки хранения',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    ListTile(
                      title: const Text('Запуск при старте системы'),
                      trailing: Switch(
                        value: _launchAtStartup,
                        onChanged: _setAutoStartEnabled,
                      ),
                    ),
                    
                    ListTile(
                      title: const Text('Максимум элементов истории'),
                      subtitle: Slider(
                        value: _maxItems.toDouble(),
                        min: 10,
                        max: 100,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() => _maxItems = value.toInt());
                        },
                        onChangeEnd: (value) {
                          _clipboardManager.setMaxItems(value.toInt());
                        },
                      ),
                      trailing: Text('$_maxItems'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}