// lib/views/settings_window.dart
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class SettingsWindow extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsWindow({super.key, required this.onClose});

  @override
  _SettingsWindowState createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  final ClipboardManager _clipboardManager = ClipboardManager();
  final HotkeyService _hotkeyService = HotkeyService();
  late int _maxItems;
  HotKey _currentHotkey = HotKey(
    key: LogicalKeyboardKey.keyC,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  bool _isRecording = false;
  HotKey? _pendingHotkey;

  @override
  void initState() {
    super.initState();
    _maxItems = _clipboardManager.maxItems;
    _currentHotkey = _hotkeyService.currentHotkey;
  }

  String _formatHotkey(HotKey hotkey) {
    final modifiers = hotkey.modifiers
        ?.map((modifier) {
          switch (modifier) {
            case HotKeyModifier.control:
              return 'Ctrl';
            case HotKeyModifier.alt:
              return 'Alt';
            case HotKeyModifier.shift:
              return 'Shift';
            case HotKeyModifier.meta:
              return 'Cmd';
            default:
              return '';
          }
        })
        .where((element) => element.isNotEmpty)
        .join('+');

    final key = _getKeyName(hotkey.key);
    return '$modifiers${modifiers!.isNotEmpty ? '+' : ''}$key';
  }

  String _getKeyName(KeyboardKey keyCode) {
    switch (keyCode) {
      case LogicalKeyboardKey.keyA:
        return 'A';
      case LogicalKeyboardKey.keyB:
        return 'B';
      case LogicalKeyboardKey.keyC:
        return 'C';
      case LogicalKeyboardKey.keyD:
        return 'D';
      case LogicalKeyboardKey.keyE:
        return 'E';
      case LogicalKeyboardKey.keyF:
        return 'F';
      case LogicalKeyboardKey.keyG:
        return 'G';
      case LogicalKeyboardKey.keyH:
        return 'H';
      case LogicalKeyboardKey.keyI:
        return 'I';
      case LogicalKeyboardKey.keyJ:
        return 'J';
      case LogicalKeyboardKey.keyK:
        return 'K';
      case LogicalKeyboardKey.keyL:
        return 'L';
      case LogicalKeyboardKey.keyM:
        return 'M';
      case LogicalKeyboardKey.keyN:
        return 'N';
      case LogicalKeyboardKey.keyO:
        return 'O';
      case LogicalKeyboardKey.keyP:
        return 'P';
      case LogicalKeyboardKey.keyQ:
        return 'Q';
      case LogicalKeyboardKey.keyR:
        return 'R';
      case LogicalKeyboardKey.keyS:
        return 'S';
      case LogicalKeyboardKey.keyT:
        return 'T';
      case LogicalKeyboardKey.keyU:
        return 'U';
      case LogicalKeyboardKey.keyV:
        return 'V';
      case LogicalKeyboardKey.keyW:
        return 'W';
      case LogicalKeyboardKey.keyX:
        return 'X';
      case LogicalKeyboardKey.keyY:
        return 'Y';
      case LogicalKeyboardKey.keyZ:
        return 'Z';
      case LogicalKeyboardKey.digit0:
        return '0';
      case LogicalKeyboardKey.digit1:
        return '1';
      case LogicalKeyboardKey.digit2:
        return '2';
      case LogicalKeyboardKey.digit3:
        return '3';
      case LogicalKeyboardKey.digit4:
        return '4';
      case LogicalKeyboardKey.digit5:
        return '5';
      case LogicalKeyboardKey.digit6:
        return '6';
      case LogicalKeyboardKey.digit7:
        return '7';
      case LogicalKeyboardKey.digit8:
        return '8';
      case LogicalKeyboardKey.digit9:
        return '9';
      case LogicalKeyboardKey.space:
        return 'Space';
      case LogicalKeyboardKey.enter:
        return 'Enter';
      case LogicalKeyboardKey.escape:
        return 'Esc';
      case LogicalKeyboardKey.tab:
        return 'Tab';
      case LogicalKeyboardKey.backspace:
        return 'Backspace';
      case LogicalKeyboardKey.delete:
        return 'Delete';
      case LogicalKeyboardKey.arrowUp:
        return '↑';
      case LogicalKeyboardKey.arrowDown:
        return '↓';
      case LogicalKeyboardKey.arrowLeft:
        return '←';
      case LogicalKeyboardKey.arrowRight:
        return '→';
      case LogicalKeyboardKey.f1:
        return 'F1';
      case LogicalKeyboardKey.f2:
        return 'F2';
      case LogicalKeyboardKey.f3:
        return 'F3';
      case LogicalKeyboardKey.f4:
        return 'F4';
      case LogicalKeyboardKey.f5:
        return 'F5';
      case LogicalKeyboardKey.f6:
        return 'F6';
      case LogicalKeyboardKey.f7:
        return 'F7';
      case LogicalKeyboardKey.f8:
        return 'F8';
      case LogicalKeyboardKey.f9:
        return 'F9';
      case LogicalKeyboardKey.f10:
        return 'F10';
      case LogicalKeyboardKey.f11:
        return 'F11';
      case LogicalKeyboardKey.f12:
        return 'F12';
      default:
        return keyCode.toString().replaceFirst('KeyCode.', '');
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _pendingHotkey = null;
    });

    // Временная регистрация для захвата горячих клавиш
    hotKeyManager.register(
      HotKey(
        key: LogicalKeyboardKey.keyC,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      ), // Заглушка
      keyDownHandler: (hotKey) {
        if (_isRecording) {
          setState(() {
            _pendingHotkey = hotKey;
          });
        }
      },
    );
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });

    if (_pendingHotkey != null) {
      setState(() {
        _currentHotkey = _pendingHotkey!;
      });
      _hotkeyService.updateHotkey(_pendingHotkey!);
    }

    // Убираем временный обработчик
    hotKeyManager.unregisterAll();
    // Перерегистрируем основной обработчик
    _hotkeyService.initialize(() {});
  }

  void _cancelRecording() {
    setState(() {
      _isRecording = false;
      _pendingHotkey = null;
    });
    hotKeyManager.unregisterAll();
    _hotkeyService.initialize(() {});
  }

  void _resetToDefault() {
    final defaultHotkey = HotKey(
      key: LogicalKeyboardKey.keyC,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    );
    setState(() {
      _currentHotkey = defaultHotkey;
    });
    _hotkeyService.updateHotkey(defaultHotkey);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Горячие клавиши сброшены к значениям по умолчанию'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Секция горячих клавиш
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Горячие клавиши',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Сочетание клавиш для открытия меню буфера обмена',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Отображение текущей горячей клавиши
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isRecording ? Colors.blue : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_isRecording)
                            const Text(
                              'Нажмите новое сочетание клавиш...',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else if (_pendingHotkey != null)
                            Text(
                              _formatHotkey(_pendingHotkey!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              _formatHotkey(_currentHotkey),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          if (_isRecording) const SizedBox(height: 8),
                          if (_isRecording)
                            const Text(
                              'Нажмите Esc для отмены',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
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
                          ElevatedButton(
                            onPressed: _stopRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Сохранить'),
                          ),

                        const SizedBox(width: 8),

                        if (_isRecording)
                          OutlinedButton(
                            onPressed: _cancelRecording,
                            child: const Text('Отмена'),
                          ),

                        const Spacer(),

                        TextButton(
                          onPressed: _resetToDefault,
                          child: const Text(
                            'Сбросить',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Секция настроек хранения
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Настройки хранения',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Text(
                          'Максимум элементов:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Slider(
                            value: _maxItems.toDouble(),
                            min: 10,
                            max: 200,
                            divisions: 19,
                            label: _maxItems.toString(),
                            onChanged: (value) {
                              setState(() {
                                _maxItems = value.toInt();
                              });
                            },
                            onChangeEnd: (value) {
                              _clipboardManager.setMaxItems(_maxItems);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            _maxItems.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Количество элементов истории, которые будут сохраняться',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () {
                        _clipboardManager.clearHistory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('История буфера обмена очищена'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Очистить всю историю'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Секция информации
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Информация',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Приложение работает в фоновом режиме',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Закройте это окно чтобы свернуть в трей',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Иконка в трее для быстрого доступа',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
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

  @override
  void dispose() {
    // Убедимся, что все обработчики очищены
    if (_isRecording) {
      _cancelRecording();
    }
    super.dispose();
  }
}
