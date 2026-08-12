import 'package:copy_paste_plus/services/update_service.dart';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:flutter/material.dart';

Future<void> showUpdateAvailableDialog(
  BuildContext context, {
  required AppRelease release,
  required UpdateService updateService,
  bool autoOpened = false,
}) {
  final palette = context.palette;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        title: const Text('Доступно обновление'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вышла версия ${release.version}',
              style: TextStyle(color: palette.ink, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              autoOpened
                  ? 'Автообновление: откроется загрузка DMG, затем приложение закроется, чтобы можно было установить новую версию.'
                  : 'Скачается DMG, после этого CopyPastePlus закроется — так проще заменить приложение в «Программах».',
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await updateService.skipVersion(release.version);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Пропустить', style: TextStyle(color: palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Позже', style: TextStyle(color: palette.mutedBright)),
          ),
          TextButton(
            onPressed: () async {
              if (context.mounted) Navigator.pop(context);
              await updateService.openUpdate(release);
            },
            child: Text(
              'Скачать и закрыть',
              style: TextStyle(color: palette.accent),
            ),
          ),
        ],
      );
    },
  );
}
