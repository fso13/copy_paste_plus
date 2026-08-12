import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/models/content_type_colors.dart';
import 'package:copy_paste_plus/services/app_settings.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/macos_clipboard_service.dart';
import 'package:copy_paste_plus/services/snippet_service.dart';
import 'package:copy_paste_plus/services/text_transforms.dart';
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
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _historyScrollController = ScrollController();
  final ScrollController _favoritesScrollController = ScrollController();
  final ScrollController _snippetsScrollController = ScrollController();

  StreamSubscription<List<ClipboardItem>>? _subscription;

  late TabController _tabController;
  int _currentTabIndex = 0;
  int _selectedIndex = 0;
  late final String _emptyHistoryJoke;
  late final String _emptyFavoritesJoke;
  final Set<String> _revealedSensitiveIds = {};

  bool get _isSnippetsTab => _currentTabIndex == 2;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _emptyHistoryJoke =
        emptyHistoryJokes[rng.nextInt(emptyHistoryJokes.length)];
    _emptyFavoritesJoke =
        emptyFavoritesJokes[rng.nextInt(emptyFavoritesJokes.length)];
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _subscribeToStream();
    AppSettings.instance.addListener(_onSettingsChanged);
    SnippetService.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }
  void _handleTabChange() {
    setState(() {
      _currentTabIndex = _tabController.index;
      _selectedIndex = 0;
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

  List<ClipboardItem> get _visibleItems {
    if (_currentTabIndex == 0) {
      return _filtered(_clipboardManager.items);
    }
    if (_currentTabIndex == 1) {
      return _filtered(_clipboardManager.favorites);
    }
    return const [];
  }

  List<Snippet> get _visibleSnippets {
    final searchQuery = _searchController.text.toLowerCase();
    final all = SnippetService.instance.snippets;
    if (searchQuery.isEmpty) return all;
    return all
        .where(
          (s) =>
              s.title.toLowerCase().contains(searchQuery) ||
              s.body.toLowerCase().contains(searchQuery),
        )
        .toList();
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

  void _moveSelection(int delta, int itemCount) {
    if (itemCount == 0) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, itemCount - 1);
    });
    _ensureSelectedVisible();
  }

  ScrollController get _activeScrollController {
    switch (_currentTabIndex) {
      case 0:
        return _historyScrollController;
      case 1:
        return _favoritesScrollController;
      default:
        return _snippetsScrollController;
    }
  }

  void _ensureSelectedVisible() {
    final scrollController = _activeScrollController;
    if (!scrollController.hasClients) return;
    const itemExtent = 78.0;
    final target = _selectedIndex * itemExtent;
    final viewHeight = scrollController.position.viewportDimension;
    final current = scrollController.offset;
    if (target < current) {
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else if (target + itemExtent > current + viewHeight) {
      scrollController.animateTo(
        (target + itemExtent - viewHeight).clamp(
          0.0,
          scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _activateSelected() async {
    if (_isSnippetsTab) {
      final snippets = _visibleSnippets;
      if (snippets.isEmpty) return;
      final index = _selectedIndex.clamp(0, snippets.length - 1);
      await _handleSnippetTap(snippets[index]);
      return;
    }
    final items = _visibleItems;
    if (items.isEmpty) return;
    final index = _selectedIndex.clamp(0, items.length - 1);
    await _handleItemTap(items[index]);
  }

  bool get _searchHasFocus => _searchFocusNode.hasFocus;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final itemCount =
        _isSnippetsTab ? _visibleSnippets.length : _visibleItems.length;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (_searchHasFocus) {
        _searchFocusNode.unfocus();
        _listFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (_searchHasFocus) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1, itemCount);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1, itemCount);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activateSelected();
      return KeyEventResult.handled;
    }

    final digitMap = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.digit5: 4,
      LogicalKeyboardKey.digit6: 5,
      LogicalKeyboardKey.digit7: 6,
      LogicalKeyboardKey.digit8: 7,
      LogicalKeyboardKey.digit9: 8,
      LogicalKeyboardKey.numpad1: 0,
      LogicalKeyboardKey.numpad2: 1,
      LogicalKeyboardKey.numpad3: 2,
      LogicalKeyboardKey.numpad4: 3,
      LogicalKeyboardKey.numpad5: 4,
      LogicalKeyboardKey.numpad6: 5,
      LogicalKeyboardKey.numpad7: 6,
      LogicalKeyboardKey.numpad8: 7,
      LogicalKeyboardKey.numpad9: 8,
    };

    final quickIndex = digitMap[key];
    if (quickIndex != null && quickIndex < itemCount) {
      if (_isSnippetsTab) {
        _handleSnippetTap(_visibleSnippets[quickIndex]);
      } else {
        _handleItemTap(_visibleItems[quickIndex]);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listFocusNode.dispose();
    _historyScrollController.dispose();
    _favoritesScrollController.dispose();
    _snippetsScrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final historyItems = _filtered(_clipboardManager.items);
    final favoriteItems = _filtered(_clipboardManager.favorites);
    final snippets = _visibleSnippets;
    final isHistoryTab = _currentTabIndex == 0;
    final isFavoritesTab = _currentTabIndex == 1;
    final visibleCount = _isSnippetsTab
        ? snippets.length
        : (isHistoryTab ? historyItems : favoriteItems).length;
    final hasClipboardItems =
        (isHistoryTab && historyItems.isNotEmpty) ||
        (isFavoritesTab && favoriteItems.isNotEmpty);

    if (_selectedIndex >= visibleCount && visibleCount > 0) {
      _selectedIndex = visibleCount - 1;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
      },
      child: Focus(
        focusNode: _listFocusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
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
                    onChanged: (_) => setState(() {
                      _selectedIndex = 0;
                    }),
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
                        Tab(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _currentTabIndex == 2
                                    ? Icons.code
                                    : Icons.code_outlined,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              const Text('Сниппеты'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasClipboardItems)
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
                if (_isSnippetsTab)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _editSnippet(),
                        icon: Icon(Icons.add, size: 14, color: palette.accent),
                        label: Text(
                          'Добавить',
                          style:
                              TextStyle(fontSize: 11, color: palette.accent),
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
                      _buildItemsList(
                        historyItems,
                        scrollController: _historyScrollController,
                      ),
                      _buildFavoritesTab(favoriteItems),
                      _buildSnippetsTab(snippets),
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
    return _buildItemsList(
      items,
      scrollController: _favoritesScrollController,
    );
  }

  Widget _buildSnippetsTab(List<Snippet> snippets) {
    if (SnippetService.instance.snippets.isEmpty) {
      return _EmptyState(
        icon: Icons.code_outlined,
        title: 'Пока нет сниппетов',
        subtitle:
            'Шаблоны с плейсхолдерами {{name}} — заполните и вставьте в один клик',
      );
    }
    if (snippets.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title: 'Ничего не найдено для "${_searchController.text}" 🕵️',
        subtitle: null,
      );
    }

    final palette = context.palette;
    return ListView.separated(
      controller: _snippetsScrollController,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      itemCount: snippets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final snippet = snippets[index];
        final selected = index == _selectedIndex;
        final placeholders = snippet.placeholders;
        final preview = snippet.body.replaceAll(RegExp(r'\s+'), ' ').trim();
        final shortcutLabel = index < 9 ? '${index + 1}' : null;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleSnippetTap(snippet),
            onLongPress: () => _showSnippetOptions(snippet),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
              decoration: BoxDecoration(
                color: selected
                    ? palette.current.withValues(alpha: 0.55)
                    : palette.bgElevated.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? palette.accent.withValues(alpha: 0.7)
                      : palette.line.withValues(alpha: 0.75),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3.5,
                      margin: const EdgeInsets.only(left: 2, right: 8),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (shortcutLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.current.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: palette.line),
                            ),
                            child: Text(
                              shortcutLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Menlo',
                                fontWeight: FontWeight.w600,
                                color: palette.mutedBright,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snippet.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preview.isEmpty ? '(пусто)' : preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontFamily: 'Menlo',
                              color: palette.mutedBright,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            placeholders.isEmpty
                                ? 'без плейсхолдеров'
                                : '${placeholders.length} {{…}}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Menlo',
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: palette.muted,
                      ),
                      onPressed: () => _showSnippetOptions(snippet),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      splashRadius: 14,
                      tooltip: 'Меню',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList(
    List<ClipboardItem> items, {
    required ScrollController scrollController,
  }) {
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

    final maskSensitive = AppSettings.instance.maskSensitiveEnabled;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = items[index];
        final masked = maskSensitive &&
            item.isSensitive &&
            !_revealedSensitiveIds.contains(item.id);
        return _ClipboardItemTile(
          item: item,
          index: index,
          selected: index == _selectedIndex,
          masked: masked,
          onTap: () => _handleItemTap(item),
          onShowMenu: () => _showItemOptions(item),
          onToggleFavorite: () async {
            await _clipboardManager.toggleFavorite(item.id);
            if (mounted) setState(() {});
          },
          onToggleReveal: item.isSensitive && maskSensitive
              ? () {
                  setState(() {
                    if (_revealedSensitiveIds.contains(item.id)) {
                      _revealedSensitiveIds.remove(item.id);
                    } else {
                      _revealedSensitiveIds.add(item.id);
                    }
                  });
                }
              : null,
        );
      },
    );
  }

  Future<void> _handleItemTap(ClipboardItem item) async {
    await _copyItemAndClose(item);
  }

  Future<void> _copyTextAndClose(String content) async {
    await _copyItemAndClose(
      ClipboardItem(content: content, timestamp: DateTime.now()),
    );
  }

  Future<void> _copyItemAndClose(ClipboardItem item) async {
    final autoPaste = AppSettings.instance.autoPasteEnabled;

    if (autoPaste) {
      var trusted = await MacOSClipboardService.isAccessibilityTrusted();
      if (!trusted) {
        trusted = await MacOSClipboardService.requestAccessibility();
      }
      if (!trusted && mounted) {
        final palette = context.palette;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Нужен Универсальный доступ'),
            content: const Text(
              'Для авто-вставки разрешите CopyPastePlus в '
              'Системные настройки → Конфиденциальность → Универсальный доступ.\n\n'
              'Сейчас фрагмент будет только скопирован в буфер.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Позже', style: TextStyle(color: palette.muted)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  MacOSClipboardService.openAccessibilitySettings();
                },
                child: Text(
                  'Открыть настройки',
                  style: TextStyle(color: palette.accent),
                ),
              ),
            ],
          ),
        );
        await _clipboardManager.copyToClipboard(item);
        if (!mounted) return;
        // Let any dialog routes finish before tearing down MainWindow.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        widget.onClose();
        return;
      }
    }

    await _clipboardManager.copyToClipboard(item);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    widget.onClose();

    if (autoPaste) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await MacOSClipboardService.pasteToPreviousApp();
    }
  }

  Future<void> _handleSnippetTap(Snippet snippet) async {
    final names = snippet.placeholders;
    if (names.isEmpty) {
      await _copyTextAndClose(snippet.render(const {}));
      return;
    }

    final values = await _promptSnippetPlaceholders(snippet, names);
    if (values == null || !mounted) return;
    // showDialog completes on pop; the route still animates out briefly.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    await _copyTextAndClose(snippet.render(values));
  }

  Future<Map<String, String>?> _promptSnippetPlaceholders(
    Snippet snippet,
    List<String> names,
  ) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _SnippetPlaceholdersDialog(
        title: snippet.title,
        names: names,
      ),
    );
  }

  void _showSnippetOptions(Snippet snippet) {
    final palette = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: palette.bgElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading:
                      Icon(Icons.edit_outlined, size: 20, color: palette.cyan),
                  title: Text(
                    'Изменить',
                    style: TextStyle(color: palette.ink, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editSnippet(snippet);
                  },
                ),
                ListTile(
                  leading:
                      Icon(Icons.delete_outline, size: 20, color: palette.red),
                  title: Text(
                    'Удалить',
                    style: TextStyle(fontSize: 14, color: palette.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteSnippet(snippet);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editSnippet([Snippet? existing]) async {
    final result = await showDialog<({String title, String body})>(
      context: context,
      builder: (context) => _SnippetEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    await SnippetService.instance.upsert(
      id: existing?.id,
      title: result.title,
      body: result.body,
    );
    if (mounted) setState(() {});
    _showSnack(existing == null ? 'Сниппет добавлен' : 'Сниппет сохранён');
  }

  Future<void> _deleteSnippet(Snippet snippet) async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сниппет'),
        content: Text('Удалить «${snippet.title}»? Это действие нельзя отменить.'),
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
    if (confirmed != true) return;
    await SnippetService.instance.remove(snippet.id);
    if (mounted) setState(() {});
    _showSnack('Сниппет удалён');
  }

  Future<void> _showTransformDialog(ClipboardItem item) async {
    final palette = context.palette;
    final transform = await showDialog<TextTransform>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Преобразовать'),
          content: SizedBox(
            width: 320,
            height: 360,
            child: ListView(
              children: [
                for (final t in TextTransform.values)
                  ListTile(
                    dense: true,
                    title: Text(
                      t.title,
                      style: TextStyle(fontSize: 13, color: palette.ink),
                    ),
                    onTap: () => Navigator.pop(context, t),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: TextStyle(color: palette.muted)),
            ),
          ],
        );
      },
    );

    if (transform == null || !mounted) return;

    final result = TextTransforms.apply(transform, item.content);
    if (!result.ok) {
      _showSnack(result.error ?? 'Не удалось преобразовать');
      return;
    }
    await _copyTextAndClose(result.value!);
  }

  void _showItemOptions(ClipboardItem item) {
    final palette = context.palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: palette.bgElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.content_copy,
                      size: 20, color: palette.cyan),
                  title: Text(
                    'Копировать',
                    style: TextStyle(color: palette.ink, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleItemTap(item);
                  },
                ),
                ListTile(
                  leading: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                    size: 20,
                    color:
                        item.isFavorite ? palette.yellow : palette.mutedBright,
                  ),
                  title: Text(
                    item.isFavorite
                        ? 'Убрать из избранного'
                        : 'Добавить в избранное',
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
                  leading: Icon(
                    item.isSensitive
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                    size: 20,
                    color: item.isSensitive
                        ? palette.yellow
                        : palette.mutedBright,
                  ),
                  title: Text(
                    item.isSensitive
                        ? 'Снять тип secret'
                        : 'Сделать типом secret',
                    style: TextStyle(color: palette.ink, fontSize: 14),
                  ),
                  subtitle: Text(
                    item.isSensitive
                        ? 'Показывать как обычный текст'
                        : 'Маскировать содержимое (пароль / токен)',
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final makeSecret = !item.isSensitive;
                    await _clipboardManager.setItemSensitive(
                      item.id,
                      makeSecret,
                    );
                    if (!mounted) return;
                    setState(() {
                      if (makeSecret) {
                        _revealedSensitiveIds.remove(item.id);
                      }
                    });
                    _showSnack(
                      makeSecret
                          ? 'Тип изменён на secret'
                          : 'Тип secret снят',
                    );
                  },
                ),
                if (!item.hasImage)
                  ListTile(
                    leading: Icon(
                      Icons.transform,
                      size: 20,
                      color: palette.accentPink,
                    ),
                    title: Text(
                      'Преобразовать…',
                      style: TextStyle(color: palette.ink, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showTransformDialog(item);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      size: 20, color: palette.red),
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
          ),
        );
      },
    );
  }

  Future<void> _editFavoriteComment(ClipboardItem item) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => _CommentEditorDialog(
        initialText: item.comment ?? '',
        canClear: item.hasComment,
      ),
    );
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

class _ClipboardItemTile extends StatefulWidget {
  const _ClipboardItemTile({
    required this.item,
    required this.index,
    required this.selected,
    required this.masked,
    required this.onTap,
    required this.onShowMenu,
    required this.onToggleFavorite,
    this.onToggleReveal,
  });

  final ClipboardItem item;
  final int index;
  final bool selected;
  final bool masked;
  final VoidCallback onTap;
  final VoidCallback onShowMenu;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onToggleReveal;

  @override
  State<_ClipboardItemTile> createState() => _ClipboardItemTileState();
}

class _ClipboardItemTileState extends State<_ClipboardItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = widget.item;
    final kind = detectContentType(
      content: item.content,
      isSensitive: item.isSensitive,
      hasImage: item.hasImage,
    );
    final typeColor = AppSettings.instance.colorFor(kind);
    final highlighted = widget.selected || _hovered;
    final shortcutLabel = widget.index < 9 ? '${widget.index + 1}' : null;
    final showThumbnail = item.hasImage &&
        !widget.masked &&
        item.imagePath != null &&
        File(item.imagePath!).existsSync();

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
              color: highlighted
                  ? palette.current.withValues(alpha: 0.55)
                  : palette.bgElevated.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected
                    ? typeColor.withValues(alpha: 0.75)
                    : highlighted
                        ? typeColor.withValues(alpha: 0.45)
                        : palette.line.withValues(alpha: 0.75),
                width: widget.selected ? 1.4 : 1,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3.5,
                    margin: const EdgeInsets.only(left: 2, right: 8),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (shortcutLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.current.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: palette.line),
                          ),
                          child: Text(
                            shortcutLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Menlo',
                              fontWeight: FontWeight.w600,
                              color: palette.mutedBright,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showThumbnail)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(item.imagePath!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 40,
                            height: 40,
                            color: palette.current,
                            child: Icon(
                              Icons.image_outlined,
                              size: 18,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (item.hasImage && widget.masked)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: palette.current,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: palette.line),
                        ),
                        child: Icon(
                          Icons.hide_image_outlined,
                          size: 18,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.masked ? item.maskedPreview : item.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: palette.ink,
                            fontFamily: 'Menlo',
                            letterSpacing: widget.masked ? 1.2 : null,
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
                                color: typeColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                kind.badge,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'Menlo',
                                  color: typeColor,
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
                      if (widget.onToggleReveal != null)
                        IconButton(
                          icon: Icon(
                            widget.masked
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 17,
                            color: palette.muted,
                          ),
                          onPressed: widget.onToggleReveal,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          splashRadius: 14,
                          tooltip: widget.masked ? 'Показать' : 'Скрыть',
                        ),
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

class _SnippetPlaceholdersDialog extends StatefulWidget {
  const _SnippetPlaceholdersDialog({
    required this.title,
    required this.names,
  });

  final String title;
  final List<String> names;

  @override
  State<_SnippetPlaceholdersDialog> createState() =>
      _SnippetPlaceholdersDialogState();
}

class _SnippetPlaceholdersDialogState extends State<_SnippetPlaceholdersDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final name in widget.names) name: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in widget.names) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '{{$name}}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Menlo',
                      color: palette.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _controllers[name],
                  autofocus: name == widget.names.first,
                  style: TextStyle(fontSize: 13, color: palette.ink),
                  decoration: InputDecoration(
                    hintText: name,
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
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: TextStyle(color: palette.muted)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              for (final e in _controllers.entries) e.key: e.value.text,
            });
          },
          child: Text('Вставить', style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}

class _SnippetEditorDialog extends StatefulWidget {
  const _SnippetEditorDialog({this.existing});

  final Snippet? existing;

  @override
  State<_SnippetEditorDialog> createState() => _SnippetEditorDialogState();
}

class _SnippetEditorDialogState extends State<_SnippetEditorDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _bodyController =
      TextEditingController(text: widget.existing?.body ?? '');

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Новый сниппет' : 'Изменить сниппет',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: palette.ink),
              decoration: InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: palette.muted, fontSize: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 8,
              minLines: 4,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Menlo',
                color: palette.ink,
                height: 1.35,
              ),
              decoration: InputDecoration(
                labelText: 'Текст',
                labelStyle: TextStyle(color: palette.muted, fontSize: 12),
                hintText: 'используйте {{name}}',
                hintStyle: TextStyle(color: palette.muted, fontSize: 13),
                alignLabelWithHint: true,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: TextStyle(color: palette.muted)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, (
              title: _titleController.text,
              body: _bodyController.text,
            ));
          },
          child: Text('Сохранить', style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}

class _CommentEditorDialog extends StatefulWidget {
  const _CommentEditorDialog({
    required this.initialText,
    required this.canClear,
  });

  final String initialText;
  final bool canClear;

  @override
  State<_CommentEditorDialog> createState() => _CommentEditorDialogState();
}

class _CommentEditorDialogState extends State<_CommentEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: const Text('Комментарий'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
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
        if (widget.canClear)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Удалить', style: TextStyle(color: palette.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: TextStyle(color: palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('Сохранить', style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}
