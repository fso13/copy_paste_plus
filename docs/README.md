# Documentation

Visual overview and usage notes for **CopyPastePlus**.

## Screenshots

### History

![History window](screenshots/main-history.png)

Clipboard history with search, tabs, and favorites.

### Favorites

![Favorites window](screenshots/favorites.png)

Starred items on the Избранное tab.

### Settings

![Settings window](screenshots/settings.png)

Theme, updates, hotkeys, and About panel.

### App icon

<p align="center">
  <img src="screenshots/app-icon.png" alt="CopyPastePlus icon" width="128" />
</p>

## Quick usage

| Action | How |
| --- | --- |
| Show / hide window | `⌘⇧C` or click the menu-bar icon |
| Copy item | Click a row |
| Favorite | Click the star |
| Item menu | Long-press a row |
| Settings | Gear icon in the title bar |
| Quit | Menu-bar icon → Выход |

## Regenerating screenshots

Optional Flutter helper (widget capture):

```bash
flutter test test/docs_screenshot_test.dart
```

Or replace PNGs in `docs/screenshots/` with fresh captures from a running build.

## Related

- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md)
- [CHANGELOG.md](../CHANGELOG.md)
- [README.md](../README.md)
