import 'dart:io';
import 'dart:ui' as ui;

import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:copy_paste_plus/theme/app_theme.dart';
import 'package:copy_paste_plus/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generates PNG screenshots for docs/screenshots.
/// Run:
///   flutter test test/docs_screenshot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory('docs/screenshots');

  Future<void> capture(
    WidgetTester tester, {
    required String fileName,
    required Widget child,
    Size size = const Size(400, 620),
  }) async {
    outDir.createSync(recursive: true);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: RepaintBoundary(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
    // Avoid pumpAndSettle — theme/shadow animations can keep the queue busy.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${outDir.path}/$fileName');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('Wrote ${file.path} (${file.lengthSync()} bytes)');
  }

  testWidgets('docs: main history window', (tester) async {
    await capture(
      tester,
      fileName: 'main-history.png',
      child: const _DemoMainWindow(tab: 0),
    );
  });

  testWidgets('docs: favorites window', (tester) async {
    await capture(
      tester,
      fileName: 'favorites.png',
      child: const _DemoMainWindow(tab: 1),
    );
  });

  testWidgets('docs: settings window', (tester) async {
    await capture(
      tester,
      fileName: 'settings.png',
      size: const Size(400, 720),
      child: const _DemoSettingsWindow(),
    );
  });
}

class _DemoMainWindow extends StatelessWidget {
  const _DemoMainWindow({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = tab == 0
        ? const [
            ('git commit -m "hire me"', '2 мин назад', true),
            ('https://github.com/fso13/copy_paste_plus', '10 мин назад', false),
            ('⌘⇧C forever', 'вчера', true),
          ]
        : const [
            ('git commit -m "hire me"', '2 мин назад', true),
            ('⌘⇧C forever', 'вчера', true),
          ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppPanel(
        title: 'clipboard.history',
        actions: [
          Icon(Icons.settings_outlined, size: 16, color: palette.muted),
          const SizedBox(width: 8),
          Icon(Icons.close, size: 16, color: palette.muted),
          const SizedBox(width: 4),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: palette.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ready for ⌘C spam',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Menlo',
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
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
                    Text('Поиск…',
                        style: TextStyle(color: palette.muted, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                child: Row(
                  children: [
                    Expanded(child: _TabChip(label: 'История', selected: tab == 0)),
                    Expanded(child: _TabChip(label: 'Избранное', selected: tab == 1)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final (text, ago, fav) = items[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.bgElevated.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 34,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: fav ? palette.yellow : palette.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.ink,
                                    fontFamily: 'Menlo',
                                  )),
                              const SizedBox(height: 4),
                              Text(ago,
                                  style: TextStyle(
                                      fontSize: 11, color: palette.muted)),
                            ],
                          ),
                        ),
                        Icon(
                          fav ? Icons.star : Icons.star_border,
                          size: 16,
                          color: fav ? palette.yellow : palette.muted,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? palette.current : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: selected
            ? Border.all(color: palette.accent.withValues(alpha: 0.45))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? palette.accent : palette.muted,
        ),
      ),
    );
  }
}

class _DemoSettingsWindow extends StatelessWidget {
  const _DemoSettingsWindow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppPanel(
        title: 'settings.cfg',
        actions: [
          Icon(Icons.close, size: 16, color: palette.muted),
          const SizedBox(width: 4),
        ],
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SettingsCard(
              title: 'Тема',
              subtitle: 'По умолчанию используется тема системы',
              child: Column(
                children: [
                  _Option(label: 'Как в системе', selected: true),
                  const SizedBox(height: 8),
                  _Option(label: 'Светлая', selected: false),
                  const SizedBox(height: 8),
                  _Option(label: 'Тёмная', selected: false),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              title: 'Обновления',
              subtitle: 'Проверка GitHub Releases примерно раз в 12 часов',
              child: Column(
                children: [
                  _Option(label: 'Уведомлять', selected: true),
                  const SizedBox(height: 8),
                  _Option(label: 'Выключено', selected: false),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              title: 'О приложении',
              footer: Text(
                '© CopyPastePlus · built with coffee & clipboard 🦇',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  color: palette.muted,
                ),
              ),
              child: Column(
                children: [
                  _Info(label: 'Версия', value: '1.0.1'),
                  const SizedBox(height: 8),
                  _Info(label: 'Номер сборки', value: '2'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? palette.accent.withValues(alpha: 0.14)
            : palette.codeBar.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? palette.accent : palette.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? palette.accent : palette.ink,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: palette.mutedBright)),
        ),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Menlo',
              color: palette.accent,
            )),
      ],
    );
  }
}
