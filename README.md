# CopyPastePlus

[![CI — macOS DMG](https://github.com/fso13/copy_paste_plus/actions/workflows/build-dmg.yml/badge.svg)](https://github.com/fso13/copy_paste_plus/actions/workflows/build-dmg.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/fso13/copy_paste_plus?include_prereleases)](https://github.com/fso13/copy_paste_plus/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)](https://github.com/fso13/copy_paste_plus)

<p align="center">
  <img src="docs/screenshots/app-icon.png" alt="CopyPastePlus" width="120" />
</p>

Менеджер буфера обмена для macOS: история копирований, избранное, глобальный хоткей и трей.

🌐 [Сайт (GitHub Pages)](https://fso13.github.io/copy_paste_plus/)

## Возможности

- История скопированного текста с быстрым поиском
- Сохранение стилей (HTML/RTF): подсветка из IDE при вставке в Word и др.; в plain-text — только текст
- Избранное (звёздочка) с произвольными комментариями
- Глобальный хоткей (по умолчанию `⌘⇧C`)
- Иконка в меню-баре
- Темы: системная / светлая / тёмная (Dracula-inspired)
- Проверка обновлений через GitHub Releases
- Пасхалка 🦇 (кликните 13 раз по блоку «О приложении»)

## Установка

1. Скачайте `.dmg` из [Releases](https://github.com/fso13/copy_paste_plus/releases/latest)
2. Откройте DMG и перетащите **CopyPastePlus** в **Applications**
3. При первом запуске macOS может попросить разрешить приложение в **Системные настройки → Конфиденциальность**

> Если репозиторий другой — поправьте ссылки и константы `githubOwner` / `githubRepo` в `lib/utils/constants.dart`.

## Сборка локально

```bash
# Debug
flutter pub get
flutter run -d macos

# Release .app
flutter build macos --release

# DMG-установщик
./scripts/create_dmg.sh --build
```

Готовый файл: `dist/CopyPastePlus-<version>.<build>.dmg`

## CI / Releases

Workflow [`.github/workflows/build-dmg.yml`](.github/workflows/build-dmg.yml):

- при пуше тега `v*` (например `v1.0.1`) собирает macOS app + DMG и публикует GitHub Release с вложением
- при публикации Release вручную докладывает DMG в релиз
- можно запустить вручную через **Actions → Build macOS DMG → Run workflow**

Пример релиза:

```bash
# обновите version в pubspec.yaml, затем:
git tag v1.0.1
git push origin v1.0.1
```

## Настройки обновлений

В **Настройки → Обновления**:

| Режим | Поведение |
| --- | --- |
| Выключено | Не проверять GitHub |
| Уведомлять | Раз в 12 часов спрашивать, если есть новый релиз |
| Автоматически | При новой версии сразу открывать скачивание DMG |

Также есть кнопка **Проверить сейчас**.

## Документация

Сайт: [fso13.github.io/copy_paste_plus](https://fso13.github.io/copy_paste_plus/)  
Подробнее: [docs/README.md](docs/README.md)

### Скриншоты

#### История буфера

Окно истории: поиск, вкладки «История» / «Избранное», список скопированных фрагментов.

<p align="center">
  <img src="docs/screenshots/main-history.png" alt="История буфера обмена" width="360" />
</p>

#### Избранное

Закладки со звёздочкой — быстрый доступ к нужным фрагментам.

<p align="center">
  <img src="docs/screenshots/favorites.png" alt="Избранное" width="360" />
</p>

#### Настройки

Тема (система / светлая / тёмная), обновления, горячие клавиши и сведения о версии.

<p align="center">
  <img src="docs/screenshots/settings.png" alt="Настройки" width="360" />
</p>

### Быстрые действия

| Действие | Как |
| --- | --- |
| Показать / скрыть окно | `⌘⇧C` или иконка в меню-баре |
| Вставить из истории | Клик по элементу |
| В избранное | Клик по ★ |
| Комментарий к избранному | ⋮ → «Добавить комментарий» |
| Меню элемента | ⋮ или долгое нажатие |
| Настройки | Иконка ⚙ в заголовке |
| Выход | Меню трея → Выход |

### Ссылки

- [CHANGELOG.md](CHANGELOG.md) — история изменений
- [CONTRIBUTING.md](CONTRIBUTING.md) — как контрибьютить
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — кодекс поведения
- [LICENSE](LICENSE) — MIT

## Стек

Flutter (macOS, 3.44 / Dart 3.12), `window_manager`, `system_tray`, `hotkey_manager`, `shared_preferences`, `package_info_plus`.

## Лицензия

[MIT](LICENSE) © Dmitry Rudenko
