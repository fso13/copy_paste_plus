import 'dart:async';

import 'package:copy_paste_plus/global.dart';
import 'package:copy_paste_plus/models/clipboard_item.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:flutter/material.dart';

class MainWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const MainWindow({
    required this.onClose,
    required this.onOpenSettings,
  });

  @override
  _MainWindowState createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  final ClipboardManager _clipboardManager = clipboardManager;
  List<ClipboardItem> _currentItems = [];
  StreamSubscription<List<ClipboardItem>>? _subscription;

  @override
  void initState() {
    super.initState();
    print('MainWindow initState');
    _subscribeToStream();
  }

  void _subscribeToStream() {
    print('Subscribing to stream...');
    
    // Отписываемся от старой подписки
    _subscription?.cancel();
    
    // Создаем новую подписку
    _subscription = _clipboardManager.listen(
      (items) {
        print('Received ${items.length} items in stream');
        if (mounted) {
          setState(() {
            _currentItems = items;
          });
        }
      },
      onError: (error) {
        print('Stream error: $error');
      },
      onDone: () {
        print('Stream closed');
      },
    );
    
    // Немедленно запрашиваем текущие данные
    _clipboardManager.refreshStreams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('MainWindow didChangeDependencies');
    // Пересоздаем подписку при изменениях
    _subscribeToStream();
  }

  @override
  void dispose() {
    print('MainWindow dispose');
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building MainWindow with ${_currentItems.length} items');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onOpenSettings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _clipboardManager.reloadData();
              _subscribeToStream(); // Пересоздаем подписку
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.content_paste, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('История буфера обмена пуста'),
            SizedBox(height: 8),
            Text('Скопируйте текст'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        return ListTile(
          title: Text(item.preview),
          subtitle: Text(item.timeAgo),
          trailing: IconButton(
            icon: Icon(
              item.isFavorite ? Icons.star : Icons.star_border,
              color: item.isFavorite ? Colors.amber : null,
            ),
            onPressed: () => _clipboardManager.toggleFavorite(item.id),
          ),
          onTap: () {
            _clipboardManager.copyToClipboard(item);
            widget.onClose();
          },
        );
      },
    );
  }
}