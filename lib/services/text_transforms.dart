import 'dart:convert';

/// Built-in text transforms for clipboard items.
enum TextTransform {
  trim,
  jsonPretty,
  jsonMinify,
  base64Encode,
  base64Decode,
  urlEncode,
  urlDecode,
  slug,
  upperCase,
  lowerCase,
  snakeCase,
  camelCase,
}

extension TextTransformLabel on TextTransform {
  String get title {
    switch (this) {
      case TextTransform.trim:
        return 'Trim (обрезать пробелы)';
      case TextTransform.jsonPretty:
        return 'JSON pretty';
      case TextTransform.jsonMinify:
        return 'JSON minify';
      case TextTransform.base64Encode:
        return 'Base64 encode';
      case TextTransform.base64Decode:
        return 'Base64 decode';
      case TextTransform.urlEncode:
        return 'URL encode';
      case TextTransform.urlDecode:
        return 'URL decode';
      case TextTransform.slug:
        return 'Slug';
      case TextTransform.upperCase:
        return 'UPPER CASE';
      case TextTransform.lowerCase:
        return 'lower case';
      case TextTransform.snakeCase:
        return 'snake_case';
      case TextTransform.camelCase:
        return 'camelCase';
    }
  }

  String get shortTitle {
    switch (this) {
      case TextTransform.trim:
        return 'Trim';
      case TextTransform.jsonPretty:
        return 'JSON pretty';
      case TextTransform.jsonMinify:
        return 'JSON minify';
      case TextTransform.base64Encode:
        return 'Base64 →';
      case TextTransform.base64Decode:
        return '← Base64';
      case TextTransform.urlEncode:
        return 'URL encode';
      case TextTransform.urlDecode:
        return 'URL decode';
      case TextTransform.slug:
        return 'Slug';
      case TextTransform.upperCase:
        return 'UPPER';
      case TextTransform.lowerCase:
        return 'lower';
      case TextTransform.snakeCase:
        return 'snake_case';
      case TextTransform.camelCase:
        return 'camelCase';
    }
  }
}

class TextTransformResult {
  const TextTransformResult({required this.ok, this.value, this.error});

  final bool ok;
  final String? value;
  final String? error;
}

class TextTransforms {
  TextTransforms._();

  static TextTransformResult apply(TextTransform transform, String input) {
    try {
      switch (transform) {
        case TextTransform.trim:
          return TextTransformResult(ok: true, value: input.trim());
        case TextTransform.jsonPretty:
          return _jsonPretty(input);
        case TextTransform.jsonMinify:
          return _jsonMinify(input);
        case TextTransform.base64Encode:
          final encoded = base64Encode(utf8.encode(input));
          return TextTransformResult(ok: true, value: encoded);
        case TextTransform.base64Decode:
          return _base64Decode(input);
        case TextTransform.urlEncode:
          return TextTransformResult(
            ok: true,
            value: Uri.encodeComponent(input),
          );
        case TextTransform.urlDecode:
          return TextTransformResult(
            ok: true,
            value: Uri.decodeComponent(input.trim()),
          );
        case TextTransform.slug:
          return TextTransformResult(ok: true, value: _slug(input));
        case TextTransform.upperCase:
          return TextTransformResult(ok: true, value: input.toUpperCase());
        case TextTransform.lowerCase:
          return TextTransformResult(ok: true, value: input.toLowerCase());
        case TextTransform.snakeCase:
          return TextTransformResult(ok: true, value: _snake(input));
        case TextTransform.camelCase:
          return TextTransformResult(ok: true, value: _camel(input));
      }
    } catch (e) {
      return TextTransformResult(ok: false, error: e.toString());
    }
  }

  static TextTransformResult _jsonPretty(String input) {
    final decoded = jsonDecode(input.trim());
    const encoder = JsonEncoder.withIndent('  ');
    return TextTransformResult(ok: true, value: encoder.convert(decoded));
  }

  static TextTransformResult _jsonMinify(String input) {
    final decoded = jsonDecode(input.trim());
    return TextTransformResult(ok: true, value: jsonEncode(decoded));
  }

  static TextTransformResult _base64Decode(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), '');
    final bytes = base64Decode(cleaned);
    return TextTransformResult(ok: true, value: utf8.decode(bytes));
  }

  static String _slug(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[^\w\s-]'), '');
    s = s.replaceAll(RegExp(r'[\s_-]+'), '-');
    return s.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static String _snake(String input) {
    final spaced = input
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .replaceAll(RegExp(r'[\s-]+'), '_');
    return spaced.toLowerCase().replaceAll(RegExp(r'_+'), '_');
  }

  static String _camel(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'[\s_\-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.toLowerCase();
    final rest = parts.skip(1).map((p) {
      final lower = p.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join();
    return '$first$rest';
  }
}
