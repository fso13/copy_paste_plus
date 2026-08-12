import 'package:flutter/services.dart';

/// Snapshot of macOS pasteboard contents (plain + optional rich formats).
class ClipboardPayload {
  const ClipboardPayload({
    required this.content,
    this.html,
    this.rtf,
    this.sourceBundleId,
    this.sourceAppName,
  });

  final String content;
  final String? html;
  final String? rtf;
  final String? sourceBundleId;
  final String? sourceAppName;

  bool get hasRichText =>
      (html != null && html!.isNotEmpty) || (rtf != null && rtf!.isNotEmpty);

  bool get isEmpty => content.isEmpty;

  factory ClipboardPayload.fromMap(dynamic raw) {
    if (raw is String) {
      return ClipboardPayload(content: raw);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return ClipboardPayload(
        content: map['content']?.toString() ?? '',
        html: _optionalString(map['html']),
        rtf: _optionalString(map['rtf']),
        sourceBundleId: _optionalString(map['sourceBundleId']),
        sourceAppName: _optionalString(map['sourceAppName']),
      );
    }
    return const ClipboardPayload(content: '');
  }

  Map<String, dynamic> toMap() => {
        'content': content,
        if (html != null && html!.isNotEmpty) 'html': html,
        if (rtf != null && rtf!.isNotEmpty) 'rtf': rtf,
        if (sourceBundleId != null && sourceBundleId!.isNotEmpty)
          'sourceBundleId': sourceBundleId,
        if (sourceAppName != null && sourceAppName!.isNotEmpty)
          'sourceAppName': sourceAppName,
      };

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}

class NativeResult {
  const NativeResult({
    required this.ok,
    this.enabled,
    this.supported,
    this.error,
  });

  final bool ok;
  final bool? enabled;
  final bool? supported;
  final String? error;

  factory NativeResult.fromMap(dynamic raw) {
    if (raw is! Map) {
      return const NativeResult(ok: false, error: 'Invalid response');
    }
    final map = Map<String, dynamic>.from(raw);
    return NativeResult(
      ok: map['ok'] == true,
      enabled: map['enabled'] is bool ? map['enabled'] as bool : null,
      supported: map['supported'] is bool ? map['supported'] as bool : null,
      error: map['error']?.toString(),
    );
  }
}

class RunningAppInfo {
  const RunningAppInfo({required this.bundleId, this.name});

  final String bundleId;
  final String? name;

  factory RunningAppInfo.fromMap(Map<String, dynamic> map) {
    return RunningAppInfo(
      bundleId: map['bundleId']?.toString() ?? '',
      name: map['name']?.toString(),
    );
  }
}

class MacOSClipboardService {
  static const MethodChannel _channel = MethodChannel('clipboard_manager');
  static const EventChannel _clipboardChangeChannel =
      EventChannel('clipboard_manager/changes');

  /// Reads plain text and any available HTML / RTF from the pasteboard.
  static Future<ClipboardPayload> getClipboardContent() async {
    try {
      final result = await _channel.invokeMethod('getClipboardContent');
      return ClipboardPayload.fromMap(result);
    } on PlatformException catch (e) {
      print('Failed to get clipboard content: ${e.message}');
      return const ClipboardPayload(content: '');
    }
  }

  /// Writes plain text plus optional rich formats.
  /// Apps that don't support styles fall back to [content] automatically.
  static Future<bool> setClipboardContent({
    required String content,
    String? html,
    String? rtf,
  }) async {
    try {
      final result = await _channel.invokeMethod(
        'setClipboardContent',
        ClipboardPayload(content: content, html: html, rtf: rtf).toMap(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set clipboard content: ${e.message}');
      return false;
    }
  }

  static Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
    } on PlatformException catch (e) {
      print('Failed to start monitoring: ${e.message}');
    }
  }

  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } on PlatformException catch (e) {
      print('Failed to stop monitoring: ${e.message}');
    }
  }

  static Future<int> getChangeCount() async {
    try {
      final result = await _channel.invokeMethod('getChangeCount');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Failed to get change count: ${e.message}');
      return 0;
    }
  }

  static Future<Map<String, String?>> getFrontmostApp() async {
    try {
      final result = await _channel.invokeMethod('getFrontmostApp');
      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        return {
          'bundleId': map['bundleId']?.toString(),
          'name': map['name']?.toString(),
        };
      }
    } on PlatformException catch (e) {
      print('Failed to get frontmost app: ${e.message}');
    }
    return const {'bundleId': null, 'name': null};
  }

  /// Remember the app that was frontmost before our panel is shown.
  static Future<void> captureFrontmostApp() async {
    try {
      await _channel.invokeMethod('captureFrontmostApp');
    } on PlatformException catch (e) {
      print('Failed to capture frontmost app: ${e.message}');
    }
  }

  static Future<bool> isAccessibilityTrusted() async {
    try {
      final result = await _channel.invokeMethod('isAccessibilityTrusted');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to check accessibility: ${e.message}');
      return false;
    }
  }

  static Future<bool> requestAccessibility() async {
    try {
      final result = await _channel.invokeMethod('requestAccessibility');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to request accessibility: ${e.message}');
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print('Failed to open accessibility settings: ${e.message}');
    }
  }

  /// Activate previously captured app and send ⌘V.
  static Future<NativeResult> pasteToPreviousApp() async {
    try {
      final result = await _channel.invokeMethod('pasteToPreviousApp');
      return NativeResult.fromMap(result);
    } on PlatformException catch (e) {
      print('Failed to auto-paste: ${e.message}');
      return NativeResult(ok: false, error: e.message);
    }
  }

  static Future<NativeResult> getLaunchAtLogin() async {
    try {
      final result = await _channel.invokeMethod('getLaunchAtLogin');
      return NativeResult.fromMap(result);
    } on PlatformException catch (e) {
      return NativeResult(ok: false, error: e.message);
    }
  }

  static Future<NativeResult> setLaunchAtLogin(bool enabled) async {
    try {
      final result = await _channel.invokeMethod(
        'setLaunchAtLogin',
        {'enabled': enabled},
      );
      return NativeResult.fromMap(result);
    } on PlatformException catch (e) {
      return NativeResult(ok: false, error: e.message);
    }
  }

  static Future<List<RunningAppInfo>> listRunningApps() async {
    try {
      final result = await _channel.invokeMethod('listRunningApps');
      if (result is! List) return const [];
      return result
          .whereType<Map>()
          .map((e) => RunningAppInfo.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.bundleId.isNotEmpty)
          .toList();
    } on PlatformException catch (e) {
      print('Failed to list running apps: ${e.message}');
      return const [];
    }
  }

  /// Stream of pasteboard changes (plain + optional HTML / RTF).
  static Stream<ClipboardPayload> get clipboardChanges {
    return _clipboardChangeChannel
        .receiveBroadcastStream()
        .map(ClipboardPayload.fromMap)
        .handleError((error) {
      print('Clipboard change stream error: $error');
    });
  }

  /// Heuristic: short, no-whitespace, mixed charset → likely a password/token.
  static bool looksLikeSecret(String content) {
    final trimmed = content.trim();
    if (trimmed.length < 8 || trimmed.length > 128) return false;
    if (trimmed.contains(' ') || trimmed.contains('\n')) return false;
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
      return false;
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(trimmed);
    final hasDigit = RegExp(r'\d').hasMatch(trimmed);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(trimmed);
    return hasLetter && hasDigit && (hasSymbol || trimmed.length >= 12);
  }
}
