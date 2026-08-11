# Contributing to CopyPastePlus

Thanks for contributing! This guide covers how to set up the project and submit changes.

## Development setup

### Requirements

- macOS
- [Flutter](https://docs.flutter.dev/get-started/install/macos) (stable)
- Xcode + Command Line Tools
- CocoaPods (`brew install cocoapods`)
- Optional for fancy DMG locally: `brew install create-dmg`

### Run

```bash
git clone https://github.com/fso13/copy_paste_plus.git
cd copy_paste_plus
flutter pub get
flutter run -d macos
```

Hotkey to show the window: `⌘⇧C` (or click the menu-bar icon).

### Build

```bash
flutter build macos --release
./scripts/create_dmg.sh --build
```

## Branching & commits

1. Create a branch from `main`: `feature/…`, `fix/…`, or `docs/…`
2. Keep commits focused and descriptive
3. Update [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]` when the change is user-facing
4. Open a Pull Request using the template

## Code style

- Follow `analysis_options.yaml` / `flutter_lints`
- Prefer small, readable widgets and services over large files
- Match existing Dracula-inspired UI tokens in `lib/theme/`
- Do not commit secrets, local DMGs, or build artifacts

```bash
flutter analyze
flutter test
```

## Pull requests

- Describe **what** changed and **why**
- Attach screenshots for UI changes (`docs/screenshots/` style)
- Link related issues
- Ensure CI (macOS DMG workflow) is not broken by your changes when possible

## Reporting bugs / ideas

Use GitHub Issues:

- **Bug report** — unexpected behavior
- **Feature request** — new capability

Please search existing issues first.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
