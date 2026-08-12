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
- Клавиатурная навигация: `↑`/`↓`, `Enter`, быстрый выбор `1`–`9`
- Опциональная авто-вставка в предыдущее приложение (нужен Универсальный доступ)
- Реальный автозапуск при старте системы (Login Items / `SMAppService`)
- Игнор приложений и маскировка `secret` (в т.ч. ручная метка в меню ⋮)
- Сниппеты с плейсхолдерами `{{name}}`
- Трансформации текста (JSON, Base64, slug, …)
- Картинки / скриншоты в истории
- Опциональное шифрование истории (AES-GCM + Keychain)
- Цвета типов данных (настраиваются в настройках)
- Встроенная справка в настройках
- Глобальный хоткей (по умолчанию `⌘⇧C`)
- Иконка в меню-баре с меню по правому клику (Показать / Настройки / Завершить)
- Темы: системная / светлая / тёмная (Dracula-inspired)
- Проверка обновлений через GitHub Releases
- Пасхалка 🦇 (кликните 13 раз по блоку «О приложении»)

## Установка

1. Скачайте `.dmg` из [Releases](https://github.com/fso13/copy_paste_plus/releases/latest)
2. Откройте DMG и либо перетащите **CopyPastePlus** в **Applications**, либо дважды кликните **Install.command** (закроет старую копию и установит новую)
3. При первом запуске macOS может попросить разрешить приложение в **Системные настройки → Конфиденциальность**
4. Для авто-вставки дополнительно включите **Универсальный доступ** для CopyPastePlus

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

- при пуше тега `v*` (например `v1.0.8`) собирает macOS app + DMG и публикует GitHub Release с вложением
- при публикации Release вручную докладывает DMG в релиз
- можно запустить вручную через **Actions → Build macOS DMG → Run workflow**

Пример релиза:

```bash
# обновите version в pubspec.yaml, затем:
git tag v1.1.0
git push origin v1.1.0
```

## Codesign / Notarize (опционально)

Для Gatekeeper без предупреждений нужны Apple Developer ID и секреты CI:

| Secret | Назначение |
| --- | --- |
| `CODESIGN_IDENTITY` | `Developer ID Application: Name (TEAMID)` |
| `APPLE_TEAM_ID` | Team ID |
| `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` | notarize |
| `NOTARIZE` | `1` чтобы включить notarization |

Локально: `./scripts/create_dmg.sh --build` при установленных env. Подробнее: [docs/README.md](docs/README.md).

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

Окно истории: поиск, вкладки «История» / «Избранное» / «Сниппеты», список фрагментов (в т.ч. masked secret).

<p align="center">
  <img src="docs/screenshots/main-history.png" alt="История буфера обмена" width="360" />
</p>

#### Избранное

Закладки со звёздочкой и комментариями — быстрый доступ к нужным фрагментам.

<p align="center">
  <img src="docs/screenshots/favorites.png" alt="Избранное" width="360" />
</p>

#### Сниппеты

Шаблоны с плейсхолдерами `{{name}}` — подстановка значений перед вставкой.

<p align="center">
  <img src="docs/screenshots/snippets.png" alt="Сниппеты" width="360" />
</p>

#### Настройки

Вставка, приватность, цвета типов, справка, тема и обновления.

<p align="center">
  <img src="docs/screenshots/settings.png" alt="Настройки" width="360" />
</p>

#### Справка

Встроенная документация: сниппеты, быстрый выбор, secret, шифрование и др.

<p align="center">
  <img src="docs/screenshots/help.png" alt="Справка" width="360" />
</p>

### Быстрые действия

| Действие | Как |
| --- | --- |
| Показать / скрыть окно | `⌘⇧C` или иконка в меню-баре |
| Вставить из истории | Клик / `Enter` (или `1`–`9`) |
| Навигация по списку | `↑` / `↓` |
| В избранное | Клик по ★ |
| Комментарий к избранному | ⋮ → «Добавить комментарий» |
| Тип secret | ⋮ → «Сделать типом secret» |
| Преобразовать текст | ⋮ → «Преобразовать…» |
| Сниппет | вкладка «Сниппеты» |
| Справка | Настройки → Справка |
| Цвета типов | Настройки → Цвета типов |
| Меню элемента | ⋮ или долгое нажатие |
| Настройки | Иконка ⚙ в заголовке или трей → Настройки |
| Выход | Трей → Завершить / Настройки → Завершить работу |

### Ссылки

- [CHANGELOG.md](CHANGELOG.md) — история изменений
- [CONTRIBUTING.md](CONTRIBUTING.md) — как контрибьютить
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — кодекс поведения
- [LICENSE](LICENSE) — MIT

## Стек

Flutter (macOS, 3.44 / Dart 3.12), `window_manager`, `system_tray`, `hotkey_manager`, `shared_preferences`, `package_info_plus`.

## Лицензия

[MIT](LICENSE) © Dmitry Rudenko
