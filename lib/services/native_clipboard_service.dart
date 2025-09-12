// lib/services/native_clipboard_service.dart
import 'package:flutter/services.dart';

class NativeClipboardService {
  static const MethodChannel _channel = MethodChannel('clipboard_manager');

  static Future<int> getChangeCount() async {
    try {
      final result = await _channel.invokeMethod('getChangeCount');
      return result as int;
    } on PlatformException catch (e) {
      print('Failed to get change count: ${e.message}');
      return -1;
    }
  }

  static Future<String> getClipboardContent() async {
    try {
      final result = await _channel.invokeMethod('getClipboardContent');
      return result as String;
    } on PlatformException catch (e) {
      print('Failed to get clipboard content: ${e.message}');
      return '';
    }
  }
}