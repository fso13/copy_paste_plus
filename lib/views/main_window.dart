import 'dart:async';
import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:flutter/material.dart';

class MainWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const MainWindow({
    super.key,
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
    }, onError: (error) {}, onDone: () {});
    
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

  void _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю'),
        content: const Text('Вы уверены, что хотите очистить всю историю? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clipboardManager.clearHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('История очищена'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _clearFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить избранное'),
        content: const Text('Вы уверены, что хотите очистить все избранное? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clipboardManager.clearFavorites();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Избранное очищено'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
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
    final hasItems = filteredItems.isNotEmpty;
    final isHistoryTab = _currentTabIndex == 0;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(8),
        child: Column(
          children: [
            // macOS-style title bar
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  // macOS traffic lights
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Буфер обмена',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, size: 16, color: Colors.grey[600]),
                    onPressed: widget.onOpenSettings,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[500]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                            onPressed: _clearSearch,
                            padding: EdgeInsets.zero,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ),
            
            // Tabs
            Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2,
                indicatorColor: Colors.blue,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'История'),
                  Tab(text: 'Избранное'),
                ],
              ),
            ),
            
            // Clear button (only visible when there are items)
            if (hasItems) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: isHistoryTab ? _clearHistory : _clearFavorites,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isHistoryTab ? 'Очистить историю' : 'Очистить избранное',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHistoryTab(filteredItems),
                  _buildFavoritesTab(filteredItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(List<ClipboardItem> items) {
    return _buildItemsList(items, 'истории');
  }

  Widget _buildFavoritesTab(List<ClipboardItem> items) {
    if (_clipboardManager.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет избранных элементов',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавляйте элементы в избранное звездочкой',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
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
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
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
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          item.preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          item.timeAgo,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: Icon(
            item.isFavorite ? Icons.star : Icons.star_border,
            size: 18,
            color: item.isFavorite ? Colors.amber : Colors.grey[500],
          ),
          onPressed: () => _clipboardManager.toggleFavorite(item.id),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        onTap: () => _handleItemTap(item),
        onLongPress: () => _showItemOptions(context, item),
      ),
    );
  }

  void _handleItemTap(ClipboardItem item) async {
    await _clipboardManager.copyToClipboard(item);
    widget.onClose();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Скопировано в буфер обмена'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showItemOptions(BuildContext context, ClipboardItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.content_copy, size: 20, color: Colors.grey[700]),
                title: Text('Копировать', style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _handleItemTap(item);
                },
              ),
              ListTile(
                leading: Icon(
                  item.isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: item.isFavorite ? Colors.amber : Colors.grey[700],
                ),
                title: Text(
                  item.isFavorite ? 'Убрать из избранного' : 'Добавить в избранное',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clipboardManager.toggleFavorite(item.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
                title: Text(
                  'Удалить',
                  style: TextStyle(fontSize: 14, color: Colors.red[400]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(ClipboardItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить элемент'),
        content: const Text('Вы уверены, что хотите удалить этот элемент?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clipboardManager.removeItem(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Элемент удален'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}