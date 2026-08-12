import 'package:copy_paste_plus/models/content_type_colors.dart';
import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:copy_paste_plus/widgets/app_panel.dart';
import 'package:flutter/material.dart';

/// Shared demo UIs for docs screenshots (tool + optional widget test).
abstract final class DocsScreenshotDemos {
  static Widget mainWindow({required int tab}) => DemoMainWindow(tab: tab);
  static Widget settingsWindow() => const DemoSettingsWindow();
  static Widget helpWindow() => const DemoHelpWindow();
}

class DemoMainWindow extends StatelessWidget {
  const DemoMainWindow({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
                    Text(
                      'Поиск…',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
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
                    Expanded(
                      child: DemoTabChip(label: 'История', selected: tab == 0),
                    ),
                    Expanded(
                      child: DemoTabChip(label: 'Избранное', selected: tab == 1),
                    ),
                    Expanded(
                      child: DemoTabChip(label: 'Сниппеты', selected: tab == 2),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: tab == 2
                  ? const DemoSnippetsList()
                  : DemoClipboardList(tab: tab),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoClipboardList extends StatelessWidget {
  const DemoClipboardList({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (tab == 1) {
      return const DemoFavoritesList();
    }

    final items = const [
      (
        'git commit -m "hire me"',
        '2 мин назад',
        ContentTypeKind.shell,
        true,
      ),
      (
        '••••••••••••••••',
        '5 мин назад',
        ContentTypeKind.secret,
        false,
      ),
      (
        'https://github.com/fso13/copy_paste_plus',
        '10 мин назад',
        ContentTypeKind.url,
        false,
      ),
      (
        '{"ok":true}',
        'вчера',
        ContentTypeKind.json,
        true,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final (text, meta, kind, fav) = items[i];
        final typeColor = ContentTypeColorDefaults.colors[kind]!;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: palette.bgElevated.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: typeColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.ink,
                        fontFamily: 'Menlo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          meta,
                          style: TextStyle(fontSize: 11, color: palette.muted),
                        ),
                        Text(
                          '  ·  ',
                          style: TextStyle(fontSize: 11, color: palette.muted),
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
              if (kind == ContentTypeKind.secret)
                Icon(Icons.visibility_outlined, size: 15, color: palette.muted)
              else
                Icon(
                  fav ? Icons.star : Icons.star_border,
                  size: 16,
                  color: fav ? palette.yellow : palette.muted,
                ),
              const SizedBox(width: 4),
              Icon(Icons.more_vert, size: 16, color: palette.muted),
            ],
          ),
        );
      },
    );
  }
}

class DemoFavoritesList extends StatelessWidget {
  const DemoFavoritesList();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = <({
      String text,
      String? comment,
      ContentTypeKind kind,
      bool pinned,
      String? folder,
      List<String> tags,
    })>[
      (
        text: 'git commit -m "hire me"',
        comment: null,
        kind: ContentTypeKind.shell,
        pinned: true,
        folder: 'Работа',
        tags: const ['git'],
      ),
      (
        text: 'API_TOKEN',
        comment: 'staging',
        kind: ContentTypeKind.secret,
        pinned: true,
        folder: 'Работа',
        tags: const ['aws', 'secret'],
      ),
      (
        text: '⌘⇧C forever',
        comment: null,
        kind: ContentTypeKind.text,
        pinned: false,
        folder: 'Личное',
        tags: const [],
      ),
    ];

    Widget chip({
      required String label,
      required bool selected,
      IconData? icon,
      Color? accent,
    }) {
      final color = accent ?? palette.accent;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : palette.bgElevated.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.7) : palette.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: selected ? color : palette.muted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Menlo',
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? color : palette.mutedBright,
              ),
            ),
          ],
        ),
      );
    }

    Widget metaChip({
      required String label,
      required Color color,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Menlo',
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip(label: 'Все', selected: true),
                const SizedBox(width: 6),
                chip(label: '📌 Pin', selected: false),
                const SizedBox(width: 6),
                chip(
                  label: 'Работа',
                  selected: false,
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(width: 6),
                chip(
                  label: 'Личное',
                  selected: false,
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(width: 6),
                chip(
                  label: '#aws',
                  selected: false,
                  accent: palette.cyan,
                ),
                const SizedBox(width: 6),
                chip(
                  label: '#git',
                  selected: false,
                  accent: palette.cyan,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final item = items[i];
              final typeColor = ContentTypeColorDefaults.colors[item.kind]!;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.bgElevated.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 42,
                      margin: const EdgeInsets.only(right: 10, top: 2),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.pinned) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 1, right: 4),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: 13,
                                    color: palette.orange,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  item.kind == ContentTypeKind.secret
                                      ? '••••••••••••'
                                      : item.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.ink,
                                    fontFamily: 'Menlo',
                                    letterSpacing:
                                        item.kind == ContentTypeKind.secret
                                            ? 1.2
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.comment != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.comment!,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: palette.muted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (item.folder != null || item.tags.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (item.folder != null)
                                  metaChip(
                                    label: item.folder!,
                                    color: palette.green,
                                    icon: Icons.folder_outlined,
                                  ),
                                for (final tag in item.tags)
                                  metaChip(
                                    label: '#$tag',
                                    color: palette.cyan,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                i == 0
                                    ? '2 мин назад'
                                    : (i == 1 ? '5 мин назад' : 'вчера'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.muted,
                                ),
                              ),
                              Text(
                                '  ·  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.muted,
                                ),
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
                                  item.kind.badge,
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
                    if (item.kind == ContentTypeKind.secret)
                      Icon(
                        Icons.visibility_outlined,
                        size: 15,
                        color: palette.muted,
                      )
                    else
                      Icon(Icons.star, size: 16, color: palette.yellow),
                    const SizedBox(width: 4),
                    Icon(Icons.more_vert, size: 16, color: palette.muted),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DemoSnippetsList extends StatelessWidget {
  const DemoSnippetsList();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const snippets = [
      ('Приветствие', 'Здравствуйте, {{name}}!', '1 {{…}}'),
      ('Тикет', 'Тикет {{ticket}} в работе.', '1 {{…}}'),
      ('Подпись', 'С уважением,\nCopyPastePlus', 'без плейсхолдеров'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            children: [
              Icon(Icons.code, size: 14, color: palette.muted),
              const SizedBox(width: 6),
              Text(
                'Шаблоны с {{name}}',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
              const Spacer(),
              Icon(Icons.add, size: 16, color: palette.accent),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            itemCount: snippets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final (title, body, badge) = snippets[i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.bgElevated.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Menlo',
                          color: palette.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Menlo',
                              color: palette.mutedBright,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            badge,
                            style:
                                TextStyle(fontSize: 10.5, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_vert, size: 16, color: palette.muted),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DemoTabChip extends StatelessWidget {
  const DemoTabChip({required this.label, required this.selected});
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? palette.accent : palette.muted,
        ),
      ),
    );
  }
}

class DemoSettingsWindow extends StatelessWidget {
  const DemoSettingsWindow();

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
              title: 'Вставка',
              subtitle: 'Поведение при выборе элемента',
              icon: Icons.keyboard_return,
              child: DemoSwitchRow(
                label: 'Авто-вставка',
                subtitle: '⌘V в предыдущее приложение',
                on: false,
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              title: 'Приватность',
              subtitle: 'Игнор, маскировка и шифрование',
              icon: Icons.shield_outlined,
              child: Column(
                children: [
                  DemoSwitchRow(
                    label: 'Маскировать secret',
                    subtitle: '•••• с раскрытием глазом',
                    on: true,
                  ),
                  const SizedBox(height: 8),
                  DemoSwitchRow(
                    label: 'Шифровать историю',
                    subtitle: 'AES-GCM + Keychain',
                    on: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              title: 'Цвета типов',
              subtitle: 'Полоска и бейдж по типу данных',
              icon: Icons.palette_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in [
                    ContentTypeKind.shell,
                    ContentTypeKind.secret,
                    ContentTypeKind.url,
                    ContentTypeKind.json,
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: ContentTypeColorDefaults.colors[kind],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          kind.badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Menlo',
                            color: palette.mutedBright,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              title: 'Справка',
              subtitle: 'Сниппеты, быстрый выбор, secret…',
              icon: Icons.menu_book_outlined,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.accent),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Открыть справку',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.accent,
                  ),
                ),
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
                  DemoInfo(label: 'Версия', value: '1.1.4'),
                  const SizedBox(height: 8),
                  DemoInfo(label: 'Номер сборки', value: '14'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoHelpWindow extends StatelessWidget {
  const DemoHelpWindow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const topics = [
      ('Сниппеты (шаблоны)', true),
      ('Избранное: pin, папки, теги', false),
      ('Secret и маскировка', false),
      ('Шифрование истории', false),
      ('Авто-вставка', false),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppPanel(
        title: 'help.md',
        actions: [
          Icon(Icons.arrow_back, size: 16, color: palette.muted),
          const SizedBox(width: 6),
          Icon(Icons.close, size: 16, color: palette.muted),
          const SizedBox(width: 4),
        ],
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'Кратко, как пользоваться CopyPastePlus.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 12),
            for (final (title, open) in topics) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: palette.bgElevated.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.code, size: 18, color: palette.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          Icon(
                            open
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: palette.muted,
                          ),
                        ],
                      ),
                    ),
                    if (open)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          'В теле шаблона — плейсхолдеры {{name}}, {{ticket}}. '
                          'При вставке откроется форма для подстановки значений.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: palette.ink.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DemoSwitchRow extends StatelessWidget {
  const DemoSwitchRow({
    required this.label,
    required this.subtitle,
    required this.on,
  });

  final String label;
  final String subtitle;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: palette.ink),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: on
                ? palette.accent.withValues(alpha: 0.55)
                : palette.line.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: palette.ink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class DemoInfo extends StatelessWidget {
  const DemoInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: palette.mutedBright),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Menlo',
            color: palette.accent,
          ),
        ),
      ],
    );
  }
}
