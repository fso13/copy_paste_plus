import 'package:copy_paste_plus/data/help_guide.dart';
import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/content_type_colors.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/hotkey_service.dart';
import 'package:copy_paste_plus/services/macos_clipboard_service.dart';
import 'package:copy_paste_plus/services/theme_service.dart';
import 'package:copy_paste_plus/services/update_service.dart';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:copy_paste_plus/utils/constants.dart';
import 'package:copy_paste_plus/views/pong_game.dart';
import 'package:copy_paste_plus/widgets/app_panel.dart';
import 'package:copy_paste_plus/widgets/brand_mark.dart';
import 'package:copy_paste_plus/widgets/fun_bits.dart';
import 'package:copy_paste_plus/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

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
  bool _launchAtLoginSupported = true;
  bool _autoPasteEnabled = false;
  bool _maskSensitiveEnabled = true;
  bool _encryptionEnabled = false;
  bool _isRecording = false;
  bool _checkingUpdates = false;
  String _currentHotkeyDescription = '';
  String _appVersion = '';
  String _buildNumber = '';
  int _aboutClicks = 0;
  bool _party = false;
  bool _showHelp = false;
  String? _expandedHelpId;
  List<String> _ignoredBundleIds = [];
  Map<String, String> _ignoredAppNames = {};

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
    await appSettings.load();
    final launch = await MacOSClipboardService.getLaunchAtLogin();
    _launchAtLoginSupported = launch.supported ?? true;
    _launchAtStartup = launch.enabled ?? await appSettings.getAutoStartEnabled();
    _autoPasteEnabled = appSettings.autoPasteEnabled;
    _maskSensitiveEnabled = appSettings.maskSensitiveEnabled;
    _encryptionEnabled = appSettings.encryptionEnabled;
    _ignoredBundleIds = appSettings.ignoredBundleIds.toList()..sort();
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
    final result = await MacOSClipboardService.setLaunchAtLogin(enabled);
    if (!result.ok) {
      _showSnack(result.error ?? 'Не удалось изменить автозапуск');
      final current = await MacOSClipboardService.getLaunchAtLogin();
      setState(() {
        _launchAtStartup = current.enabled ?? false;
        _launchAtLoginSupported = current.supported ?? false;
      });
      return;
    }
    await appSettings.setAutoStartEnabled(result.enabled ?? enabled);
    setState(() {
      _launchAtStartup = result.enabled ?? enabled;
      _launchAtLoginSupported = result.supported ?? true;
    });
  }

  Future<void> _setAutoPasteEnabled(bool enabled) async {
    if (enabled) {
      var trusted = await MacOSClipboardService.isAccessibilityTrusted();
      if (!trusted) {
        trusted = await MacOSClipboardService.requestAccessibility();
      }
      if (!trusted) {
        _showSnack(
          'Для авто-вставки нужен Универсальный доступ в настройках macOS',
        );
        await MacOSClipboardService.openAccessibilitySettings();
      }
    }
    await appSettings.setAutoPasteEnabled(enabled);
    setState(() => _autoPasteEnabled = enabled);
  }

  Future<void> _setMaskSensitiveEnabled(bool enabled) async {
    await appSettings.setMaskSensitiveEnabled(enabled);
    setState(() => _maskSensitiveEnabled = enabled);
  }

  Future<void> _setEncryptionEnabled(bool enabled) async {
    await appSettings.setEncryptionEnabled(enabled);
    await _clipboardManager.repersistWithCurrentEncryption();
    setState(() => _encryptionEnabled = enabled);
    _showSnack(
      enabled
          ? 'История будет храниться в зашифрованном виде'
          : 'Шифрование истории отключено',
    );
  }

  Future<void> _removeIgnoredApp(String bundleId) async {
    await appSettings.removeIgnoredBundleId(bundleId);
    setState(() {
      _ignoredBundleIds = appSettings.ignoredBundleIds.toList()..sort();
      _ignoredAppNames.remove(bundleId);
    });
  }

  Future<void> _resetIgnoredApps() async {
    await appSettings.resetIgnoredToDefaults();
    setState(() {
      _ignoredBundleIds = appSettings.ignoredBundleIds.toList()..sort();
      _ignoredAppNames.clear();
    });
    _showSnack('Список игнора сброшен к значениям по умолчанию');
  }

  Future<void> _addIgnoredApp() async {
    final apps = await MacOSClipboardService.listRunningApps();
    final available = apps
        .where((a) => !_ignoredBundleIds.contains(a.bundleId))
        .toList();
    if (!mounted) return;

    if (available.isEmpty) {
      _showSnack('Нет запущенных приложений для добавления');
      return;
    }

    final palette = context.palette;
    final selected = await showDialog<RunningAppInfo>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Игнорировать приложение'),
          content: SizedBox(
            width: 360,
            height: 320,
            child: ListView.builder(
              itemCount: available.length,
              itemBuilder: (context, index) {
                final app = available[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    app.name?.isNotEmpty == true ? app.name! : app.bundleId,
                    style: TextStyle(fontSize: 13, color: palette.ink),
                  ),
                  subtitle: Text(
                    app.bundleId,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Menlo',
                      color: palette.muted,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, app),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: TextStyle(color: palette.muted)),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    await appSettings.addIgnoredBundleId(selected.bundleId);
    setState(() {
      _ignoredBundleIds = appSettings.ignoredBundleIds.toList()..sort();
      if (selected.name != null && selected.name!.isNotEmpty) {
        _ignoredAppNames[selected.bundleId] = selected.name!;
      }
    });
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
        case HotKeyModifier.capsLock:
          return '⇪';
        case HotKeyModifier.fn:
          return 'Fn';
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
      case HotKeyModifier.capsLock:
        return '⇪';
      case HotKeyModifier.fn:
        return 'Fn';
    }
  }

  Future<void> _resetToDefaultHotkey() async {
    await _hotkeyService.updateHotkey(HotkeyService.defaultHotkey);
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

  Future<void> _openDocsSite() async {
    final uri = Uri.parse(AppConstants.docsSiteUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnack('Не удалось открыть сайт документации');
    }
  }

  Future<void> _pickTypeColor(ContentTypeKind kind) async {
    final palette = context.palette;
    final current = appSettings.colorFor(kind);
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _TypeColorPickerDialog(
        title: kind.label,
        initial: current,
        palette: palette,
      ),
    );
    if (picked == null || !mounted) return;
    await appSettings.setTypeColor(kind, picked);
    setState(() {});
  }

  Future<void> _resetTypeColors() async {
    await appSettings.resetTypeColors();
    if (mounted) setState(() {});
    _showSnack('Цвета типов сброшены');
  }

  IconData _helpIcon(String key) {
    switch (key) {
      case 'bolt':
        return Icons.bolt_outlined;
      case 'keyboard':
        return Icons.keyboard_outlined;
      case 'code':
        return Icons.code;
      case 'visibility_off':
        return Icons.visibility_off_outlined;
      case 'lock':
        return Icons.lock_outline;
      case 'keyboard_return':
        return Icons.keyboard_return;
      case 'auto_fix':
        return Icons.text_fields;
      case 'star':
        return Icons.star_outline;
      case 'block':
        return Icons.block;
      case 'image':
        return Icons.image_outlined;
      case 'palette':
        return Icons.palette_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildHelpBody(AppPalette palette) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Кратко, как пользоваться CopyPastePlus: сниппеты, быстрый выбор, '
            'secret, шифрование и остальное.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: palette.muted,
            ),
          ),
        ),
        for (final topic in HelpGuide.topics) ...[
          Material(
            color: palette.bgElevated.withValues(alpha: 0.78),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: palette.accent.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('help_${topic.id}'),
                initiallyExpanded: _expandedHelpId == topic.id,
                onExpansionChanged: (open) {
                  setState(() {
                    _expandedHelpId = open ? topic.id : null;
                  });
                },
                leading: Icon(
                  _helpIcon(topic.icon),
                  size: 20,
                  color: palette.accent,
                ),
                title: Text(
                  topic.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  for (var i = 0; i < topic.paragraphs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        topic.paragraphs[i],
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: palette.ink.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: _openDocsSite,
          icon: Icon(Icons.open_in_new, size: 16, color: palette.accent),
          label: Text(
            'Сайт с документацией',
            style: TextStyle(fontSize: 13, color: palette.accent),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: palette.accent.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
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
              title: _showHelp ? 'help.md' : 'settings.cfg',
              actions: [
                if (_showHelp)
                  IconButton(
                    icon: Icon(Icons.arrow_back, size: 16, color: palette.muted),
                    onPressed: () => setState(() {
                      _showHelp = false;
                      _expandedHelpId = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'К настройкам',
                  ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: palette.muted),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
              child: _showHelp
                  ? _buildHelpBody(palette)
                  : ListView(
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
                    title: 'Вставка',
                    subtitle: 'Поведение при выборе элемента',
                    icon: Icons.keyboard_return,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Авто-вставка',
                            style: TextStyle(fontSize: 13, color: palette.ink),
                          ),
                          subtitle: Text(
                            'После выбора сразу вставить ⌘V в предыдущее приложение. Можно отключить.',
                            style: TextStyle(fontSize: 11, color: palette.muted),
                          ),
                          value: _autoPasteEnabled,
                          onChanged: _setAutoPasteEnabled,
                        ),
                        if (_autoPasteEnabled)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Нужен Универсальный доступ в настройках macOS.',
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.muted,
                              ),
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
                          subtitle: !_launchAtLoginSupported
                              ? Text(
                                  'Требуется macOS 13 или новее',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                )
                              : null,
                          value: _launchAtStartup,
                          onChanged: _launchAtLoginSupported
                              ? _setAutoStartEnabled
                              : null,
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
                    title: 'Приватность',
                    subtitle: 'Игнор приложений, маскировка и шифрование',
                    icon: Icons.shield_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Маскировать чувствительные данные',
                            style: TextStyle(fontSize: 13, color: palette.ink),
                          ),
                          subtitle: Text(
                            'Пароли и токены показываются как •••• (можно раскрыть глазом)',
                            style: TextStyle(fontSize: 11, color: palette.muted),
                          ),
                          value: _maskSensitiveEnabled,
                          onChanged: _setMaskSensitiveEnabled,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Шифровать историю на диске',
                            style: TextStyle(fontSize: 13, color: palette.ink),
                          ),
                          subtitle: Text(
                            'AES-GCM, ключ в Keychain',
                            style: TextStyle(fontSize: 11, color: palette.muted),
                          ),
                          value: _encryptionEnabled,
                          onChanged: _setEncryptionEnabled,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Игнорировать копирование из',
                          style: TextStyle(fontSize: 13, color: palette.ink),
                        ),
                        const SizedBox(height: 6),
                        if (_ignoredBundleIds.isEmpty)
                          Text(
                            'Список пуст — всё попадает в историю',
                            style: TextStyle(fontSize: 11, color: palette.muted),
                          )
                        else
                          ..._ignoredBundleIds.map((id) {
                            final label = _ignoredAppNames[id] ?? id;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: palette.ink,
                                ),
                              ),
                              subtitle: label == id
                                  ? null
                                  : Text(
                                      id,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'Menlo',
                                        color: palette.muted,
                                      ),
                                    ),
                              trailing: IconButton(
                                icon: Icon(Icons.close,
                                    size: 16, color: palette.muted),
                                onPressed: () => _removeIgnoredApp(id),
                                tooltip: 'Убрать',
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _addIgnoredApp,
                              icon: Icon(Icons.add, size: 16, color: palette.ink),
                              label: Text(
                                'Добавить',
                                style:
                                    TextStyle(fontSize: 12, color: palette.ink),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _resetIgnoredApps,
                              child: Text(
                                'Сбросить',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'Цвета типов',
                    subtitle:
                        'Полоска и бейдж в списке: text, url, json, secret…',
                    icon: Icons.palette_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final kind in ContentTypeKind.values) ...[
                          if (kind != ContentTypeKind.values.first)
                            const SizedBox(height: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _pickTypeColor(kind),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: appSettings.colorFor(kind),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: palette.line,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            kind.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: palette.ink,
                                            ),
                                          ),
                                          Text(
                                            kind.badge,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'Menlo',
                                              color: palette.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: palette.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _resetTypeColors,
                            child: Text(
                              'Сбросить цвета',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsCard(
                    title: 'Справка',
                    subtitle:
                        'Сниппеты, быстрый выбор, secret, шифрование и другое',
                    icon: Icons.menu_book_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Как пользоваться шаблонами {{name}}, цифрами 1–9, '
                          'авто-вставкой и приватностью — в краткой справке.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _showHelp = true;
                            _expandedHelpId = 'snippets';
                          }),
                          icon: const Icon(Icons.menu_book_outlined, size: 16),
                          label: const Text(
                            'Открыть справку',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _openDocsSite,
                          icon: Icon(Icons.open_in_new,
                              size: 16, color: palette.ink),
                          label: Text(
                            'Открыть сайт',
                            style:
                                TextStyle(fontSize: 13, color: palette.ink),
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

class _TypeColorPickerDialog extends StatefulWidget {
  const _TypeColorPickerDialog({
    required this.title,
    required this.initial,
    required this.palette,
  });

  final String title;
  final Color initial;
  final AppPalette palette;

  @override
  State<_TypeColorPickerDialog> createState() => _TypeColorPickerDialogState();
}

class _TypeColorPickerDialogState extends State<_TypeColorPickerDialog> {
  late Color _selected;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _hexController = TextEditingController(text: _toHex(_selected));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _toHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Color? _fromHex(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  void _select(Color color) {
    setState(() {
      _selected = color;
      _hexController.text = _toHex(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _selected,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.line),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Menlo',
                      color: palette.ink,
                    ),
                    decoration: InputDecoration(
                      labelText: 'HEX',
                      labelStyle:
                          TextStyle(color: palette.muted, fontSize: 12),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (value) {
                      final parsed = _fromHex(value);
                      if (parsed != null) _select(parsed);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in ContentTypeColorDefaults.swatches)
                  InkWell(
                    onTap: () => _select(swatch),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selected.toARGB32() == swatch.toARGB32()
                              ? palette.ink
                              : palette.line,
                          width: _selected.toARGB32() == swatch.toARGB32()
                              ? 2
                              : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: TextStyle(color: palette.muted)),
        ),
        TextButton(
          onPressed: () {
            final parsed = _fromHex(_hexController.text);
            Navigator.pop(context, parsed ?? _selected);
          },
          child: Text('Сохранить', style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}
