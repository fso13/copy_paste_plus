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
        case HotKeyModifier.control: return '⌃';
        case HotKeyModifier.alt: return '⌥';
        case HotKeyModifier.shift: return '⇧';
        case HotKeyModifier.meta: return '⌘';
        default: return '';
      }
    }).where((element) => element.isNotEmpty).join('');

    final key = _getKeyName(hotkey.physicalKey);
    return '$modifiers$key';
  }

  String _getKeyName(PhysicalKeyboardKey key) {
    final keyString = key.keyLabel;
    
    if (key == PhysicalKeyboardKey.space) return 'Space';
    if (key == PhysicalKeyboardKey.enter) return 'Return';
    if (key == PhysicalKeyboardKey.escape) return 'Esc';
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
    
    FocusScope.of(context).requestFocus(_recordingFocusNode);
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    
    _recordingFocusNode.unfocus();
  }

  void _saveRecordedHotkey() {
    if (_recordedKey != null && _recordedModifiers.isNotEmpty) {
      final newHotkey = HotKey(key: _recordedKey!, modifiers: _recordedModifiers);
      _applyNewHotkey(newHotkey);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Выберите полную комбинацию (модификаторы + клавиша)'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
      SnackBar(
        content: Text('Горячие клавиши изменены: ${_formatHotkey(newHotkey)}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_isRecording || event is! KeyDownEvent) return;

    final physicalKey = event.physicalKey;

    if (_isModifierKey(physicalKey)) {
      _handleModifierKey(physicalKey, true);
      return;
    }

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

    final modifiers = _recordedModifiers.map(_modifierToString).join('');
    final key = _recordedKey != null ? _getKeyName(_recordedKey!) : '...';

    if (modifiers.isEmpty && _recordedKey == null) {
      return 'Нажмите сочетание клавиш';
    } else if (modifiers.isNotEmpty && _recordedKey == null) {
      return '$modifiers...';
    } else if (modifiers.isEmpty && _recordedKey != null) {
      return 'Добавьте модификаторы (⌃, ⌥, ⇧, ⌘)';
    } else {
      return '$modifiers$key';
    }
  }

  String _modifierToString(HotKeyModifier modifier) {
    switch (modifier) {
      case HotKeyModifier.control: return '⌃';
      case HotKeyModifier.alt: return '⌥';
      case HotKeyModifier.shift: return '⇧';
      case HotKeyModifier.meta: return '⌘';
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
      SnackBar(
        content: const Text('Горячие клавиши сброшены на ⌘⇧C'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingStatus = _getRecordingStatus();

    return KeyboardListener(
      focusNode: _recordingFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              // macOS-style title bar
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // macOS traffic lights
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Настройки',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Hotkeys settings
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Горячие клавиши',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Сочетание для открытия приложения',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Current hotkey display
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _isRecording ? Colors.blue : Colors.grey[800],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_isRecording) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Нажмите модификаторы (⌃, ⌥, ⇧, ⌘) затем основную клавишу',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Изменить сочетание', style: TextStyle(fontSize: 13)),
                              )
                            else
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _saveRecordedHotkey,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text('Сохранить', style: TextStyle(fontSize: 13)),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    onPressed: _stopRecording,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text('Отменить', style: TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _resetToDefaultHotkey,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text('Сбросить на ⌘⇧C', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Storage settings
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Настройки хранения',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Запуск при старте системы',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
                              value: _launchAtStartup,
                              onChanged: _setAutoStartEnabled,
                            ),
                            
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Максимум элементов истории',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
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
                              trailing: Text(
                                '$_maxItems',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}