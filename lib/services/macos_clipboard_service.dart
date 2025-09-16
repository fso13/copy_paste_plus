import 'package:flutter/services.dart';

class MacOSClipboardService {
  static const MethodChannel _channel = MethodChannel('clipboard_manager');
  static const EventChannel _clipboardChangeChannel = 
      EventChannel('clipboard_manager/changes');

  /// Получает текущее содержимое буфера обмена
  static Future<String> getClipboardContent() async {
    try {
      final result = await _channel.invokeMethod('getClipboardContent');
      return result ?? '';
    } on PlatformException catch (e) {
      print('Failed to get clipboard content: ${e.message}');
      return '';
    }
  }

  /// Устанавливает содержимое буфера обмена
  static Future<bool> setClipboardContent(String content) async {
    try {
      final result = await _channel.invokeMethod('setClipboardContent', {'content': content});
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set clipboard content: ${e.message}');
      return false;
    }
  }

  /// Запускает мониторинг изменений буфера обмена
  static Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
    } on PlatformException catch (e) {
      print('Failed to start monitoring: ${e.message}');
    }
  }

  /// Останавливает мониторинг изменений буфера обмена
  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } on PlatformException catch (e) {
      print('Failed to stop monitoring: ${e.message}');
    }
  }

  /// Получает счетчик изменений буфера обмена
  static Future<int> getChangeCount() async {
    try {
      final result = await _channel.invokeMethod('getChangeCount');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Failed to get change count: ${e.message}');
      return 0;
    }
  }

  /// Поток изменений буфера обмена
  static Stream<String> get clipboardChanges {
    return _clipboardChangeChannel
        .receiveBroadcastStream()
        .map((dynamic event) => event.toString())
        .handleError((error) {
          print('Clipboard change stream error: $error');
        });
  }
}