// lib/services/clipboard_manager.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clipboard_item.dart';

class ClipboardManager {
  static final ClipboardManager _instance = ClipboardManager._internal();
  factory ClipboardManager() => _instance;
  ClipboardManager._internal();

  final List<ClipboardItem> _items = [];
  final List<ClipboardItem> _favorites = [];
  int _maxItems = 50;
  String _lastContent = '';
  
  final StreamController<List<ClipboardItem>> _itemsController = 
      StreamController<List<ClipboardItem>>.broadcast();
  final StreamController<List<ClipboardItem>> _favoritesController = 
      StreamController<List<ClipboardItem>>.broadcast();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  Stream<List<ClipboardItem>> get itemsStream => _itemsController.stream;
  Stream<List<ClipboardItem>> get favoritesStream => _favoritesController.stream;

  Future<void> initialize() async {
    await _loadData();
    startMonitoring();
    print('ClipboardManager initialized with ${_items.length} items');
  }

  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    print('Clipboard monitoring started');
    
    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _checkClipboard();
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _isMonitoring = false;
    print('Clipboard monitoring stopped');
  }

  Future<void> _checkClipboard() async {
    try {
      final text = await Clipboard.getData(Clipboard.kTextPlain);
      if (text != null && text.text != null && text.text!.isNotEmpty) {
        final currentContent = text.text!;
        if (currentContent != _lastContent) {
          print('New clipboard content detected: ${_truncateText(currentContent)}');
          _lastContent = currentContent;
          await addItem(
            content: currentContent,
            type: ClipboardContentType.text,
          );
        }
      }
    } catch (e) {
      print('Error checking clipboard: $e');
    }
  }

  String _truncateText(String text) {
    const maxLength = 60;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Future<void> addItem({
    required String content,
    required ClipboardContentType type,
    String? additionalData,
  }) async {
    // Проверяем на дубликаты (последний элемент)
    if (_items.isNotEmpty && _items.first.content == content) {
      print('Duplicate content, skipping');
      return;
    }

    final newItem = ClipboardItem(
      content: content,
      type: type,
      timestamp: DateTime.now(),
      additionalData: additionalData,
    );

    _items.insert(0, newItem);

    // Ограничение количества элементов
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }

    _itemsController.add(List.from(_items));
    await _saveData();
    
    print('Item added to history. Total items: ${_items.length}');
  }

  Future<void> forceAddItem(String content) async {
    if (content.isEmpty) return;
    
    _lastContent = content;
    await addItem(
      content: content,
      type: ClipboardContentType.text,
    );
  }

  void refreshStreams() {
    _itemsController.add(List.from(_items));
    _favoritesController.add(List.from(_favorites));
    print('Streams refreshed');
  }

  Future<void> toggleFavorite(String itemId) async {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex != -1) {
      _items[itemIndex].isFavorite = !_items[itemIndex].isFavorite;
      
      if (_items[itemIndex].isFavorite) {
        _favorites.add(_items[itemIndex]);
        print('Item added to favorites');
      } else {
        _favorites.removeWhere((item) => item.id == itemId);
        print('Item removed from favorites');
      }

      _itemsController.add(List.from(_items));
      _favoritesController.add(List.from(_favorites));
      await _saveData();
    }
  }

  Future<void> copyToClipboard(ClipboardItem item) async {
    // Временно останавливаем мониторинг чтобы избежать дублирования
    stopMonitoring();
    
    try {
      await Clipboard.setData(ClipboardData(text: item.content));
      _lastContent = item.content;
      print('Copied to clipboard: ${_truncateText(item.content)}');
    } catch (e) {
      print('Error copying to clipboard: $e');
    }
    
    // Возобновляем мониторинг через задержку
    Future.delayed(const Duration(milliseconds: 1000), () {
      startMonitoring();
    });
  }

  Future<void> removeItem(String itemId) async {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex != -1) {
      final removedItem = _items.removeAt(itemIndex);
      
      // Удаляем также из избранного если нужно
      if (removedItem.isFavorite) {
        _favorites.removeWhere((item) => item.id == itemId);
      }

      _itemsController.add(List.from(_items));
      _favoritesController.add(List.from(_favorites));
      await _saveData();
      
      print('Item removed from history');
    }
  }

  Future<void> clearHistory() async {
    _items.clear();
    // Очищаем только историю, избранное сохраняем
    _itemsController.add(List.from(_items));
    await _saveData();
    print('History cleared');
  }

  Future<void> clearAll() async {
    _items.clear();
    _favorites.clear();
    _itemsController.add(List.from(_items));
    _favoritesController.add(List.from(_favorites));
    await _saveData();
    print('All data cleared');
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final itemsJson = _items.map((item) => _mapToJsonString(item.toJson())).toList();
      await prefs.setStringList('clipboard_items', itemsJson);
      
      final favoritesJson = _favorites.map((item) => _mapToJsonString(item.toJson())).toList();
      await prefs.setStringList('favorites', favoritesJson);
      
      await prefs.setInt('max_items', _maxItems);
      
      print('Data saved successfully');
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  String _mapToJsonString(Map<String, dynamic> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Загрузка истории
      final itemsData = prefs.getStringList('clipboard_items') ?? [];
      _items.clear();
      for (final itemJson in itemsData) {
        try {
          final decodedJson = _parseJsonString(itemJson);
          final item = ClipboardItem.fromJson(decodedJson);
          _items.add(item);
        } catch (e) {
          print('Error loading item: $e');
        }
      }
      
      // Загрузка избранного
      final favoritesData = prefs.getStringList('favorites') ?? [];
      _favorites.clear();
      for (final favoriteJson in favoritesData) {
        try {
          final decodedJson = _parseJsonString(favoriteJson);
          final item = ClipboardItem.fromJson(decodedJson);
          _favorites.add(item);
        } catch (e) {
          print('Error loading favorite: $e');
        }
      }
      
      _maxItems = prefs.getInt('max_items') ?? 50;
      
      // Обновляем последний контент из последнего элемента
      if (_items.isNotEmpty) {
        _lastContent = _items.first.content;
      }
      
      refreshStreams();
      print('Data loaded: ${_items.length} items, ${_favorites.length} favorites');
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Map<String, dynamic> _parseJsonString(String jsonString) {
    final Map<String, dynamic> result = {};
    final pairs = jsonString.split(',');
    
    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();
        
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else {
          result[key] = value;
        }
      }
    }
    
    return result;
  }

  void setMaxItems(int maxItems) {
    _maxItems = maxItems;
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
      _itemsController.add(List.from(_items));
    }
    _saveData();
    print('Max items set to: $maxItems');
  }

  int get maxItems => _maxItems;
  List<ClipboardItem> get items => List.from(_items);
  List<ClipboardItem> get favorites => List.from(_favorites);

  ClipboardItem? getItemById(String id) {
    return _items.firstWhere((item) => item.id == id);
  }

  List<ClipboardItem> searchItems(String query) {
    if (query.isEmpty) return List.from(_items);
    
    final lowercaseQuery = query.toLowerCase();
    return _items.where((item) => 
      item.content.toLowerCase().contains(lowercaseQuery) ||
      item.timestamp.toString().toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  void dispose() {
    stopMonitoring();
    _itemsController.close();
    _favoritesController.close();
    print('ClipboardManager disposed');
  }
}