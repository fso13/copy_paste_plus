// lib/services/macos_clipboard_monitor.dart
import 'dart:async';
import 'package:flutter/services.dart';

class MacOSClipboardMonitor {
  static const MethodChannel _channel = MethodChannel('clipboard_monitor');
  static const EventChannel _clipboardChangeChannel = 
      EventChannel('clipboard_monitor/changes');

  static Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
      print('Clipboard monitoring started');
    } on PlatformException catch (e) {
      print('Failed to start clipboard monitoring: ${e.message}');
    }
  }

  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
      print('Clipboard monitoring stopped');
    } on PlatformException catch (e) {
      print('Failed to stop clipboard monitoring: ${e.message}');
    }
  }

  static Stream<String> get clipboardChanges {
    return _clipboardChangeChannel
        .receiveBroadcastStream()
        .map((dynamic event) => event.toString());
  }

  static Future<String> getCurrentClipboard() async {
    try {
      final result = await _channel.invokeMethod('getCurrentClipboard');
      return result as String;
    } on PlatformException catch (e) {
      print('Failed to get clipboard: ${e.message}');
      return '';
    }
  }
}