import 'dart:io';
import 'dart:ui' as ui;

import 'package:copy_paste_plus/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'docs_screenshot_demos.dart';

/// Real-engine screenshot generator (widget-test toImage hangs on macOS).
///
///   flutter run -t tool/generate_docs_screenshots.dart -d macos
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ShotApp());
}

class _ShotApp extends StatefulWidget {
  const _ShotApp();

  @override
  State<_ShotApp> createState() => _ShotAppState();
}

class _ShotAppState extends State<_ShotApp> {
  final _key = GlobalKey();
  var _index = 0;

  static final _shots = <({String file, Size size, Widget child})>[
    (
      file: 'main-history.png',
      size: const Size(400, 620),
      child: DocsScreenshotDemos.mainWindow(tab: 0),
    ),
    (
      file: 'favorites.png',
      size: const Size(400, 620),
      child: DocsScreenshotDemos.mainWindow(tab: 1),
    ),
    (
      file: 'snippets.png',
      size: const Size(400, 620),
      child: DocsScreenshotDemos.mainWindow(tab: 2),
    ),
    (
      file: 'settings.png',
      size: const Size(400, 780),
      child: DocsScreenshotDemos.settingsWindow(),
    ),
    (
      file: 'help.png',
      size: const Size(400, 720),
      child: DocsScreenshotDemos.helpWindow(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _captureLoop());
  }

  Future<void> _captureLoop() async {
    // Sandboxed macOS app: cwd is the container Data dir. Write there, then
    // copy into the repo with the shell helper (see docs/README.md).
    final outDir = Directory('docs/screenshots')..createSync(recursive: true);
    stdout.writeln('cwd=${Directory.current.path}');
    stdout.writeln('out=${outDir.absolute.path}');

    while (_index < _shots.length) {
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        stderr.writeln('No boundary for ${_shots[_index].file}');
        exit(1);
      }

      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = '${outDir.path}/${_shots[_index].file}';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      stdout.writeln(
        'Wrote ${File(path).absolute.path} (${File(path).lengthSync()} bytes)',
      );
      _index++;
    }

    stdout.writeln('Done.');
    stdout.writeln(
      'Copy into the repo:\n'
      '  cp -f "${outDir.absolute.path}/"*.png docs/screenshots/',
    );
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shots[_index.clamp(0, _shots.length - 1)];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1C24),
        body: Center(
          child: RepaintBoundary(
            key: _key,
            child: SizedBox(
              width: shot.size.width,
              height: shot.size.height,
              child: shot.child,
            ),
          ),
        ),
      ),
    );
  }
}
