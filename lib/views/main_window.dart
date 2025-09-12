// lib/views/main_window.dart
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:flutter/material.dart';

class MainWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const MainWindow({super.key, required this.onClose, required this.onOpenSettings});

  @override
  _MainWindowState createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  final ClipboardManager _clipboardManager = ClipboardManager();
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard Manager'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onOpenSettings, // Теперь работает!
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('История')),
                ButtonSegment(value: 1, label: Text('Избранное')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedTab = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? _buildHistoryList()
                : _buildFavoritesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<ClipboardItem>>(
      stream: _clipboardManager.itemsStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(child: Text('История буфера обмена пуста'));
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildClipboardItem(item);
          },
        );
      },
    );
  }

  Widget _buildFavoritesList() {
    return StreamBuilder<List<ClipboardItem>>(
      stream: _clipboardManager.favoritesStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(child: Text('Нет избранных элементов'));
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildClipboardItem(item);
          },
        );
      },
    );
  }

  Widget _buildClipboardItem(ClipboardItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(item.preview, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isFavorite ? Icons.star : Icons.star_border,
                color: item.isFavorite ? Colors.amber : Colors.grey,
                size: 20,
              ),
              onPressed: () {
                _clipboardManager.toggleFavorite(item.id);
              },
            ),
            IconButton(
              icon: const Icon(Icons.content_copy, size: 20),
              onPressed: () {
                _clipboardManager.copyToClipboard(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано в буфер обмена')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Вызываем метод refreshStreams вместо прямого доступа к потокам
                _clipboardManager.refreshStreams();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Список обновлен')),
                );
              },
            ),
          ],
        ),
        onTap: () {
          _clipboardManager.copyToClipboard(item);
          widget.onClose();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Скопировано в буфер обмена')),
          );
        },
      ),
    );
  }
}
