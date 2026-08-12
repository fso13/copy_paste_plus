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
  /// Keep favorite near the top of the favorites list.
  bool isPinned;
  /// Soft labels for filtering (favorites).
  List<String> tags;
  /// Exclusive collection name for favorites (null = unfiled).
  String? folder;
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
    this.isPinned = false,
    List<String>? tags,
    this.folder,
    this.sourceBundleId,
    this.sourceAppName,
    this.isSensitive = false,
  })  : id = id ?? const Uuid().v4(),
        tags = normalizeTags(tags ?? const []);

  bool get hasRichText =>
      (html != null && html!.isNotEmpty) || (rtf != null && rtf!.isNotEmpty);

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  bool get hasTags => tags.isNotEmpty;

  bool get hasFolder => folder != null && folder!.trim().isNotEmpty;

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
        if (isPinned) 'isPinned': true,
        if (hasTags) 'tags': tags,
        if (hasFolder) 'folder': folder,
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
        isPinned: json['isPinned'] == true || json['isPinned'] == 'true',
        tags: _parseTags(json['tags']),
        folder: _optionalString(json['folder']),
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

  /// Trims, strips leading `#`, dedupes case-insensitively, keeps first casing.
  static List<String> normalizeTags(Iterable<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw) {
      var tag = entry.trim();
      if (tag.startsWith('#')) tag = tag.substring(1).trim();
      if (tag.isEmpty) continue;
      final key = tag.toLowerCase();
      if (seen.add(key)) result.add(tag);
    }
    return result;
  }

  static String? normalizeFolder(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static List<String> _parseTags(dynamic value) {
    if (value is List) {
      return normalizeTags(value.map((e) => e.toString()));
    }
    if (value is String && value.trim().isNotEmpty) {
      return normalizeTags(value.split(RegExp(r'[,;\s]+')));
    }
    return const [];
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
