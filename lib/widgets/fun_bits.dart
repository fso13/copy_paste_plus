import 'dart:math';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:flutter/material.dart';

const funToasts = [
  '🦇 Welcome to the dark side of clipboard',
  '404: boring paste history not found',
  'git commit -m "ctrl+c forever"',
  'Stack: Flutter, vibes, ⌘⇧C',
  'compiling excuses…',
  'TODO: hire this clipboard',
];

const emptyHistoryJokes = [
  'Буфер голоден. Скопируй что-нибудь вкусное.',
  'Здесь пока пусто — как prod в пятницу вечером.',
  'Waiting for clipboard events…',
];

const emptyFavoritesJokes = [
  'Избранное пусто. Добавь звёздочку — будет магия ✨',
  'No favorites yet. Be the first star.',
  'Любимые фрагменты появятся здесь.',
];

class FunBatOverlay extends StatefulWidget {
  const FunBatOverlay({super.key, required this.active});

  final bool active;

  @override
  State<FunBatOverlay> createState() => _FunBatOverlayState();
}

class _FunBatOverlayState extends State<FunBatOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant FunBatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          if (_controller.value == 0) return const SizedBox.shrink();
          return Stack(
            children: [
              Positioned(
                left: -40 + 420 * t,
                top: 40 + 30 * sin(t * pi),
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: const Text('🦇', style: TextStyle(fontSize: 18)),
                ),
              ),
              Positioned(
                left: -60 + 400 * t,
                top: 80 + 20 * sin(t * pi + 1),
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: const Text('🦇', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StatusTicker extends StatefulWidget {
  const StatusTicker({super.key});

  @override
  State<StatusTicker> createState() => _StatusTickerState();
}

class _StatusTickerState extends State<StatusTicker> {
  static const _lines = [
    'compiling excuses…',
    'watching clipboard like hawk 🦅',
    'ready for ⌘C spam',
    'no bugs, only features',
    'built with coffee & Flutter',
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _index = (_index + 1) % _lines.length);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: palette.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.green.withValues(alpha: 0.55),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            _lines[_index],
            key: ValueKey(_index),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Menlo',
              color: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}
