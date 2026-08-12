import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Persisted app preferences (auto-start, auto-paste, privacy).
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _keyAutoStart = 'auto_start_enabled';
  static const _keyAutoPaste = 'auto_paste_enabled';
  static const _keyMaskSensitive = 'mask_sensitive_enabled';
  static const _keyIgnoredBundleIds = 'ignored_bundle_ids';
  static const _keyIgnoredInitialized = 'ignored_bundle_ids_initialized';

  bool autoPasteEnabled = false;
  bool maskSensitiveEnabled = true;
  Set<String> ignoredBundleIds = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoPasteEnabled = prefs.getBool(_keyAutoPaste) ?? false;
    maskSensitiveEnabled = prefs.getBool(_keyMaskSensitive) ?? true;

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
  }

  Future<void> setMaskSensitiveEnabled(bool enabled) async {
    maskSensitiveEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMaskSensitive, enabled);
  }

  Future<void> setIgnoredBundleIds(Set<String> ids) async {
    ignoredBundleIds = {...ids};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyIgnoredBundleIds,
      ignoredBundleIds.toList()..sort(),
    );
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
