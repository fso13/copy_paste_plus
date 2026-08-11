import 'package:flutter/services.dart';

/// Snapshot of macOS pasteboard contents (plain + optional rich formats).
class ClipboardPayload {
  const ClipboardPayload({
    required this.content,
    this.html,
    this.rtf,
  });

  final String content;
  final String? html;
  final String? rtf;

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
      );
    }
    return const ClipboardPayload(content: '');
  }

  Map<String, dynamic> toMap() => {
        'content': content,
        if (html != null && html!.isNotEmpty) 'html': html,
        if (rtf != null && rtf!.isNotEmpty) 'rtf': rtf,
      };

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
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

  /// Stream of pasteboard changes (plain + optional HTML / RTF).
  static Stream<ClipboardPayload> get clipboardChanges {
    return _clipboardChangeChannel
        .receiveBroadcastStream()
        .map(ClipboardPayload.fromMap)
        .handleError((error) {
      print('Clipboard change stream error: $error');
    });
  }
}
