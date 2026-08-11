import 'dart:async';
import 'dart:math';
import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:copy_paste_plus/widgets/app_panel.dart';
import 'package:copy_paste_plus/widgets/fun_bits.dart';
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
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow>
    with SingleTickerProviderStateMixin {
  final ClipboardManager _clipboardManager = clipboardManager;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  StreamSubscription<List<ClipboardItem>>? _subscription;

  late TabController _tabController;
  int _currentTabIndex = 0;
  late final String _emptyHistoryJoke;
  late final String _emptyFavoritesJoke;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _emptyHistoryJoke =
        emptyHistoryJokes[rng.nextInt(emptyHistoryJokes.length)];
    _emptyFavoritesJoke =
        emptyFavoritesJokes[rng.nextInt(emptyFavoritesJokes.length)];
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
      if (mounted) setState(() {});
    }, onError: (error) {}, onDone: () {});

    _clipboardManager.refreshStreams();
  }

  List<ClipboardItem> _filtered(List<ClipboardItem> items) {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) return items;

    return items
        .where((item) => item.content.toLowerCase().contains(searchQuery))
        .toList();
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirm(
      title: 'Очистить историю',
      message:
          'Вы уверены, что хотите очистить всю историю? Это действие нельзя отменить.',
    );

    if (confirmed == true) {
      await _clipboardManager.clearHistory();
      if (mounted) setState(() {});
      _showSnack('История очищена');
    }
  }

  Future<void> _clearFavorites() async {
    final confirmed = await _confirm(
      title: 'Очистить избранное',
      message:
          'Вы уверены, что хотите очистить все избранное? Это действие нельзя отменить.',
    );

    if (confirmed == true) {
      await _clipboardManager.clearFavorites();
      if (mounted) setState(() {});
      _showSnack('Избранное очищено');
    }
  }

  Future<bool?> _confirm({required String title, required String message}) {
    final palette = context.palette;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Очистить', style: TextStyle(color: palette.red)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
    final palette = context.palette;
    final historyItems = _filtered(_clipboardManager.items);
    final favoriteItems = _filtered(_clipboardManager.favorites);
    final isHistoryTab = _currentTabIndex == 0;
    final hasItems = isHistoryTab ? historyItems.isNotEmpty : favoriteItems.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppPanel(
        title: 'clipboard.history',
        actions: [
          _HeaderIconButton(
            icon: Icons.settings_outlined,
            onPressed: widget.onOpenSettings,
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.close,
            onPressed: widget.onClose,
          ),
        ],
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusTicker(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: _SearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (_) => setState(() {}),
                onClear: _clearSearch,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: palette.bgElevated.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.line),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: palette.current,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.accent.withValues(alpha: 0.45)),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  labelColor: palette.accent,
                  unselectedLabelColor: palette.muted,
                  tabs: const [
                    Tab(text: 'История'),
                    Tab(text: 'Избранное'),
                  ],
                ),
              ),
            ),
            if (hasItems)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isHistoryTab ? _clearHistory : _clearFavorites,
                    icon: Icon(Icons.delete_outline, size: 14, color: palette.muted),
                    label: Text(
                      isHistoryTab ? 'Очистить историю' : 'Очистить избранное',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: palette.bgElevated.withValues(alpha: 0.65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: palette.line),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemsList(historyItems, 'истории'),
                  _buildFavoritesTab(favoriteItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesTab(List<ClipboardItem> items) {
    if (_clipboardManager.favorites.isEmpty) {
      return _EmptyState(
        icon: Icons.star_outline,
        title: _emptyFavoritesJoke,
        subtitle: 'Добавляйте элементы в избранное звездочкой ✨',
      );
    }
    return _buildItemsList(items, 'избранном');
  }

  Widget _buildItemsList(List<ClipboardItem> items, String listType) {
    if (items.isEmpty) {
      final message = _searchController.text.isEmpty
          ? _emptyHistoryJoke
          : 'Ничего не найдено для "${_searchController.text}" 🕵️';

      return _EmptyState(
        icon: Icons.search_off,
        title: message,
        subtitle: _searchController.text.isEmpty
            ? 'Скопируй что-нибудь — и магия начнётся'
            : null,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ClipboardItemTile(
          item: item,
          onTap: () => _handleItemTap(item),
          onLongPress: () => _showItemOptions(item),
          onToggleFavorite: () async {
            await _clipboardManager.toggleFavorite(item.id);
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  Future<void> _handleItemTap(ClipboardItem item) async {
    await _clipboardManager.copyToClipboard(item);
    widget.onClose();
    _showSnack('Скопировано в буфер обмена');
  }

  void _showItemOptions(ClipboardItem item) {
    final palette = context.palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.line),
            boxShadow: [
              BoxShadow(color: palette.shadow, blurRadius: 16, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.content_copy, size: 20, color: palette.cyan),
                title: Text('Копировать', style: TextStyle(color: palette.ink, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _handleItemTap(item);
                },
              ),
              ListTile(
                leading: Icon(
                  item.isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: item.isFavorite ? palette.yellow : palette.mutedBright,
                ),
                title: Text(
                  item.isFavorite ? 'Убрать из избранного' : 'Добавить в избранное',
                  style: TextStyle(color: palette.ink, fontSize: 14),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _clipboardManager.toggleFavorite(item.id);
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, size: 20, color: palette.red),
                title: Text(
                  'Удалить',
                  style: TextStyle(fontSize: 14, color: palette.red),
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

  Future<void> _showDeleteConfirmation(ClipboardItem item) async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить элемент'),
        content: const Text('Вы уверены, что хотите удалить этот элемент?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить', style: TextStyle(color: palette.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clipboardManager.removeItem(item.id);
      if (mounted) setState(() {});
      _showSnack('Элемент удален');
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      icon: Icon(icon, size: 16, color: palette.muted),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      splashRadius: 16,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasText = controller.text.isNotEmpty;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.bgElevated.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 15, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: palette.ink,
              ),
              cursorColor: palette.accent,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Поиск…',
                hintStyle: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.2,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 15, color: palette.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: palette.muted.withValues(alpha: 0.7)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.mutedBright, fontSize: 13),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClipboardItemTile extends StatefulWidget {
  const _ClipboardItemTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
  });

  final ClipboardItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;

  @override
  State<_ClipboardItemTile> createState() => _ClipboardItemTileState();
}

class _ClipboardItemTileState extends State<_ClipboardItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _hovered
                  ? palette.current.withValues(alpha: 0.55)
                  : palette.bgElevated.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hovered ? palette.accent.withValues(alpha: 0.35) : palette.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 34,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: item.isFavorite ? palette.yellow : palette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: palette.ink,
                          fontFamily: 'Menlo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.timeAgo,
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                    size: 16,
                    color: item.isFavorite ? palette.yellow : palette.muted,
                  ),
                  onPressed: widget.onToggleFavorite,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
