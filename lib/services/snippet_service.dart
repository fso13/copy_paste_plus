import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Snippet {
  Snippet({
    String? id,
    required this.title,
    required this.body,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String body;
  DateTime updatedAt;

  /// Placeholder names in `{{name}}` form, unique, ordered by first appearance.
  List<String> get placeholders {
    final re = RegExp(r'\{\{\s*([a-zA-Z_][\w]*)\s*\}\}');
    final seen = <String>{};
    final result = <String>[];
    for (final match in re.allMatches(body)) {
      final name = match.group(1)!;
      if (seen.add(name)) result.add(name);
    }
    return result;
  }

  String render(Map<String, String> values) {
    return body.replaceAllMapped(
      RegExp(r'\{\{\s*([a-zA-Z_][\w]*)\s*\}\}'),
      (match) {
        final name = match.group(1)!;
        return values[name] ?? match.group(0)!;
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Snippet.fromJson(Map<String, dynamic> json) {
    return Snippet(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? 'Без названия',
      body: json['body']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SnippetService {
  SnippetService._();
  static final SnippetService instance = SnippetService._();

  static const _prefsKey = 'snippets';

  final List<Snippet> _snippets = [];
  bool _loaded = false;

  List<Snippet> get snippets => List.unmodifiable(_snippets);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    _snippets
      ..clear()
      ..addAll(
        raw.map((s) {
          try {
            return Snippet.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }).whereType<Snippet>(),
      );
    _snippets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _snippets.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<Snippet> upsert({
    String? id,
    required String title,
    required String body,
  }) async {
    await load();
    final trimmedTitle = title.trim().isEmpty ? 'Без названия' : title.trim();
    if (id != null) {
      final index = _snippets.indexWhere((s) => s.id == id);
      if (index != -1) {
        _snippets[index].title = trimmedTitle;
        _snippets[index].body = body;
        _snippets[index].updatedAt = DateTime.now();
        await _save();
        return _snippets[index];
      }
    }
    final snippet = Snippet(title: trimmedTitle, body: body);
    _snippets.insert(0, snippet);
    await _save();
    return snippet;
  }

  Future<void> remove(String id) async {
    await load();
    _snippets.removeWhere((s) => s.id == id);
    await _save();
  }
}
