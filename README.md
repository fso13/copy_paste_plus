# CopyPastePlus

Менеджер буфера обмена для macOS: история копирований, избранное, глобальный хоткей и трей.

## Возможности

- История скопированного текста с быстрым поиском
- Избранное (звёздочка)
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

## Стек

Flutter (macOS), `window_manager`, `system_tray`, `hotkey_manager`, `shared_preferences`, `package_info_plus`.

## Лицензия

Private / personal project unless stated otherwise.
