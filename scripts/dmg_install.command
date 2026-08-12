#!/bin/bash
# Install CopyPastePlus into /Applications, quitting the running app first.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${DIR}/CopyPastePlus.app"
DEST="/Applications/CopyPastePlus.app"

if [[ ! -d "$SRC" ]]; then
  osascript -e 'display alert "CopyPastePlus" message "Рядом со скриптом нет CopyPastePlus.app"'
  exit 1
fi

# Quit running instance so Finder/cp can replace the bundle.
osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  if (name of processes) contains "CopyPastePlus" then
    tell application "CopyPastePlus" to quit
    delay 1.5
  end if
end tell
APPLESCRIPT

# Force-quit if still hanging (menu-bar apps sometimes linger).
pkill -x "CopyPastePlus" >/dev/null 2>&1 || true
sleep 0.4

rm -rf "$DEST"
cp -R "$SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" >/dev/null 2>&1 || true
open "$DEST"

osascript -e 'display notification "Установлено в Программы" with title "CopyPastePlus"'
