#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="ContainerDesktop"
BUNDLE_ID="com.shiguanghuxian.ContainerDesktop"
MIN_SYSTEM_VERSION="26.0"
TERMINAL_APP_NAME="Docker Compatibility Terminal"
TERMINAL_APP_EXECUTABLE="DockerCompatibilityTerminal"
TERMINAL_BUNDLE_ID="$BUNDLE_ID.DockerCompatibilityTerminal"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_APPLICATIONS="$APP_CONTENTS/Applications"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
TERMINAL_ICON_SOURCE="$ROOT_DIR/Resources/DockerCompatibilityTerminalIcon.icns"
TERMINAL_APP_BUNDLE="$APP_APPLICATIONS/$TERMINAL_APP_NAME.app"
TERMINAL_APP_CONTENTS="$TERMINAL_APP_BUNDLE/Contents"
TERMINAL_APP_MACOS="$TERMINAL_APP_CONTENTS/MacOS"
TERMINAL_APP_RESOURCES="$TERMINAL_APP_CONTENTS/Resources"
TERMINAL_APP_BINARY="$TERMINAL_APP_MACOS/$TERMINAL_APP_EXECUTABLE"
TERMINAL_INFO_PLIST="$TERMINAL_APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$TERMINAL_APP_EXECUTABLE" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"
mkdir -p "$APP_APPLICATIONS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>在 Docker 兼容终端中打开</string>
      </dict>
      <key>NSMessage</key>
      <string>openDockerCompatibilityTerminal</string>
      <key>NSPortName</key>
      <string>$APP_NAME</string>
      <key>NSSendTypes</key>
      <array>
        <string>NSFilenamesPboardType</string>
        <string>public.file-url</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

mkdir -p "$TERMINAL_APP_MACOS"
mkdir -p "$TERMINAL_APP_RESOURCES"
cp "$BUILD_BINARY" "$TERMINAL_APP_BINARY"
chmod +x "$TERMINAL_APP_BINARY"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$TERMINAL_APP_RESOURCES/AppIcon.icns"
fi
if [[ -f "$TERMINAL_ICON_SOURCE" ]]; then
  cp "$TERMINAL_ICON_SOURCE" "$TERMINAL_APP_RESOURCES/DockerCompatibilityTerminalIcon.icns"
elif [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$TERMINAL_APP_RESOURCES/DockerCompatibilityTerminalIcon.icns"
fi

cat >"$TERMINAL_INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$TERMINAL_APP_EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>$TERMINAL_BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$TERMINAL_APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Docker 兼容终端</string>
  <key>CFBundleIconFile</key>
  <string>DockerCompatibilityTerminalIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
