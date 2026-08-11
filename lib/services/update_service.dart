import 'dart:async';
import 'dart:convert';

import 'package:copy_paste_plus/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateCheckMode {
  /// Never check for updates.
  disabled,

  /// Periodically check and ask the user.
  notify,

  /// Periodically check and open the download automatically.
  auto,
}

class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.version,
    required this.htmlUrl,
    this.dmgUrl,
    this.body,
  });

  final String tagName;
  final String version;
  final String htmlUrl;
  final String? dmgUrl;
  final String? body;

  String get downloadUrl => dmgUrl ?? htmlUrl;
}

class UpdateService extends ChangeNotifier {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const _modeKey = 'update_check_mode';
  static const _lastCheckKey = 'update_last_check_ms';
  static const _skippedVersionKey = 'update_skipped_version';

  UpdateCheckMode _mode = UpdateCheckMode.notify;
  bool _loaded = false;
  AppRelease? _availableUpdate;
  bool _checking = false;

  UpdateCheckMode get mode => _mode;
  bool get isLoaded => _loaded;
  AppRelease? get availableUpdate => _availableUpdate;
  bool get checking => _checking;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_modeKey)) {
      'disabled' => UpdateCheckMode.disabled,
      'auto' => UpdateCheckMode.auto,
      _ => UpdateCheckMode.notify,
    };
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(UpdateCheckMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _modeKey,
      switch (mode) {
        UpdateCheckMode.disabled => 'disabled',
        UpdateCheckMode.notify => 'notify',
        UpdateCheckMode.auto => 'auto',
      },
    );
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
    if (_availableUpdate?.version == version) {
      _availableUpdate = null;
      notifyListeners();
    }
  }

  /// Returns a newer release if available, otherwise null.
  Future<AppRelease?> checkForUpdates({bool force = false}) async {
    if (_mode == UpdateCheckMode.disabled && !force) return null;
    if (_checking) return _availableUpdate;

    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final lastMs = prefs.getInt(_lastCheckKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (elapsed < AppConstants.updateCheckInterval.inMilliseconds) {
        return _availableUpdate;
      }
    }

    _checking = true;
    notifyListeners();

    try {
      final response = await http
          .get(
            Uri.parse(AppConstants.githubReleasesApiUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'CopyPastePlus',
            },
          )
          .timeout(const Duration(seconds: 12));

      await prefs.setInt(
        _lastCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (response.statusCode == 404) {
        _availableUpdate = null;
        return null;
      }
      if (response.statusCode != 200) {
        throw Exception('GitHub API ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (json['tag_name'] as String?)?.trim() ?? '';
      final version = _normalizeVersion(tagName);
      if (version.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final current = _normalizeVersion(info.version);
      if (!_isNewer(version, current)) {
        _availableUpdate = null;
        return null;
      }

      final skipped = prefs.getString(_skippedVersionKey);
      if (!force && skipped != null && skipped == version) {
        _availableUpdate = null;
        return null;
      }

      String? dmgUrl;
      final assets = json['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is! Map<String, dynamic>) continue;
          final name = (asset['name'] as String?)?.toLowerCase() ?? '';
          final url = asset['browser_download_url'] as String?;
          if (name.endsWith('.dmg') && url != null) {
            dmgUrl = url;
            break;
          }
        }
      }

      final release = AppRelease(
        tagName: tagName,
        version: version,
        htmlUrl: (json['html_url'] as String?) ??
            AppConstants.githubReleasesPageUrl,
        dmgUrl: dmgUrl,
        body: json['body'] as String?,
      );
      _availableUpdate = release;
      return release;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<void> openUpdate(AppRelease release) async {
    final uri = Uri.parse(release.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    // Strip build metadata / suffixes like 1.0.0+1 or 1.0.0-beta
    v = v.split('+').first.split('-').first;
    return v;
  }

  /// Semver-ish compare: returns true if [candidate] > [current].
  static bool _isNewer(String candidate, String current) {
    List<int> parts(String v) {
      final chunks = v.split('.');
      return List<int>.generate(3, (i) {
        if (i >= chunks.length) return 0;
        return int.tryParse(chunks[i]) ?? 0;
      });
    }

    final a = parts(candidate);
    final b = parts(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }
}
