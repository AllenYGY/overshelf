#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DropShelf"
BUNDLE_ID="com.dropshelf.app"
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
   -O \
   -o "$DIST_DIR/$APP_NAME" \
    DropShelf/App/*.swift \
    DropShelf/Models/*.swift \
    DropShelf/Services/*.swift \
    DropShelf/Views/*.swift \
    DropShelf/Views/Shared/*.swift \
    DropShelf/Window/*.swift
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
  cp "$ROOT_DIR/DropShelf/Resources/AppIcon.icns" "$STAGE_RESOURCES/" 2>/dev/null || true

  # Copy Info.plist from source, expanding build variables
  sed \
    -e 's/$(EXECUTABLE_NAME)/'"$APP_NAME"'/g' \
    -e 's/$(PRODUCT_NAME)/'"$APP_NAME"'/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/'"$BUNDLE_ID"'/g' \
    -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
    "$ROOT_DIR/DropShelf/Info.plist" > "$STAGE_CONTENTS/Info.plist"

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
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
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
    /usr/bin/log stream --info --style compact --predicate 'process == "DropShelf"'
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
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
