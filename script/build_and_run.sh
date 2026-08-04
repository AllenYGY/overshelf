#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OverShelf"
BUNDLE_ID="com.overshelf.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PKGINFO="$APP_CONTENTS/PkgInfo"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

PATCHED_SWIFT="/private/tmp/swift-patched"
CLANG_MODULE_CACHE="/private/tmp/clang-module-cache"

# Ensure patched Swift stdlib exists (patches 6.3.2 -> 6.3.3 to match installed compiler)
ensure_patched_swift() {
  if [ ! -d "$PATCHED_SWIFT/Swift.swiftmodule" ]; then
    echo "Preparing patched Swift stdlib cache..."
    rm -rf "$PATCHED_SWIFT"
    cp -R "$SDK_PATH/usr/lib/swift" "$PATCHED_SWIFT"
    find "$PATCHED_SWIFT" -name "*.swiftinterface" -exec sed -i '' 's/Apple Swift version 6\\.3\\.2/Apple Swift version 6.3.3/g' {} \;
  fi
  mkdir -p "$CLANG_MODULE_CACHE"
}

kill_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

compile_test() {
  local output="$1"
  shift
  local errlog
  errlog="$(mktemp)"
  for attempt in 1 2 3; do
    if swiftc "$@" -o "$output" 2>"$errlog"; then
      rm -f "$errlog"
      return 0
    fi
    if grep -q "modified during the build" "$errlog"; then
      echo "Retrying swiftc compile (attempt $attempt) after transient source-file check..."
      sleep 1
      continue
    fi
    cat "$errlog" >&2
    rm -f "$errlog"
    return 1
  done
  cat "$errlog" >&2
  rm -f "$errlog"
  return 1
}

build_app() {
  mkdir -p "$DIST_DIR"
  echo "Building $APP_NAME..."
  ensure_patched_swift
  cd "$ROOT_DIR"
  swiftc \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK_PATH" \
    -I "$PATCHED_SWIFT" \
    -L "$PATCHED_SWIFT" \
    -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
    -swift-version 5 \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -framework WebKit \
   -O \
   -o "$DIST_DIR/$APP_NAME" \
    OverShelf/App/*.swift \
    OverShelf/Models/*.swift \
    OverShelf/Services/*.swift \
    OverShelf/Views/*.swift \
    OverShelf/Views/Shared/*.swift \
    OverShelf/Window/*.swift
}

stage_bundle() {
  echo "Staging .app bundle..."
  kill_app
  # Build in a fresh temp dir to avoid stale xattr from previous builds
  STAGE_DIR="$(mktemp -d)"
  STAGE_BUNDLE="$STAGE_DIR/$APP_NAME.app"
  STAGE_CONTENTS="$STAGE_BUNDLE/Contents"
  STAGE_MACOS="$STAGE_CONTENTS/MacOS"
  STAGE_RESOURCES="$STAGE_CONTENTS/Resources"
  mkdir -p "$STAGE_MACOS" "$STAGE_RESOURCES"
  cp "$DIST_DIR/$APP_NAME" "$STAGE_MACOS/$APP_NAME"
  chmod +x "$STAGE_MACOS/$APP_NAME"
  cp "$ROOT_DIR/OverShelf/Resources/AppIcon.icns" "$STAGE_RESOURCES/" || { echo "ERROR: AppIcon.icns copy failed" >&2; exit 1; }
  # Guard against the silent 0-byte icon failure mode.
  [ -s "$STAGE_RESOURCES/AppIcon.icns" ] || { echo "ERROR: AppIcon.icns is empty after copy" >&2; exit 1; }
  cp -R "$ROOT_DIR/OverShelf/Resources/Markdown" "$STAGE_RESOURCES/" 2>/dev/null || true

  # Copy Info.plist from source, expanding build variables
  sed \
    -e 's/$(EXECUTABLE_NAME)/'"$APP_NAME"'/g' \
    -e 's/$(PRODUCT_NAME)/'"$APP_NAME"'/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/'"$BUNDLE_ID"'/g' \
    -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
    "$ROOT_DIR/OverShelf/Info.plist" > "$STAGE_CONTENTS/Info.plist"

  printf 'APPL????' > "$STAGE_CONTENTS/PkgInfo"

  # Clear extended attributes that break code signing
  xattr -cr "$STAGE_BUNDLE"
  dot_clean "$STAGE_BUNDLE" 2>/dev/null || true

  # Ad-hoc sign
  echo "Signing..."
  codesign -s - --force "$STAGE_BUNDLE"

  # Replace the dist bundle with the fresh one
  mkdir -p "$DIST_DIR"
  rm -r "$APP_BUNDLE" 2>/dev/null || true
  mv "$STAGE_BUNDLE" "$APP_BUNDLE"
  # The sandbox/filesystem may add provenance xattrs after move; keep the bundle clean.
  xattr -cr "$APP_BUNDLE" 2>/dev/null || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build)
    build_app
    stage_bundle
    echo "Built and staged $APP_BUNDLE"
    ;;
  run)
    build_app
    stage_bundle
    echo "Launching $APP_NAME..."
    open_app
    ;;
  --debug|debug)
    build_app
    stage_bundle
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_app
    stage_bundle
    open_app
    sleep 2
    /usr/bin/log stream --info --style compact --predicate 'process == "OverShelf"'
    ;;
  --telemetry|telemetry)
    build_app
    stage_bundle
    open_app
    sleep 2
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_app
    stage_bundle
    open_app
    sleep 2
    if pgrep -x "$APP_NAME" >/dev/null; then
      echo "VERIFY: OK — $APP_NAME is running"
      kill_app
    else
      echo "VERIFY: FAIL — $APP_NAME not running"
      exit 1
    fi
    ;;
  test)
    build_app
    stage_bundle
    echo "Running migration test..."
    compile_test "$DIST_DIR/MigrationTests" \
      -target arm64-apple-macosx14.0 \
      -sdk "$SDK_PATH" \
      -I "$PATCHED_SWIFT" \
      -L "$PATCHED_SWIFT" \
      -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
      -swift-version 5 \
      -framework Cocoa \
      -framework SwiftUI \
      -framework Carbon \
      -framework WebKit \
      OverShelf/Models/AppSettings.swift \
      OverShelf/Services/PersistenceManager.swift \
      Tests/MigrationTests/main.swift
    "$DIST_DIR/MigrationTests"
    echo "Running app services test..."
    compile_test "$DIST_DIR/AppServicesTests" \
      -target arm64-apple-macosx14.0 \
      -sdk "$SDK_PATH" \
      -I "$PATCHED_SWIFT" \
      -L "$PATCHED_SWIFT" \
      -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
      -swift-version 5 \
      -framework Cocoa \
      -framework SwiftUI \
      -framework Carbon \
      -framework WebKit \
      OverShelf/Models/AppSettings.swift \
      OverShelf/Models/ClipboardItem.swift \
      OverShelf/Models/Note.swift \
      OverShelf/Models/StagedFile.swift \
      OverShelf/Models/TodoItem.swift \
      OverShelf/Services/PersistenceManager.swift \
      OverShelf/Services/NotesManager.swift \
      OverShelf/Services/TodoManager.swift \
      OverShelf/Services/FileStagingManager.swift \
      OverShelf/Services/ClipboardMonitor.swift \
      Tests/AppServicesTests/main.swift
    "$DIST_DIR/AppServicesTests"
    echo "Running top edge tracker test..."
    compile_test "$DIST_DIR/TopEdgeTrackerTests" \
      -target arm64-apple-macosx14.0 \
      -sdk "$SDK_PATH" \
      -I "$PATCHED_SWIFT" \
      -L "$PATCHED_SWIFT" \
      -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
      -swift-version 5 \
      -framework Cocoa \
      -framework SwiftUI \
      OverShelf/Window/TopEdgeTracker.swift \
      Tests/TopEdgeTrackerTests/main.swift
    "$DIST_DIR/TopEdgeTrackerTests"
    echo "Running panel frame test..."
    compile_test "$DIST_DIR/PanelFrameTests" \
      -target arm64-apple-macosx14.0 \
      -sdk "$SDK_PATH" \
      -I "$PATCHED_SWIFT" \
      -L "$PATCHED_SWIFT" \
      -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
      -swift-version 5 \
      -framework CoreGraphics \
      OverShelf/Window/PanelFrame.swift \
      Tests/PanelFrameTests/main.swift
    "$DIST_DIR/PanelFrameTests"
    echo "Running markdown preview test..."
    compile_test "$DIST_DIR/MarkdownPreviewTests" \
      -target arm64-apple-macosx14.0 \
      -sdk "$SDK_PATH" \
      -I "$PATCHED_SWIFT" \
      -L "$PATCHED_SWIFT" \
      -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
      -swift-version 5 \
      -framework Cocoa \
      -framework WebKit \
      Tests/MarkdownPreviewTests/main.swift
    DROPSHELF_MARKDOWN_DIR="$APP_RESOURCES/Markdown" "$DIST_DIR/MarkdownPreviewTests"
    echo "Running app bundle test..."
    compile_test "$DIST_DIR/AppBundleTests" \
      -target arm64-apple-macosx14.0 \
      -sdk "$SDK_PATH" \
      -I "$PATCHED_SWIFT" \
      -L "$PATCHED_SWIFT" \
      -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
      -swift-version 5 \
      -framework Foundation \
      Tests/AppBundleTests/main.swift
    DROPSHELF_APP_BUNDLE="$APP_BUNDLE" "$DIST_DIR/AppBundleTests"
    echo "Running app launch check..."
    open_app
    sleep 2
    if pgrep -x "$APP_NAME" >/dev/null; then
      echo "App launch check passed"
      kill_app
    else
      echo "App launch check FAIL: $APP_NAME not running"
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify|test]" >&2
    exit 2
    ;;
esac
