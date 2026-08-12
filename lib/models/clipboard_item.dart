import 'package:uuid/uuid.dart';

class ClipboardItem {
  final String id;
  final String content;
  /// HTML fragment from the source pasteboard (syntax highlighting, colors).
  final String? html;
  /// RTF from the source pasteboard (preferred by Word / rich editors).
  final String? rtf;
  /// Absolute path to a persisted PNG screenshot / image.
  final String? imagePath;
  final DateTime timestamp;
  bool isFavorite;
  /// Freeform note for favorites (shown under content).
  String? comment;
  final String? sourceBundleId;
  final String? sourceAppName;
  /// Hide content in UI when masking is enabled.
  bool isSensitive;

  ClipboardItem({
    String? id,
    required this.content,
    this.html,
    this.rtf,
    this.imagePath,
    required this.timestamp,
    this.isFavorite = false,
    this.comment,
    this.sourceBundleId,
    this.sourceAppName,
    this.isSensitive = false,
  }) : id = id ?? const Uuid().v4();

  bool get hasRichText =>
      (html != null && html!.isNotEmpty) || (rtf != null && rtf!.isNotEmpty);

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  String get preview {
    if (hasImage && (content.isEmpty || content == '[image]')) {
      return 'Изображение';
    }
    const maxLength = 80;
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  String get maskedPreview => '••••••••••••';

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
        if (html != null && html!.isNotEmpty) 'html': html,
        if (rtf != null && rtf!.isNotEmpty) 'rtf': rtf,
        if (imagePath != null && imagePath!.isNotEmpty) 'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
        'isFavorite': isFavorite,
        if (hasComment) 'comment': comment,
        if (sourceBundleId != null && sourceBundleId!.isNotEmpty)
          'sourceBundleId': sourceBundleId,
        if (sourceAppName != null && sourceAppName!.isNotEmpty)
          'sourceAppName': sourceAppName,
        if (isSensitive) 'isSensitive': true,
      };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    try {
      return ClipboardItem(
        id: json['id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        html: _optionalString(json['html']),
        rtf: _optionalString(json['rtf']),
        imagePath: _optionalString(json['imagePath']),
        timestamp: DateTime.parse(
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        ),
        isFavorite: json['isFavorite'] == true || json['isFavorite'] == 'true',
        comment: _optionalString(json['comment']),
        sourceBundleId: _optionalString(json['sourceBundleId']),
        sourceAppName: _optionalString(json['sourceAppName']),
        isSensitive:
            json['isSensitive'] == true || json['isSensitive'] == 'true',
      );
    } catch (e) {
      print('Error creating ClipboardItem from JSON: $e');
      print('JSON data: $json');
      return ClipboardItem(
        content: 'Error loading item',
        timestamp: DateTime.now(),
      );
    }
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
