import 'dart:async';

import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:flutter/material.dart';

class MainWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const MainWindow({super.key, 
    required this.onClose,
    required this.onOpenSettings,
  });

  @override
  _MainWindowState createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> with SingleTickerProviderStateMixin {
  final ClipboardManager _clipboardManager = clipboardManager;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<ClipboardItem> _currentItems = [];
  StreamSubscription<List<ClipboardItem>>? _subscription;
  
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _subscribeToStream();
  }

  void _handleTabChange() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  void _subscribeToStream() {
    _subscription?.cancel();
    
    _subscription = _clipboardManager.listen((items) {
      if (mounted) {
        setState(() {
          _currentItems = items;
        });
      }
    }, onError: (error) {  }, onDone: () {  });
    
    _clipboardManager.refreshStreams();
  }

  List<ClipboardItem> _getFilteredItems() {
    final items = _currentTabIndex == 0 
        ? _clipboardManager.items
        : _clipboardManager.favorites;
    
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) return items;
    
    return items.where((item) => 
      item.content.toLowerCase().contains(searchQuery)
    ).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'История'),
            Tab(icon: Icon(Icons.star), text: 'Избранное'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onOpenSettings,
            tooltip: 'Настройки',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: 'Закрыть',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(filteredItems),
          _buildFavoritesTab(filteredItems),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Поиск...',
        border: InputBorder.none,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              )
            : null,
      ),
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildHistoryTab(List<ClipboardItem> items) {
    return _buildItemsList(items, 'истории');
  }

  Widget _buildFavoritesTab(List<ClipboardItem> items) {
    if (_clipboardManager.favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет избранных элементов'),
            SizedBox(height: 8),
            Text('Добавляйте элементы в избранное звездочкой'),
          ],
        ),
      );
    }
    
    return _buildItemsList(items, 'избранном');
  }

  Widget _buildItemsList(List<ClipboardItem> items, String listType) {
    if (items.isEmpty) {
      final message = _searchController.text.isEmpty
          ? 'Нет элементов в $listType'
          : 'Ничего не найдено для "${_searchController.text}"';
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(message),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildClipboardItem(item);
      },
    );
  }

  Widget _buildClipboardItem(ClipboardItem item) {
    return ListTile(
      title: Text(
        item.preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(item.timeAgo),
      trailing: IconButton(
        icon: Icon(
          item.isFavorite ? Icons.star : Icons.star_border,
          color: item.isFavorite ? Colors.amber : null,
        ),
        onPressed: () => _clipboardManager.toggleFavorite(item.id),
      ),
      onTap: () => _handleItemTap(item),
      onLongPress: () => _showItemOptions(context, item),
    );
  }

  void _handleItemTap(ClipboardItem item) async {
    await _clipboardManager.copyToClipboard(item);
    widget.onClose();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Скопировано в буфер обмена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showItemOptions(BuildContext context, ClipboardItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Копировать'),
              onTap: () {
                Navigator.pop(context);
                _handleItemTap(item);
              },
            ),
            ListTile(
              leading: Icon(item.isFavorite ? Icons.star : Icons.star_border),
              title: Text(item.isFavorite ? 'Убрать из избранного' : 'Добавить в избранное'),
              onTap: () {
                Navigator.pop(context);
                _clipboardManager.toggleFavorite(item.id);
              },
            ),
          ],
        );
      },
    );
  }
}