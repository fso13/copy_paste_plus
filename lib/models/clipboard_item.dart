// lib/models/clipboard_item.dart
import 'package:uuid/uuid.dart';

enum ClipboardContentType {
  text,
  richText,
  image,
  file,
}

class ClipboardItem {
  final String id;
  final String content;
  final ClipboardContentType type;
  final DateTime timestamp;
  final String? additionalData;
  bool isFavorite;

  ClipboardItem({
    String? id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.additionalData,
    this.isFavorite = false,
  }) : id = id ?? const Uuid().v4();

  String get preview {
    const maxLength = 80;
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} дн назад';
    } else {
      return '${timestamp.day}.${timestamp.month}.${timestamp.year}';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'type': type.index,
        'timestamp': timestamp.toIso8601String(),
        'additionalData': additionalData,
        'isFavorite': isFavorite,
      };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) => ClipboardItem(
        id: json['id'] ?? const Uuid().v4(),
        content: json['content'] ?? '',
        type: ClipboardContentType.values[json['type'] ?? 0],
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        additionalData: json['additionalData'],
        isFavorite: json['isFavorite'] ?? false,
      );

  @override
  String toString() {
    return 'ClipboardItem{id: $id, content: $preview, timestamp: $timestamp, isFavorite: $isFavorite}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}