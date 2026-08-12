import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_type_colors.dart';
import '../utils/constants.dart';

/// Persisted app preferences (auto-start, auto-paste, privacy, type colors).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _keyAutoStart = 'auto_start_enabled';
  static const _keyAutoPaste = 'auto_paste_enabled';
  static const _keyMaskSensitive = 'mask_sensitive_enabled';
  static const _keyIgnoredBundleIds = 'ignored_bundle_ids';
  static const _keyIgnoredInitialized = 'ignored_bundle_ids_initialized';
  static const _keyEncryption = 'encryption_enabled';
  static const _keyTypeColors = 'content_type_colors_v1';

  bool autoPasteEnabled = false;
  bool maskSensitiveEnabled = true;
  bool encryptionEnabled = false;
  Set<String> ignoredBundleIds = {};
  final Map<ContentTypeKind, Color> typeColors = {
    for (final e in ContentTypeColorDefaults.colors.entries) e.key: e.value,
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoPasteEnabled = prefs.getBool(_keyAutoPaste) ?? false;
    maskSensitiveEnabled = prefs.getBool(_keyMaskSensitive) ?? true;
    encryptionEnabled = prefs.getBool(_keyEncryption) ?? false;

    final initialized = prefs.getBool(_keyIgnoredInitialized) ?? false;
    if (!initialized) {
      ignoredBundleIds = {...AppConstants.defaultIgnoredBundleIds};
      await prefs.setStringList(
        _keyIgnoredBundleIds,
        ignoredBundleIds.toList()..sort(),
      );
      await prefs.setBool(_keyIgnoredInitialized, true);
    } else {
      ignoredBundleIds = {
        ...(prefs.getStringList(_keyIgnoredBundleIds) ?? const <String>[]),
      };
    }

    _loadTypeColors(prefs.getStringList(_keyTypeColors));
    notifyListeners();
  }

  void _loadTypeColors(List<String>? raw) {
    typeColors
      ..clear()
      ..addAll(ContentTypeColorDefaults.colors);
    if (raw == null) return;
    for (final entry in raw) {
      final parts = entry.split('=');
      if (parts.length != 2) continue;
      ContentTypeKind? kind;
      for (final k in ContentTypeKind.values) {
        if (k.id == parts[0]) {
          kind = k;
          break;
        }
      }
      final value = int.tryParse(parts[1]);
      if (kind == null || value == null) continue;
      typeColors[kind] = Color(value);
    }
  }

  Color colorFor(ContentTypeKind kind) =>
      typeColors[kind] ?? ContentTypeColorDefaults.colors[kind]!;

  Future<void> setTypeColor(ContentTypeKind kind, Color color) async {
    typeColors[kind] = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyTypeColors,
      [
        for (final e in typeColors.entries)
          '${e.key.id}=${_colorToArgb(e.value)}',
      ],
    );
  }

  Future<void> resetTypeColors() async {
    typeColors
      ..clear()
      ..addAll(ContentTypeColorDefaults.colors);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTypeColors);
  }

  static int _colorToArgb(Color c) {
    final a = (c.a * 255.0).round() & 0xff;
    final r = (c.r * 255.0).round() & 0xff;
    final g = (c.g * 255.0).round() & 0xff;
    final b = (c.b * 255.0).round() & 0xff;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  Future<bool> getAutoStartEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoStart) ?? false;
  }

  Future<void> setAutoStartEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoStart, enabled);
  }

  Future<void> setAutoPasteEnabled(bool enabled) async {
    autoPasteEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPaste, enabled);
    notifyListeners();
  }

  Future<void> setMaskSensitiveEnabled(bool enabled) async {
    maskSensitiveEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMaskSensitive, enabled);
    notifyListeners();
  }

  Future<void> setEncryptionEnabled(bool enabled) async {
    encryptionEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEncryption, enabled);
    notifyListeners();
  }

  Future<void> setIgnoredBundleIds(Set<String> ids) async {
    ignoredBundleIds = {...ids};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyIgnoredBundleIds,
      ignoredBundleIds.toList()..sort(),
    );
    notifyListeners();
  }

  Future<void> addIgnoredBundleId(String bundleId) async {
    if (bundleId.isEmpty) return;
    ignoredBundleIds = {...ignoredBundleIds, bundleId};
    await setIgnoredBundleIds(ignoredBundleIds);
  }

  Future<void> removeIgnoredBundleId(String bundleId) async {
    ignoredBundleIds = {...ignoredBundleIds}..remove(bundleId);
    await setIgnoredBundleIds(ignoredBundleIds);
  }

  Future<void> resetIgnoredToDefaults() async {
    await setIgnoredBundleIds({...AppConstants.defaultIgnoredBundleIds});
  }

  bool isIgnored(String? bundleId) {
    if (bundleId == null || bundleId.isEmpty) return false;
    return ignoredBundleIds.contains(bundleId);
  }

  /// Known password-manager style apps (for sensitive marking / masking).
  bool isPasswordManager(String? bundleId) {
    if (bundleId == null || bundleId.isEmpty) return false;
    return AppConstants.passwordManagerBundleIds.contains(bundleId);
  }
}
