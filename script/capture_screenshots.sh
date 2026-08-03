#!/usr/bin/env bash
# Capture usage screenshots for DropShelf docs.
#
# Prereqs:
#   - macOS 14+, Xcode Command Line Tools
#   - Screen Recording permission granted to the terminal you run this in
#     (System Settings > Privacy & Security > Screen Recording)
#   - Accessibility permission granted to DropShelf (for hotkey/edge tracking)
#
# Usage:
#   ./script/capture_screenshots.sh          # build + launch + capture all
#   ./script/capture_screenshots.sh --no-build   # skip rebuild, use existing app
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/DropShelf.app"
OUT_DIR="$ROOT_DIR/docs/screenshots"
DO_BUILD=1

[[ "${1:-}" == "--no-build" ]] && DO_BUILD=0

mkdir -p "$OUT_DIR"

if [[ $DO_BUILD -eq 1 ]]; then
  echo "Building DropShelf..."
  "$ROOT_DIR/script/build_and_run.sh" build
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "ERROR: $APP_BUNDLE not found. Run without --no-build first." >&2
  exit 1
fi

# Quit any running instance, then launch fresh.
pkill -x DropShelf 2>/dev/null || true
sleep 1
open -n "$APP_BUNDLE"
echo "Waiting for DropShelf to start..."
sleep 3

toggle_panel() {
  osascript <<'OSA'
tell application "System Events"
  tell process "DropShelf"
    click menu bar item 1 of menu bar 2
    delay 0.4
    click menu item "Show/Hide DropShelf" of menu 1 of menu bar item 1 of menu bar 2
  end tell
end tell
OSA
}

capture_top() {
  local out="$1"
  # Capture the top 480pt strip of the main screen where the panel slides down.
  local geo
  geo="$(osascript -e 'tell application "Finder" to bounds of window of desktop')"
  local w h
  w="$(cut -d, -f3 <<<"$geo" | tr -d ' ')"
  h="$(cut -d, -f4 <<<"$geo" | tr -d ' ')"
  local strip=480
  [[ $h -lt $strip ]] && strip=$h
  screencapture -R 0,0,$w,$strip -x "$out"
}

hide_panel() {
  osascript <<'OSA' 2>/dev/null || true
tell application "System Events"
  tell process "DropShelf"
    click menu bar item 1 of menu bar 2
    delay 0.3
    click menu item "Show/Hide DropShelf" of menu 1 of menu bar item 1 of menu bar 2
  end tell
end tell
OSA
  sleep 1
}

echo "Capturing: all panels visible"
toggle_panel
sleep 2
capture_top "$OUT_DIR/panel-all.png"
hide_panel

echo "Capturing: menu bar"
osascript <<'OSA'
tell application "System Events"
  tell process "DropShelf"
    click menu bar item 1 of menu bar 2
  end tell
end tell
OSA
sleep 1
screencapture -x "$OUT_DIR/menu-bar.png"
osascript -e 'tell application "System Events" to key code 53'  # Esc to close menu
sleep 1

echo "Capturing: settings (Preferences)"
osascript <<'OSA'
tell application "System Events"
  tell process "DropShelf"
    click menu bar item 1 of menu bar 2
    delay 0.4
    click menu item "Preferences…" of menu 1 of menu bar item 1 of menu bar 2
  end tell
end tell
OSA
sleep 2
screencapture -x "$OUT_DIR/settings-general.png"

echo "Capturing: clipboard panel"
toggle_panel
sleep 2
capture_top "$OUT_DIR/panel-clipboard.png"
hide_panel

echo "Capturing: files panel"
toggle_panel
sleep 2
capture_top "$OUT_DIR/panel-files.png"
hide_panel

echo "Capturing: notes panel"
toggle_panel
sleep 2
capture_top "$OUT_DIR/panel-notes.png"
hide_panel

# Done. Leave the app running or quit it.
pkill -x DropShelf 2>/dev/null || true

echo ""
echo "Screenshots written to $OUT_DIR:"
ls -1 "$OUT_DIR"/*.png 2>/dev/null || echo "(none — check Screen Recording permission)"
