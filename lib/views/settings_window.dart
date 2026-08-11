import 'dart:io';

import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';
import 'package:copy_paste_plus/services/theme_service.dart';
import 'package:copy_paste_plus/services/update_service.dart';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:copy_paste_plus/views/pong_game.dart';
import 'package:copy_paste_plus/widgets/app_panel.dart';
import 'package:copy_paste_plus/widgets/brand_mark.dart';
import 'package:copy_paste_plus/widgets/fun_bits.dart';
import 'package:copy_paste_plus/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class SettingsWindow extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsWindow({super.key, required this.onClose});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  final ClipboardManager _clipboardManager = clipboardManager;
  final HotkeyService _hotkeyService = HotkeyService();
  final ThemeService _themeService = themeService;
  final UpdateService _updateService = updateService;

  late int _maxItems;
  bool _launchAtStartup = false;
  bool _isRecording = false;
  bool _checkingUpdates = false;
  String _currentHotkeyDescription = '';
  String _appVersion = '';
  String _buildNumber = '';
  int _aboutClicks = 0;
  bool _party = false;

  final List<HotKeyModifier> _recordedModifiers = [];
  PhysicalKeyboardKey? _recordedKey;
  final FocusNode _recordingFocusNode = FocusNode();

  static const _secretClicks = 13;

  @override
  void initState() {
    super.initState();
    _maxItems = _clipboardManager.maxItems;
    _loadSettings();
    _loadAppVersion();
    _updateHotkeyDescription();
    _themeService.addListener(_onThemeChanged);
    _updateService.addListener(_onUpdateChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onUpdateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _updateService.removeListener(_onUpdateChanged);
    _recordingFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _launchAtStartup = prefs.getBool('auto_start_enabled') ?? false;
    setState(() {});
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _setAutoStartEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start_enabled', enabled);
    setState(() => _launchAtStartup = enabled);
  }

  void _onAboutTap() {
    setState(() {
      _aboutClicks += 1;
      if (_aboutClicks == 1 || _aboutClicks % 4 == 0) {
        _party = true;
      }
    });

    if (_aboutClicks >= _secretClicks) {
      _aboutClicks = 0;
      _showSnack('arcade unlocked: pong.exe 🦇');
      PongGameOverlay.open(context);
      return;
    }

    if (_aboutClicks == 1 || _aboutClicks % 4 == 0) {
      final message = funToasts[(_aboutClicks ~/ 4) % funToasts.length];
      _showSnack(message);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _party = false);
      });
    }
  }

  String _formatHotkey(HotKey hotkey) {
    final modifiers = hotkey.modifiers!.map((modifier) {
      switch (modifier) {
        case HotKeyModifier.control:
          return '⌃';
        case HotKeyModifier.alt:
          return '⌥';
        case HotKeyModifier.shift:
          return '⇧';
        case HotKeyModifier.meta:
          return '⌘';
        default:
          return '';
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
      final newHotkey =
          HotKey(key: _recordedKey!, modifiers: _recordedModifiers);
      _applyNewHotkey(newHotkey);
    } else {
      _showSnack('Выберите полную комбинацию (модификаторы + клавиша)');
    }
  }

  Future<void> _applyNewHotkey(HotKey newHotkey) async {
    await _hotkeyService.updateHotkey(newHotkey);

    setState(() {
      _updateHotkeyDescription();
      _isRecording = false;
    });

    _showSnack('Горячие клавиши изменены: ${_formatHotkey(newHotkey)}');
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_isRecording || event is! KeyDownEvent) return;

    final physicalKey = event.physicalKey;

    if (_isModifierKey(physicalKey)) {
      _handleModifierKey(physicalKey, true);
      return;
    }

    setState(() {
      _recordedKey = physicalKey;
    });

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
      case HotKeyModifier.control:
        return '⌃';
      case HotKeyModifier.alt:
        return '⌥';
      case HotKeyModifier.shift:
        return '⇧';
      case HotKeyModifier.meta:
        return '⌘';
      default:
        return '';
    }
  }

  Future<void> _resetToDefaultHotkey() async {
    final defaultHotkey = HotKey(
      key: PhysicalKeyboardKey.keyC,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    );
    await _hotkeyService.updateHotkey(defaultHotkey);
    setState(() {
      _updateHotkeyDescription();
    });

    _showSnack('Горячие клавиши сброшены на ⌘⇧C');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _checkUpdatesNow() async {
    setState(() => _checkingUpdates = true);
    try {
      final release = await _updateService.checkForUpdates(force: true);
      if (!mounted) return;
      if (release == null) {
        _showSnack('У вас актуальная версия ✨');
      } else {
        await showUpdateAvailableDialog(
          context,
          release: release,
          updateService: _updateService,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Не удалось проверить обновления');
      }
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _quitApp() async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить работу'),
        content: const Text(
          'Приложение будет закрыто полностью, включая иконку в меню-баре.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Завершить', style: TextStyle(color: palette.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await windowManager.destroy();
    } catch (_) {
      // Ignore — process exit is enough.
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final recordingStatus = _getRecordingStatus();

    return KeyboardListener(
      focusNode: _recordingFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            AppPanel(
              title: 'settings.cfg',
              actions: [
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: palette.muted),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: BrandMark(
                      iconSize: 36,
                      fontSize: 18,
                      showSubtitle: 'Настройки',
                    ),
                  ),
                  SettingsCard(
                    title: 'Тема',
                    subtitle: 'Выберите тему приложения',
                    icon: Icons.brush_outlined,
                    child: Column(
                      children: [
                        _ThemeOption(
                          label: 'Как в системе',
                          description:
                              'Автоматически переключать тему в зависимости от настроек системы',
                          selected: _themeService.preference ==
                              AppThemePreference.system,
                          onTap: () => _themeService
                              .setPreference(AppThemePreference.system),
                        ),
                        const SizedBox(height: 8),
                        _ThemeOption(
                          label: 'Светлая',
                          description: 'Всегда использовать светлую тему',
                          selected: _themeService.preference ==
                              AppThemePreference.light,
                          onTap: () => _themeService
                              .setPreference(AppThemePreference.light),
                        ),
                        const SizedBox(height: 8),
                        _ThemeOption(
                          label: 'Тёмная',
                          description: 'Всегда использовать тёмную тему',
                          selected: _themeService.preference ==
                              AppThemePreference.dark,
                          onTap: () => _themeService
                              .setPreference(AppThemePreference.dark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'Обновления',
                    subtitle:
                        'Настройте способ получения уведомлений об обновлениях',
                    icon: Icons.sync,
                    child: Column(
                      children: [
                        _ThemeOption(
                          label: 'Выключено',
                          description: 'Не проверять обновления',
                          selected: _updateService.mode ==
                              UpdateCheckMode.disabled,
                          onTap: () => _updateService
                              .setMode(UpdateCheckMode.disabled),
                        ),
                        const SizedBox(height: 8),
                        _ThemeOption(
                          label: 'Уведомлять',
                          description:
                              'Показывать уведомления о доступных обновлениях',
                          selected:
                              _updateService.mode == UpdateCheckMode.notify,
                          onTap: () =>
                              _updateService.setMode(UpdateCheckMode.notify),
                        ),
                        const SizedBox(height: 8),
                        _ThemeOption(
                          label: 'Автоматически',
                          description:
                              'При новой версии сразу открывать скачивание DMG',
                          selected:
                              _updateService.mode == UpdateCheckMode.auto,
                          onTap: () =>
                              _updateService.setMode(UpdateCheckMode.auto),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _checkingUpdates ? null : _checkUpdatesNow,
                            icon: _checkingUpdates
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.refresh,
                                    size: 16, color: palette.accent),
                            label: Text(
                              _checkingUpdates
                                  ? 'Проверяем…'
                                  : 'Проверить сейчас',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.accent,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: palette.accent.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'Горячие клавиши',
                    subtitle: 'Сочетание для открытия приложения',
                    icon: Icons.keyboard_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? palette.accent.withValues(alpha: 0.12)
                                : palette.codeBar.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _isRecording ? palette.accent : palette.line,
                              width: _isRecording ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isRecording
                                    ? recordingStatus
                                    : _currentHotkeyDescription,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Menlo',
                                  color: _isRecording
                                      ? palette.accent
                                      : palette.ink,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_isRecording) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Нажмите модификаторы (⌃, ⌥, ⇧, ⌘), затем клавишу',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!_isRecording)
                          ElevatedButton(
                            onPressed: _startRecording,
                            child: const Text(
                              'Изменить сочетание',
                              style: TextStyle(fontSize: 13),
                            ),
                          )
                        else
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: _saveRecordedHotkey,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.green,
                                  foregroundColor: palette.bg,
                                ),
                                child: const Text(
                                  'Сохранить',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: _stopRecording,
                                child: const Text(
                                  'Отменить',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _resetToDefaultHotkey,
                          child: const Text(
                            'Сбросить на ⌘⇧C',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'Хранение',
                    subtitle: 'Автозапуск и размер истории',
                    icon: Icons.storage_outlined,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Запуск при старте системы',
                            style: TextStyle(fontSize: 13, color: palette.ink),
                          ),
                          value: _launchAtStartup,
                          onChanged: _setAutoStartEnabled,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Максимум элементов истории',
                            style: TextStyle(fontSize: 13, color: palette.ink),
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
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Menlo',
                              color: palette.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'О приложении',
                    subtitle: 'Версия и сборка',
                    icon: Icons.info_outline,
                    onTap: _onAboutTap,
                    footer: Center(
                      child: Text(
                        '© CopyPastePlus · built with coffee & clipboard 🦇',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Menlo',
                          color: palette.muted,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Версия',
                          value: _appVersion.isEmpty ? '…' : _appVersion,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Номер сборки',
                          value: _buildNumber.isEmpty ? '…' : _buildNumber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'Приложение',
                    subtitle: 'Полностью закрыть CopyPastePlus',
                    icon: Icons.power_settings_new,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _quitApp,
                        icon: Icon(Icons.power_settings_new,
                            size: 16, color: palette.red),
                        label: Text(
                          'Завершить работу',
                          style: TextStyle(fontSize: 13, color: palette.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: palette.red.withValues(alpha: 0.45)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            FunBatOverlay(active: _party),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? palette.accent.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? palette.accent.withValues(alpha: 0.75)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.accent : palette.muted,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: palette.muted,
                        ),
                      ),
                    ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: palette.mutedBright),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Menlo',
            color: palette.accent,
          ),
        ),
      ],
    );
  }
}
