#!/usr/bin/env bash
# Optional codesign + notarization for Release .app / DMG.
#
# Required env (Developer ID):
#   APPLE_TEAM_ID
#   CODESIGN_IDENTITY   e.g. "Developer ID Application: Name (TEAMID)"
# Optional notarization:
#   APPLE_ID
#   APPLE_APP_SPECIFIC_PASSWORD
#   NOTARIZE=1
#
# Usage:
#   ./scripts/codesign_and_notarize.sh path/to/CopyPastePlus.app
#   ./scripts/codesign_and_notarize.sh path/to/CopyPastePlus-1.1.0.10.dmg
set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" || ! -e "$TARGET" ]]; then
  echo "Usage: $0 <App.app|file.dmg>" >&2
  exit 1
fi

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  echo "CODESIGN_IDENTITY is not set — skipping codesign." >&2
  exit 0
fi

echo "→ Codesigning $TARGET with $CODESIGN_IDENTITY"
if [[ "$TARGET" == *.app ]]; then
  codesign --force --deep --options runtime \
    --sign "$CODESIGN_IDENTITY" \
    "$TARGET"
  codesign --verify --deep --strict --verbose=2 "$TARGET"
elif [[ "$TARGET" == *.dmg ]]; then
  codesign --force --sign "$CODESIGN_IDENTITY" "$TARGET"
  codesign --verify --verbose=2 "$TARGET"
else
  echo "Unsupported target type" >&2
  exit 1
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "NOTARIZE=1 but APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD / APPLE_TEAM_ID missing" >&2
    exit 1
  fi
  echo "→ Submitting for notarization..."
  xcrun notarytool submit "$TARGET" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
  if [[ "$TARGET" == *.dmg || "$TARGET" == *.app ]]; then
    xcrun stapler staple "$TARGET" || true
  fi
  echo "✓ Notarization complete"
fi

echo "✓ Done"
