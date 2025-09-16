import 'package:uuid/uuid.dart';

class ClipboardItem {
  final String id;
  final String content;
  final DateTime timestamp;
  bool isFavorite;

  ClipboardItem({
    String? id,
    required this.content,
    required this.timestamp,
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

    if (difference.inSeconds < 60) return 'только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
    if (difference.inHours < 24) return '${difference.inHours} ч назад';
    if (difference.inDays < 30) return '${difference.inDays} дн назад';
    return '${timestamp.day}.${timestamp.month}.${timestamp.year}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    try {
      return ClipboardItem(
        id: json['id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        timestamp: DateTime.parse(
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        ),
        isFavorite: json['isFavorite'] == true || json['isFavorite'] == 'true',
      );
    } catch (e) {
      print('Error creating ClipboardItem from JSON: $e');
      print('JSON data: $json');
      // Возвращаем пустой item в случае ошибки
      return ClipboardItem(
        content: 'Error loading item',
        timestamp: DateTime.now(),
      );
    }
  }
}
