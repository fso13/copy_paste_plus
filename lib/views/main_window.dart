import 'dart:async';
import 'dart:math';
import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:copy_paste_plus/widgets/app_panel.dart';
import 'package:copy_paste_plus/widgets/brand_mark.dart';
import 'package:copy_paste_plus/widgets/fun_bits.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    return items.where((item) {
      if (item.content.toLowerCase().contains(searchQuery)) return true;
      final comment = item.comment;
      return comment != null && comment.toLowerCase().contains(searchQuery);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) setState(() {});
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
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
    final visibleCount =
        isHistoryTab ? historyItems.length : favoriteItems.length;
    final hasItems = visibleCount > 0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AppPanel(
            title: 'clipboard.history',
            actions: [
              _HeaderIconButton(
                icon: Icons.settings_outlined,
                onPressed: widget.onOpenSettings,
              ),
              const SizedBox(width: 2),
              _HeaderIconButton(
                icon: Icons.close,
                onPressed: widget.onClose,
              ),
            ],
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandMark(iconSize: 26, fontSize: 17),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: _SearchField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (_) => setState(() {}),
                    onClear: _clearSearch,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: palette.line.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: UnderlineTabIndicator(
                        borderSide:
                            BorderSide(color: palette.accent, width: 2.5),
                        insets: EdgeInsets.zero,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      labelColor: palette.accent,
                      unselectedLabelColor: palette.muted,
                      tabs: [
                        const Tab(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.schedule, size: 15),
                              SizedBox(width: 6),
                              Text('История'),
                            ],
                          ),
                        ),
                        Tab(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _currentTabIndex == 1
                                    ? Icons.star_rounded
                                    : Icons.star_outline,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              const Text('Избранное'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasItems)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            isHistoryTab ? _clearHistory : _clearFavorites,
                        icon: Icon(Icons.delete_outline,
                            size: 14, color: palette.muted),
                        label: Text(
                          isHistoryTab ? 'Очистить' : 'Очистить избранное',
                          style:
                              TextStyle(fontSize: 11, color: palette.muted),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: palette.line)),
                    color: palette.codeBar.withValues(alpha: 0.55),
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: StatusTicker()),
                      Text(
                        '$visibleCount ${visibleCount == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Menlo',
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          onShowMenu: () => _showItemOptions(item),
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
              if (item.isFavorite)
                ListTile(
                  leading: Icon(
                    Icons.notes_outlined,
                    size: 20,
                    color: palette.accentPink,
                  ),
                  title: Text(
                    item.hasComment
                        ? 'Изменить комментарий'
                        : 'Добавить комментарий',
                    style: TextStyle(color: palette.ink, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editFavoriteComment(item);
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

  Future<void> _editFavoriteComment(ClipboardItem item) async {
    final palette = context.palette;
    final controller = TextEditingController(text: item.comment ?? '');

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Комментарий'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 6,
              minLines: 3,
              style: TextStyle(fontSize: 13, color: palette.ink, height: 1.35),
              decoration: InputDecoration(
                hintText: 'Любой текст: метка, заметка, ссылка…',
                hintStyle: TextStyle(color: palette.muted, fontSize: 13),
                filled: true,
                fillColor: palette.bgElevated.withValues(alpha: 0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.accent),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          actions: [
            if (item.hasComment)
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: Text('Удалить', style: TextStyle(color: palette.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: TextStyle(color: palette.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('Сохранить', style: TextStyle(color: palette.accent)),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (result == null || !mounted) return;

    await _clipboardManager.setFavoriteComment(item.id, result);
    if (mounted) setState(() {});
    _showSnack(
      result.trim().isEmpty ? 'Комментарий удалён' : 'Комментарий сохранён',
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
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.bgElevated.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: palette.muted),
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
                hintText: 'Поиск в истории…',
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
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: palette.current.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: palette.line),
              ),
              child: Text(
                '⌘F',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Menlo',
                  color: palette.muted,
                ),
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

String _detectContentType(String content) {
  final trimmed = content.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return 'json';
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
    return 'url';
  }
  if (RegExp(r'^(git|npm|flutter|cd|ls|brew|curl|ssh)\b').hasMatch(trimmed) ||
      trimmed.startsWith('./') ||
      trimmed.startsWith('sudo ')) {
    return 'shell';
  }
  if (trimmed.contains('function') ||
      trimmed.contains('const ') ||
      trimmed.contains('=>') ||
      trimmed.contains('console.')) {
    return 'javascript';
  }
  if (trimmed.contains('{') &&
      (trimmed.contains('color:') || trimmed.contains('background'))) {
    return 'css';
  }
  return 'text';
}

class _ClipboardItemTile extends StatefulWidget {
  const _ClipboardItemTile({
    required this.item,
    required this.onTap,
    required this.onShowMenu,
    required this.onToggleFavorite,
  });

  final ClipboardItem item;
  final VoidCallback onTap;
  final VoidCallback onShowMenu;
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
    final type = _detectContentType(item.content);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onShowMenu,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
            decoration: BoxDecoration(
              color: _hovered
                  ? palette.current.withValues(alpha: 0.45)
                  : palette.bgElevated.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered
                    ? palette.accent.withValues(alpha: 0.4)
                    : palette.line.withValues(alpha: 0.75),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3.5,
                    margin: const EdgeInsets.only(left: 2, right: 10),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
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
                            fontSize: 12.5,
                            height: 1.4,
                            color: palette.ink,
                            fontFamily: 'Menlo',
                          ),
                        ),
                        if (item.hasComment) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.comment!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.3,
                              color: palette.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              item.timeAgo,
                              style: TextStyle(
                                  fontSize: 11, color: palette.muted),
                            ),
                            Text(
                              '  ·  ',
                              style: TextStyle(
                                  fontSize: 11, color: palette.muted),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'Menlo',
                                  color: palette.accent.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          item.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                          color:
                              item.isFavorite ? palette.accent : palette.muted,
                        ),
                        onPressed: widget.onToggleFavorite,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 14,
                        tooltip: item.isFavorite
                            ? 'Убрать из избранного'
                            : 'В избранное',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: palette.muted,
                        ),
                        onPressed: widget.onShowMenu,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 14,
                        tooltip: 'Меню',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
