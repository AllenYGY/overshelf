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

capture_frame() {
  local scene="$1"
  local progress="$2"
  local name="$3"
  pkill -x OverShelf >/dev/null 2>&1 || true
  open -n "$APP_BUNDLE" --args \
    "--readme-demo-scene=$scene" \
    "--readme-demo-frame=$progress"
  sleep 0.7
  screencapture -x "$UNIQUE_DIR/$name.png"
  validate_capture "$UNIQUE_DIR/$name.png"
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

echo "Capturing clean full-progress scene frames..."
capture_frame clipboard 1 focus-clipboard
capture_frame files 1 focus-files
capture_frame notes 1 focus-notes
capture_frame todo 1 focus-todo
capture_frame overview 1 overview-full

# Normalize clean app captures to one canvas. Focus frames use a fixed
# quarter-width crop before fitting into the same neutral-padded output.
CANVAS_WIDTH=1100
CANVAS_HEIGHT=520
PANEL_TOP='trunc(ih*0.027)'
PANEL_HEIGHT='trunc(ih*0.47/2)*2'
normalize_frame() {
  local source="$1"
  local kind="$2"
  local output="$3"
  local crop_x='0'
  if [[ "$kind" == focus-* ]]; then
    case "$kind" in
      focus-clipboard) crop_x='0' ;;
      focus-files) crop_x='iw/4' ;;
      focus-notes) crop_x='iw/2' ;;
      focus-todo) crop_x='3*iw/4' ;;
    esac
    ffmpeg -hide_banner -loglevel error -y -i "$source" \
      -vf "crop=iw/4:$PANEL_HEIGHT:$crop_x:$PANEL_TOP,scale=$CANVAS_WIDTH:$CANVAS_HEIGHT:force_original_aspect_ratio=decrease:flags=lanczos,pad=$CANVAS_WIDTH:$CANVAS_HEIGHT:(ow-iw)/2:(oh-ih)/2:color=0x131518,format=rgb24" \
      "$output"
  else
    ffmpeg -hide_banner -loglevel error -y -i "$source" \
      -vf "crop=iw:$PANEL_HEIGHT:0:$PANEL_TOP,scale=$CANVAS_WIDTH:$CANVAS_HEIGHT:force_original_aspect_ratio=decrease:flags=lanczos,pad=$CANVAS_WIDTH:$CANVAS_HEIGHT:(ow-iw)/2:(oh-ih)/2:color=0x131518,format=rgb24" \
      "$output"
  fi
}

generate_neutral_frame() {
  local output="$1"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=0x131518:s=${CANVAS_WIDTH}x${CANVAS_HEIGHT}" \
    -frames:v 1 "$output"
}

generate_reveal_frame() {
  local progress="$1"
  local output="$2"
  local reveal_height
  reveal_height="$(awk -v height="$CANVAS_HEIGHT" -v progress="$progress" \
    'BEGIN { print int(height * progress / 2) * 2 }')"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=0x131518:s=${CANVAS_WIDTH}x${CANVAS_HEIGHT}" \
    -i "$UNIQUE_DIR/normalized-overview-full.png" \
    -filter_complex \
    "[1:v]crop=$CANVAS_WIDTH:$reveal_height:0:0[reveal];[0:v][reveal]overlay=0:0,format=rgb24" \
    -frames:v 1 "$output"
}

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

for spec in \
  'focus-clipboard focus-clipboard' \
  'focus-files focus-files' 'focus-notes focus-notes' 'focus-todo focus-todo' \
  'overview-full overview'; do
  read -r name kind <<< "$spec"
  normalize_frame "$UNIQUE_DIR/$name.png" "$kind" "$UNIQUE_DIR/normalized-$name.png"
done

# Hidden and partial reveal frames contain no screen pixels. They are rendered
# from the fixed neutral canvas and the validated full overview capture only.
generate_neutral_frame "$UNIQUE_DIR/normalized-hidden.png"
generate_reveal_frame 0.15 "$UNIQUE_DIR/normalized-open-15.png"
generate_reveal_frame 0.45 "$UNIQUE_DIR/normalized-open-45.png"
generate_reveal_frame 0.75 "$UNIQUE_DIR/normalized-open-75.png"
cp "$UNIQUE_DIR/normalized-overview-full.png" "$UNIQUE_DIR/normalized-open-full.png"
generate_reveal_frame 0.75 "$UNIQUE_DIR/normalized-close-75.png"
generate_reveal_frame 0.40 "$UNIQUE_DIR/normalized-close-40.png"
generate_reveal_frame 0.10 "$UNIQUE_DIR/normalized-close-10.png"

append_frame "$UNIQUE_DIR/normalized-hidden.png" 12
for name in open-15 open-45 open-75 open-full; do
  append_frame "$UNIQUE_DIR/normalized-$name.png" 2
done
for name in focus-clipboard focus-files focus-notes focus-todo; do
  append_frame "$UNIQUE_DIR/normalized-$name.png" 40
done
append_frame "$UNIQUE_DIR/normalized-overview-full.png" 48
for name in close-75 close-40 close-10; do
  append_frame "$UNIQUE_DIR/normalized-$name.png" 2
done
append_frame "$UNIQUE_DIR/normalized-hidden.png" 15

ACTUAL_FRAME_COUNT="$(find "$FRAMES_DIR" -type f -name 'frame-*.png' | wc -l | tr -d ' ')"
if [[ "$ACTUAL_FRAME_COUNT" -ne "$FRAME_INDEX" ]]; then
  echo "ERROR: assembled $ACTUAL_FRAME_COUNT of $FRAME_INDEX expected frames." >&2
  exit 1
fi
echo "Encoding $FRAME_INDEX README GIF frames..."
ffmpeg -hide_banner -loglevel error -y \
  -framerate 30 -i "$FRAMES_DIR/frame-%03d.png" \
  -filter_complex \
  "split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=sierra2_4a" \
  -loop 0 "$OUTPUT"

echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
