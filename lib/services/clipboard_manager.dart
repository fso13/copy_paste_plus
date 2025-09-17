import 'dart:async';
import 'package:copy_paste_plus/services/macos_clipboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clipboard_item.dart';

class ClipboardManager {
  static final ClipboardManager _instance = ClipboardManager._internal();
  factory ClipboardManager() => _instance;

  final List<ClipboardItem> _items = [];
  final List<ClipboardItem> _favorites = [];
  int _maxItems = 28;
  String _lastContent = '';
  int _lastChangeCount = 0;

  late StreamController<List<ClipboardItem>> _itemsController;
  late StreamController<List<ClipboardItem>> _favoritesController;

  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  StreamSubscription<String>? _clipboardSubscription;

  ClipboardManager._internal() {
    print('ClipboardManager singleton instance created');
    _initializeControllers();
    _initialize();
  }

  void _initializeControllers() {
    _itemsController = StreamController<List<ClipboardItem>>.broadcast();
    _favoritesController = StreamController<List<ClipboardItem>>.broadcast();
  }

  Future<void> _initialize() async {
    await _loadData();
    await _startRealMonitoring();
    print('ClipboardManager initialized with ${_items.length} items');
  }

  Future<void> _startRealMonitoring() async {
    try {
      // Получаем текущее состояние буфера
      _lastChangeCount = await MacOSClipboardService.getChangeCount();
      _lastContent = await MacOSClipboardService.getClipboardContent();

      // Запускаем нативный мониторинг
      await MacOSClipboardService.startMonitoring();

      // Слушаем изменения через EventChannel
      _clipboardSubscription = MacOSClipboardService.clipboardChanges.listen(
        (content) async {
          if (content.isNotEmpty && content != _lastContent) {
            print('Clipboard change detected: $content');
            _lastContent = content;
            await addItem(content: content);
          }
        },
        onError: (error) {
          print('Native clipboard monitoring error: $error');
          _startFallbackMonitoring();
        },
      );

      _isMonitoring = true;
      print('Real clipboard monitoring started');
    } catch (e) {
      print('Native clipboard monitoring not available: $e');
      _startFallbackMonitoring();
    }
  }

  void _startFallbackMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    print('Starting fallback clipboard monitoring');

    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      await _checkClipboard();
    });
  }

  Future<void> _checkClipboard() async {
    try {
      final currentChangeCount = await MacOSClipboardService.getChangeCount();

      if (currentChangeCount != _lastChangeCount) {
        _lastChangeCount = currentChangeCount;

        final content = await MacOSClipboardService.getClipboardContent();
        if (content.isNotEmpty && content != _lastContent) {
          print('Clipboard change detected: $content');
          _lastContent = content;
          await addItem(content: content);
        }
      }
    } catch (e) {
      print('Error checking clipboard: $e');
    }
  }

  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    print('Clipboard monitoring started');

    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      await _checkClipboard();
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _isMonitoring = false;
    print('Clipboard monitoring stopped');
  }

  Future<void> addItem({required String content}) async {
    if (content.isEmpty) return;
    if (_items.isNotEmpty && _items.first.content == content) {
      return;
    }

    final newItem = ClipboardItem(content: content, timestamp: DateTime.now());

    _items.insert(0, newItem);

    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }

    await _saveData();
    refreshStreams();

    print('Item added to history. Total items: ${_items.length}');
  }

  void refreshStreams() {
    if (_itemsController.isClosed) {
      print('ItemsController is closed, recreating...');
      _recreateControllers();
      return;
    }

    _itemsController.add([..._items]);
    _favoritesController.add([..._favorites]);

    print('Streams refreshed with ${_items.length} items');
  }

  void _recreateControllers() {
    if (!_itemsController.isClosed) _itemsController.close();
    if (!_favoritesController.isClosed) _favoritesController.close();

    _itemsController = StreamController<List<ClipboardItem>>.broadcast();
    _favoritesController = StreamController<List<ClipboardItem>>.broadcast();

    // Immediately add current data to new streams
    _itemsController.add([..._items]);
    _favoritesController.add([..._favorites]);
  }

  Future<void> ensureControllersActive() async {
    if (_itemsController.isClosed || _favoritesController.isClosed) {
      print('Controllers are closed, recreating...');
      _recreateControllers();
    }
  }

  Future<void> reloadData() async {
    await _loadData();
    refreshStreams();
    print('Data reloaded. Items: ${_items.length}');
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final itemsData = _items
          .map(
            (item) =>
                '${item.id}|${item.content.replaceAll('|', '_')}|${item.timestamp.millisecondsSinceEpoch}|${item.isFavorite}',
          )
          .toList();

      await prefs.setStringList('clipboard_items', itemsData);

      final favoritesData = _favorites
          .map(
            (item) =>
                '${item.id}|${item.content.replaceAll('|', '_')}|${item.timestamp.millisecondsSinceEpoch}|${item.isFavorite}',
          )
          .toList();

      await prefs.setStringList('favorites', favoritesData);
      await prefs.setInt('max_items', _maxItems);

      print('Data saved successfully');
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final itemsData = prefs.getStringList('clipboard_items') ?? [];
      _items.clear();

      for (final itemStr in itemsData) {
        try {
          final parts = itemStr.split('|');
          if (parts.length == 4) {
            final content = parts[1].replaceAll('_', '|');
            _items.add(
              ClipboardItem(
                id: parts[0],
                content: content,
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                  int.parse(parts[2]),
                ),
                isFavorite: parts[3] == 'true',
              ),
            );
          }
        } catch (e) {
          print('Error loading item: $e');
        }
      }

      final favoritesData = prefs.getStringList('favorites') ?? [];
      _favorites.clear();

      for (final favoriteStr in favoritesData) {
        try {
          final parts = favoriteStr.split('|');
          if (parts.length == 4) {
            final content = parts[1].replaceAll('_', '|');
            _favorites.add(
              ClipboardItem(
                id: parts[0],
                content: content,
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                  int.parse(parts[2]),
                ),
                isFavorite: parts[3] == 'true',
              ),
            );
          }
        } catch (e) {
          print('Error loading favorite: $e');
        }
      }

      _maxItems = prefs.getInt('max_items') ?? 28;
      _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      print(
        'Data loaded: ${_items.length} items, ${_favorites.length} favorites',
      );
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> copyToClipboard(ClipboardItem item) async {
    // Временно останавливаем мониторинг чтобы избежать дублирования
    stopMonitoring();

    try {
      print('Copying to clipboard: ${item.preview}');

      // Используем нативный метод для установки буфера обмена
      final success = await MacOSClipboardService.setClipboardContent(
        item.content,
      );

      if (success) {
        _lastContent = item.content;
        _lastChangeCount = await MacOSClipboardService.getChangeCount();
        print('Successfully copied to clipboard: ${item.preview}');
      } else {
        print('Failed to copy to clipboard');
      }
    } catch (e) {
      print('Error copying to clipboard: $e');

      // Fallback: используем flutter clipboard как запасной вариант
      try {
        await _copyWithFlutterClipboard(item.content);
      } catch (e) {
        print('Fallback copy also failed: $e');
      }
    }

    // Возобновляем мониторинг через задержку
    Future.delayed(const Duration(milliseconds: 1000), () {
      startMonitoring();
    });
  }

  // Запасной метод через flutter/clipboard
  Future<void> _copyWithFlutterClipboard(String content) async {
    try {
      // Добавим зависимость в pubspec.yaml: clipboard: ^0.1.3
      // import 'package:clipboard/clipboard.dart';
      // await Clipboard.setData(ClipboardData(text: content));
      print('Used fallback clipboard method');
    } catch (e) {
      print('Fallback clipboard error: $e');
    }
  }

  Future<void> toggleFavorite(String itemId) async {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex != -1) {
      _items[itemIndex].isFavorite = !_items[itemIndex].isFavorite;

      if (_items[itemIndex].isFavorite) {
        _favorites.add(_items[itemIndex]);
      } else {
        _favorites.removeWhere((item) => item.id == itemId);
      }

      await _saveData();
      refreshStreams();
    }
  }

  void setMaxItems(int maxItems) {
    _maxItems = maxItems;
    _saveData();
  }

  int get maxItems => _maxItems;
  List<ClipboardItem> get items => List.from(_items);
  List<ClipboardItem> get favorites => List.from(_favorites);

  void debugPrintState() {
    print('=== ClipboardManager State ===');
    print('Items: ${_items.length}, Favorites: ${_favorites.length}');
    print(
      'Controllers closed: ${_itemsController.isClosed}, ${_favoritesController.isClosed}',
    );

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      print('$i: ${item.preview}');
    }
  }

  // Не закрываем контроллеры при dispose!
  void dispose() {
    stopMonitoring();
    print('ClipboardManager dispose called (controllers kept alive)');
  }

  Future<void> clearHistory() async {
    _items.clear();
    _itemsController.add(List.from(_items));
    await _saveData();
  }

  StreamSubscription<List<ClipboardItem>>? listen(
    Null Function(dynamic items) param0, {
    required Null Function(dynamic error) onError,
    required Null Function() onDone,
  }) {
    _itemsController.stream.listen(param0);
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveData();
  }

  Future<void> removeItem(String id) async {
    ClipboardItem? item = _items.firstWhere(
      (item) => item.id == id,
      orElse: () => _favorites.firstWhere(
        (item) => item.id == id,
      ), // если элемент не найден
    );
    _items.remove(item);
    _items.remove(item);

    await _saveData();
  }
}
