// lib/utils/json_utils.dart
import 'dart:convert';

Map<String, dynamic> parseJsonString(String jsonString) {
  try {
    // Пробуем стандартный JSON парсинг
    return jsonDecode(jsonString);
  } catch (e) {
    // Fallback: простой парсинг
    final cleanedString = jsonString.replaceAll('{', '').replaceAll('}', '');
    final pairs = cleanedString.split(', ');
    final Map<String, dynamic> result = {};
    
    for (final pair in pairs) {
      final keyValue = pair.split(': ');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        var value = keyValue[1].trim();
        
        // Убираем кавычки если есть
        if (value.startsWith("'") && value.endsWith("'")) {
          value = value.substring(1, value.length - 1);
        } else if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }
        
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }
    
    return result;
  }
}

String mapToJsonString(Map<String, dynamic> map) {
  return jsonEncode(map);
}