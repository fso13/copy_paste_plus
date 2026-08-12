import 'dart:io';
import 'dart:ui' as ui;

import 'package:copy_paste_plus/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/docs_screenshot_demos.dart';

/// Prefer: flutter run -t tool/generate_docs_screenshots.dart -d macos
/// (widget-test toImage often hangs on macOS desktop).
///
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    final file = File('${outDir.path}/$fileName');
    await file.writeAsBytes(bytes!);
    // ignore: avoid_print
    print('Wrote ${file.path} (${file.lengthSync()} bytes)');
  }

  testWidgets('docs: main history window', (tester) async {
    await capture(
      tester,
      fileName: 'main-history.png',
      child: DocsScreenshotDemos.mainWindow(tab: 0),
    );
  }, skip: true);

  testWidgets('docs: favorites window', (tester) async {
    await capture(
      tester,
      fileName: 'favorites.png',
      child: DocsScreenshotDemos.mainWindow(tab: 1),
    );
  }, skip: true);

  testWidgets('docs: snippets window', (tester) async {
    await capture(
      tester,
      fileName: 'snippets.png',
      child: DocsScreenshotDemos.mainWindow(tab: 2),
    );
  }, skip: true);

  testWidgets('docs: settings window', (tester) async {
    await capture(
      tester,
      fileName: 'settings.png',
      size: const Size(400, 780),
      child: DocsScreenshotDemos.settingsWindow(),
    );
  }, skip: true);

  testWidgets('docs: help window', (tester) async {
    await capture(
      tester,
      fileName: 'help.png',
      size: const Size(400, 720),
      child: DocsScreenshotDemos.helpWindow(),
    );
  }, skip: true);
}
