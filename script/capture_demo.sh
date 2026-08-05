#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/OverShelf.app"
OUTPUT="$ROOT_DIR/docs/screenshots/overshelf-reveal.gif"
TEMP_DIR="$(mktemp -d)"
UNIQUE_DIR="$TEMP_DIR/unique"
FRAMES_DIR="$TEMP_DIR/frames"
BACKDROP_BIN="$TEMP_DIR/demo-backdrop"
BACKDROP_PID=""

cleanup() {
  pkill -x OverShelf >/dev/null 2>&1 || true
  if [[ -n "$BACKDROP_PID" ]]; then
    kill "$BACKDROP_PID" >/dev/null 2>&1 || true
  fi
  rm -r "$TEMP_DIR"
}
trap cleanup EXIT

command -v ffmpeg >/dev/null || {
  echo "ERROR: ffmpeg is required. Install it with: brew install ffmpeg" >&2
  exit 1
}

"$ROOT_DIR/script/build_and_run.sh" build
xcrun swiftc "$ROOT_DIR/script/DemoBackdrop.swift" \
  -framework AppKit -o "$BACKDROP_BIN"
mkdir -p "$(dirname "$OUTPUT")"
mkdir -p "$UNIQUE_DIR" "$FRAMES_DIR"
pkill -x OverShelf >/dev/null 2>&1 || true
"$BACKDROP_BIN" &
BACKDROP_PID=$!
sleep 0.5

capture_progress() {
  local progress="$1"
  local name="$2"
  pkill -x OverShelf >/dev/null 2>&1 || true
  open -n "$APP_BUNDLE" --args "--readme-demo-frame=$progress"
  sleep 0.7
  screencapture -x "$UNIQUE_DIR/$name.png"
}

validate_capture() {
  local image="$1"
  local mean_luma
  mean_luma="$(
    ffmpeg -hide_banner -loglevel error -i "$image" \
      -vf "signalstats,metadata=print:file=-" -frames:v 1 -f null - \
      | awk -F= '$1 == "lavfi.signalstats.YAVG" { print $2; exit }'
  )"
  if [[ -z "$mean_luma" ]] || ! awk -v value="$mean_luma" 'BEGIN { exit !(value > 17) }'; then
    echo "ERROR: screen capture is blank. Unlock the Mac and confirm Screen Recording permission, then retry." >&2
    exit 1
  fi
}

echo "Capturing real reveal frames..."
capture_progress 0 hidden
validate_capture "$UNIQUE_DIR/hidden.png"
capture_progress 0.05 open-01
capture_progress 0.15 open-02
capture_progress 0.30 open-03
capture_progress 0.50 open-04
capture_progress 0.70 open-05
capture_progress 0.85 open-06
capture_progress 0.95 open-07
capture_progress 1 open-08
capture_progress 0.90 close-01
capture_progress 0.70 close-02
capture_progress 0.45 close-03
capture_progress 0.20 close-04
capture_progress 0.05 close-05

FRAME_INDEX=0
append_frame() {
  local source="$1"
  local repeats="$2"
  local output_name
  for ((i = 0; i < repeats; i++)); do
    output_name="$(printf 'frame-%03d.png' "$FRAME_INDEX")"
    cp "$source" "$FRAMES_DIR/$output_name"
    FRAME_INDEX=$((FRAME_INDEX + 1))
  done
}

append_frame "$UNIQUE_DIR/hidden.png" 12
for name in open-{01..08}; do append_frame "$UNIQUE_DIR/$name.png" 1; done
append_frame "$UNIQUE_DIR/open-08.png" 30
for name in close-{01..05}; do append_frame "$UNIQUE_DIR/$name.png" 1; done
append_frame "$UNIQUE_DIR/hidden.png" 15

echo "Encoding README GIF..."
ffmpeg -hide_banner -loglevel error -y \
  -framerate 30 -i "$FRAMES_DIR/frame-%03d.png" \
  -filter_complex \
  "crop=iw:trunc(ih*0.47/2)*2:0:trunc(ih*0.027),scale='min(1100,iw)':-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=sierra2_4a" \
  -loop 0 "$OUTPUT"

echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
