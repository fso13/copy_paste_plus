import 'dart:async';
import 'dart:convert';

import 'package:copy_paste_plus/services/app_settings.dart';
import 'package:copy_paste_plus/services/macos_clipboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clipboard_item.dart';
import '../utils/constants.dart';

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
  StreamSubscription<ClipboardPayload>? _clipboardSubscription;

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
    await AppSettings.instance.load();
    await _loadData();
    await _startRealMonitoring();
    print('ClipboardManager initialized with ${_items.length} items');
  }

  Future<void> _startRealMonitoring() async {
    try {
      _lastChangeCount = await MacOSClipboardService.getChangeCount();
      final current = await MacOSClipboardService.getClipboardContent();
      _lastContent = current.content;

      await MacOSClipboardService.startMonitoring();

      _clipboardSubscription = MacOSClipboardService.clipboardChanges.listen(
        (payload) async {
          if (!payload.isEmpty && payload.content != _lastContent) {
            print('Clipboard change detected: ${payload.content}');
            _lastContent = payload.content.isNotEmpty
                ? payload.content
                : (payload.imagePath ?? '');
            await addItem(
              content: payload.content.isEmpty && payload.hasImage
                  ? '[image]'
                  : payload.content,
              html: payload.html,
              rtf: payload.rtf,
              imagePath: payload.imagePath,
              sourceBundleId: payload.sourceBundleId,
              sourceAppName: payload.sourceAppName,
            );
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

        final payload = await MacOSClipboardService.getClipboardContent();
        if (!payload.isEmpty && payload.content != _lastContent) {
          print('Clipboard change detected: ${payload.content}');
          _lastContent = payload.content.isNotEmpty
              ? payload.content
              : (payload.imagePath ?? '');
          await addItem(
            content: payload.content.isEmpty && payload.hasImage
                ? '[image]'
                : payload.content,
            html: payload.html,
            rtf: payload.rtf,
            imagePath: payload.imagePath,
            sourceBundleId: payload.sourceBundleId,
            sourceAppName: payload.sourceAppName,
          );
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

  Future<void> addItem({
    required String content,
    String? html,
    String? rtf,
    String? imagePath,
    String? sourceBundleId,
    String? sourceAppName,
  }) async {
    if (content.isEmpty && (imagePath == null || imagePath.isEmpty)) return;

    final settings = AppSettings.instance;
    if (settings.isIgnored(sourceBundleId)) {
      print('Ignored clipboard from $sourceBundleId');
      return;
    }

    if (_items.isNotEmpty &&
        _items.first.content == content &&
        (_items.first.imagePath ?? '') == (imagePath ?? '')) {
      // Refresh rich formats / image if we previously stored plain-only.
      final first = _items.first;
      final enrichRich = !first.hasRichText &&
          ((html != null && html.isNotEmpty) ||
              (rtf != null && rtf.isNotEmpty));
      final enrichImage = !first.hasImage &&
          imagePath != null &&
          imagePath.isNotEmpty;
      if (enrichRich || enrichImage) {
        _items[0] = ClipboardItem(
          id: first.id,
          content: content,
          html: html ?? first.html,
          rtf: rtf ?? first.rtf,
          imagePath: imagePath ?? first.imagePath,
          timestamp: first.timestamp,
          isFavorite: first.isFavorite,
          comment: first.comment,
          sourceBundleId: first.sourceBundleId ?? sourceBundleId,
          sourceAppName: first.sourceAppName ?? sourceAppName,
          isSensitive: first.isSensitive,
        );
        final favIndex = _favorites.indexWhere((item) => item.id == first.id);
        if (favIndex != -1) {
          _favorites[favIndex] = _items[0];
        }
        await _saveData();
        refreshStreams();
      }
      return;
    }

    final isSensitive = settings.isPasswordManager(sourceBundleId) ||
        MacOSClipboardService.looksLikeSecret(content);

    final newItem = ClipboardItem(
      content: content,
      html: html,
      rtf: rtf,
      imagePath: imagePath,
      timestamp: DateTime.now(),
      sourceBundleId: sourceBundleId,
      sourceAppName: sourceAppName,
      isSensitive: isSensitive,
    );

    _items.insert(0, newItem);

    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }

    await _saveData();
    refreshStreams();

    print(
      'Item added to history (rich=${newItem.hasRichText} image=${newItem.hasImage}). Total: ${_items.length}',
    );
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
      final encrypt = AppSettings.instance.encryptionEnabled;

      final itemsData = <String>[];
      for (final item in _items) {
        itemsData.add(await _encodeStoredItem(item, encrypt: encrypt));
      }
      await prefs.setStringList('clipboard_items', itemsData);

      final favoritesData = <String>[];
      for (final item in _favorites) {
        favoritesData.add(await _encodeStoredItem(item, encrypt: encrypt));
      }
      await prefs.setStringList('favorites', favoritesData);
      await prefs.setInt('max_items', _maxItems);

      print('Data saved successfully (encrypt=$encrypt)');
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
        final item = await _parseStoredItem(itemStr);
        if (item != null) _items.add(item);
      }

      final favoritesData = prefs.getStringList('favorites') ?? [];
      _favorites.clear();
      for (final favoriteStr in favoritesData) {
        final item = await _parseStoredItem(favoriteStr);
        if (item != null) _favorites.add(item);
      }

      _maxItems = prefs.getInt('max_items') ?? AppConstants.defaultMaxItems;
      if (_maxItems < 10) _maxItems = 10;
      _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      print(
        'Data loaded: ${_items.length} items, ${_favorites.length} favorites',
      );
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  static const _encPrefix = 'cpp1:';

  Future<String> _encodeStoredItem(
    ClipboardItem item, {
    required bool encrypt,
  }) async {
    final json = jsonEncode(item.toJson());
    if (!encrypt) return json;
    final result = await MacOSClipboardService.encryptString(json);
    if (!result.ok || result.text == null) {
      print('Encrypt failed, storing plaintext: ${result.error}');
      return json;
    }
    return '$_encPrefix${result.text}';
  }

  /// Supports JSON (current), encrypted `cpp1:…`, and legacy `id|content|ts|fav`.
  Future<ClipboardItem?> _parseStoredItem(String raw) async {
    try {
      var payload = raw;
      if (raw.startsWith(_encPrefix)) {
        final cipher = raw.substring(_encPrefix.length);
        final decrypted = await MacOSClipboardService.decryptString(cipher);
        if (!decrypted.ok || decrypted.text == null) {
          print('Decrypt failed: ${decrypted.error}');
          return null;
        }
        payload = decrypted.text!;
      }

      final trimmed = payload.trimLeft();
      if (trimmed.startsWith('{')) {
        return ClipboardItem.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        );
      }

      final parts = payload.split('|');
      if (parts.length == 4) {
        return ClipboardItem(
          id: parts[0],
          content: parts[1].replaceAll('_', '|'),
          timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2])),
          isFavorite: parts[3] == 'true',
        );
      }
    } catch (e) {
      print('Error loading item: $e');
    }
    return null;
  }

  /// Re-persists history after toggling encryption on/off.
  Future<void> repersistWithCurrentEncryption() async {
    await _saveData();
  }

  Future<void> copyToClipboard(ClipboardItem item) async {
    stopMonitoring();

    try {
      print(
        'Copying to clipboard: ${item.preview} (rich=${item.hasRichText} image=${item.hasImage})',
      );

      bool success;
      if (item.hasImage &&
          (item.content.isEmpty || item.content == '[image]')) {
        success = await MacOSClipboardService.setClipboardImage(item.imagePath!);
      } else {
        success = await MacOSClipboardService.setClipboardContent(
          content: item.content,
          html: item.html,
          rtf: item.rtf,
        );
        if (success && item.hasImage) {
          // Prefer text when both exist; image stays on disk for later.
        }
      }

      if (success) {
        _lastContent = item.content;
        _lastChangeCount = await MacOSClipboardService.getChangeCount();
        print('Successfully copied to clipboard: ${item.preview}');
      } else {
        print('Failed to copy to clipboard');
      }
    } catch (e) {
      print('Error copying to clipboard: $e');
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      startMonitoring();
    });
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

  /// Sets a freeform comment on a favorite (empty clears it).
  Future<void> setFavoriteComment(String itemId, String? comment) async {
    final normalized = comment?.trim();
    final value = (normalized == null || normalized.isEmpty) ? null : comment;

    var updated = false;
    for (final item in _items) {
      if (item.id == itemId) {
        item.comment = value;
        updated = true;
      }
    }
    for (final item in _favorites) {
      if (item.id == itemId) {
        item.comment = value;
        updated = true;
      }
    }

    if (!updated) return;
    await _saveData();
    refreshStreams();
  }

  /// Marks / unmarks an item as secret (masked in UI when masking is on).
  Future<void> setItemSensitive(String itemId, bool sensitive) async {
    var updated = false;
    for (final item in _items) {
      if (item.id == itemId) {
        item.isSensitive = sensitive;
        updated = true;
      }
    }
    for (final item in _favorites) {
      if (item.id == itemId) {
        item.isSensitive = sensitive;
        updated = true;
      }
    }

    if (!updated) return;
    await _saveData();
    refreshStreams();
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
      print('$i: ${item.preview} rich=${item.hasRichText}');
    }
  }

  void dispose() {
    stopMonitoring();
    print('ClipboardManager dispose called (controllers kept alive)');
  }

  Future<void> clearHistory() async {
    _items.clear();
    await _saveData();
    refreshStreams();
  }

  StreamSubscription<List<ClipboardItem>> listen(
    void Function(List<ClipboardItem> items) onData, {
    Function? onError,
    void Function()? onDone,
  }) {
    return _itemsController.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
    );
  }

  Future<void> clearFavorites() async {
    for (final item in _items) {
      item.isFavorite = false;
    }
    _favorites.clear();
    await _saveData();
    refreshStreams();
  }

  Future<void> removeItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    _favorites.removeWhere((item) => item.id == id);
    await _saveData();
    refreshStreams();
  }
}
