import 'package:flutter/material.dart';

/// Detected clipboard content kinds (badge + accent stripe).
enum ContentTypeKind {
  text,
  url,
  json,
  shell,
  javascript,
  css,
  image,
  secret,
}

extension ContentTypeKindX on ContentTypeKind {
  String get id => name;

  String get label {
    switch (this) {
      case ContentTypeKind.text:
        return 'Текст';
      case ContentTypeKind.url:
        return 'URL';
      case ContentTypeKind.json:
        return 'JSON';
      case ContentTypeKind.shell:
        return 'Shell';
      case ContentTypeKind.javascript:
        return 'JavaScript';
      case ContentTypeKind.css:
        return 'CSS';
      case ContentTypeKind.image:
        return 'Изображение';
      case ContentTypeKind.secret:
        return 'Secret (скрытый)';
    }
  }

  /// Badge label shown in the history list.
  String get badge {
    switch (this) {
      case ContentTypeKind.text:
        return 'text';
      case ContentTypeKind.url:
        return 'url';
      case ContentTypeKind.json:
        return 'json';
      case ContentTypeKind.shell:
        return 'shell';
      case ContentTypeKind.javascript:
        return 'javascript';
      case ContentTypeKind.css:
        return 'css';
      case ContentTypeKind.image:
        return 'image';
      case ContentTypeKind.secret:
        return 'secret';
    }
  }
}

/// Default Dracula-inspired accent colors per content type.
abstract final class ContentTypeColorDefaults {
  static const Map<ContentTypeKind, Color> colors = {
    ContentTypeKind.text: Color(0xFFBD93F9),
    ContentTypeKind.url: Color(0xFF8BE9FD),
    ContentTypeKind.json: Color(0xFFF1FA8C),
    ContentTypeKind.shell: Color(0xFF50FA7B),
    ContentTypeKind.javascript: Color(0xFFFFB86C),
    ContentTypeKind.css: Color(0xFFFF79C6),
    ContentTypeKind.image: Color(0xFF6272A4),
    ContentTypeKind.secret: Color(0xFFFF5555),
  };

  /// Preset swatches for the settings picker.
  static const List<Color> swatches = [
    Color(0xFFBD93F9),
    Color(0xFFFF79C6),
    Color(0xFF8BE9FD),
    Color(0xFF50FA7B),
    Color(0xFFFFB86C),
    Color(0xFFF1FA8C),
    Color(0xFFFF5555),
    Color(0xFF6272A4),
    Color(0xFFF8F8F2),
    Color(0xFF44475A),
    Color(0xFF7C5CBF),
    Color(0xFF0F7A8A),
    Color(0xFF2D8A57),
    Color(0xFFC43C3C),
    Color(0xFFB7791F),
    Color(0xFFC44D8F),
  ];
}

ContentTypeKind detectContentType({
  required String content,
  required bool isSensitive,
  required bool hasImage,
}) {
  if (isSensitive) return ContentTypeKind.secret;
  if (hasImage) return ContentTypeKind.image;

  final trimmed = content.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return ContentTypeKind.json;
  }
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
    return ContentTypeKind.url;
  }
  if (RegExp(r'^(git|npm|flutter|cd|ls|brew|curl|ssh)\b').hasMatch(trimmed) ||
      trimmed.startsWith('./') ||
      trimmed.startsWith('sudo ')) {
    return ContentTypeKind.shell;
  }
  if (trimmed.contains('function') ||
      trimmed.contains('const ') ||
      trimmed.contains('=>') ||
      trimmed.contains('console.')) {
    return ContentTypeKind.javascript;
  }
  if (trimmed.contains('{') &&
      (trimmed.contains('color:') || trimmed.contains('background'))) {
    return ContentTypeKind.css;
  }
  return ContentTypeKind.text;
}
