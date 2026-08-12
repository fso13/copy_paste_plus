#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export PATH="${FLUTTER_PATH:-$HOME/Documents/Личное/flutter/bin}:/opt/homebrew/bin:$PATH"

APP_NAME="CopyPastePlus"
BUNDLE_NAME="CopyPastePlus.app"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)"
BUILD_NUMBER="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f2)"
DMG_NAME="${APP_NAME}-${VERSION}.${BUILD_NUMBER}.dmg"

APP_PATH="build/macos/Build/Products/Release/${BUNDLE_NAME}"
DIST_DIR="dist"
STAGING_DIR="${DIST_DIR}/dmg_staging"

DO_BUILD=false
CI_MODE=false

for arg in "$@"; do
  case "$arg" in
    --build) DO_BUILD=true ;;
    --ci) CI_MODE=true ;;
  esac
done

if [[ "${CI:-}" == "true" ]]; then
  CI_MODE=true
fi

if [[ "$DO_BUILD" == "true" ]] || [[ ! -d "$APP_PATH" ]]; then
  echo "→ Building macOS release..."
  flutter build macos --release
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app not found at $APP_PATH" >&2
  exit 1
fi

echo "→ Preparing DMG staging..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  chmod +x scripts/codesign_and_notarize.sh
  echo "→ Codesigning Release .app..."
  ./scripts/codesign_and_notarize.sh "$APP_PATH"
fi

cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -sf /Applications "$STAGING_DIR/Applications"

# Helper that quits the running app, then copies into /Applications.
INSTALL_SCRIPT="$STAGING_DIR/Install.command"
cp "$ROOT_DIR/scripts/dmg_install.command" "$INSTALL_SCRIPT"
chmod +x "$INSTALL_SCRIPT"

mkdir -p "$DIST_DIR"
rm -f "${DIST_DIR}/${DMG_NAME}"

if [[ "$CI_MODE" == "true" ]] || ! command -v create-dmg >/dev/null 2>&1; then
  echo "→ Creating ${DMG_NAME} with hdiutil (CI/simple)..."
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"
else
  echo "→ Creating ${DMG_NAME} with create-dmg..."
  create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 660 460 \
    --icon-size 112 \
    --icon "${APP_NAME}.app" 160 140 \
    --hide-extension "${APP_NAME}.app" \
    --icon "Install.command" 160 320 \
    --app-drop-link 480 140 \
    --no-internet-enable \
    "${DIST_DIR}/${DMG_NAME}" \
    "$STAGING_DIR"
fi

rm -rf "$STAGING_DIR"

echo "✓ DMG ready: ${DIST_DIR}/${DMG_NAME}"
ls -lh "${DIST_DIR}/${DMG_NAME}"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  chmod +x scripts/codesign_and_notarize.sh
  ./scripts/codesign_and_notarize.sh "${DIST_DIR}/${DMG_NAME}" || true
fi

# Emit path for CI consumers
echo "DMG_PATH=${DIST_DIR}/${DMG_NAME}"
