#!/usr/bin/env bash

release_log() {
  printf "\033[1;34m==>\033[0m %s\n" "$*"
}

release_warn() {
  printf "\033[1;33mwarning:\033[0m %s\n" "$*" >&2
}

release_error() {
  printf "\033[1;31merror:\033[0m %s\n" "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || release_error "缺少命令：$1"
}

require_xcrun_tool() {
  xcrun --find "$1" >/dev/null 2>&1 || release_error "缺少 Xcode 命令行工具：$1"
}

create_macos_app_bundle() {
  local app_name="$1"
  local bundle_id="$2"
  local app_version="$3"
  local build_number="$4"
  local minimum_system_version="$5"
  local source_binary="$6"
  local icon_source="$7"
  local app_bundle="$8"

  local app_contents="$app_bundle/Contents"
  local app_macos="$app_contents/MacOS"
  local app_resources="$app_contents/Resources"
  local app_binary="$app_macos/$app_name"
  local info_plist="$app_contents/Info.plist"

  [[ -x "$source_binary" ]] || release_error "Release 可执行文件不存在或不可执行：$source_binary"

  rm -rf "$app_bundle"
  mkdir -p "$app_macos" "$app_resources"

  cp "$source_binary" "$app_binary"
  chmod 755 "$app_binary"

  if [[ -f "$icon_source" ]]; then
    cp "$icon_source" "$app_resources/AppIcon.icns"
  else
    release_warn "未找到图标文件：$icon_source"
  fi

  cat >"$info_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$app_name</string>
  <key>CFBundleExecutable</key>
  <string>$app_name</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$app_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$app_version</string>
  <key>CFBundleVersion</key>
  <string>$build_number</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$minimum_system_version</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST
}

create_docker_compatibility_terminal_app_bundle() {
  local terminal_app_name="$1"
  local terminal_executable_name="$2"
  local terminal_bundle_id="$3"
  local app_version="$4"
  local build_number="$5"
  local minimum_system_version="$6"
  local source_binary="$7"
  local icon_source="$8"
  local main_app_bundle="$9"

  local terminal_app_bundle="$main_app_bundle/Contents/Applications/$terminal_app_name.app"
  local terminal_app_contents="$terminal_app_bundle/Contents"
  local terminal_app_macos="$terminal_app_contents/MacOS"
  local terminal_app_resources="$terminal_app_contents/Resources"
  local terminal_app_binary="$terminal_app_macos/$terminal_executable_name"
  local terminal_info_plist="$terminal_app_contents/Info.plist"

  [[ -x "$source_binary" ]] || release_error "Release 可执行文件不存在或不可执行：$source_binary"

  rm -rf "$terminal_app_bundle"
  mkdir -p "$terminal_app_macos" "$terminal_app_resources"

  cp "$source_binary" "$terminal_app_binary"
  chmod 755 "$terminal_app_binary"

  if [[ -f "$icon_source" ]]; then
    cp "$icon_source" "$terminal_app_resources/DockerCompatibilityTerminalIcon.icns"
  else
    release_warn "未找到 Docker 兼容终端图标文件：$icon_source"
  fi

  cat >"$terminal_info_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>Docker 兼容终端</string>
  <key>CFBundleExecutable</key>
  <string>$terminal_executable_name</string>
  <key>CFBundleIconFile</key>
  <string>DockerCompatibilityTerminalIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$terminal_bundle_id</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$terminal_app_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$app_version</string>
  <key>CFBundleVersion</key>
  <string>$build_number</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$minimum_system_version</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST
}

sign_macos_app_bundle() {
  local app_bundle="$1"
  local identity="$2"
  local entitlements="${3:-}"

  local codesign_args=(--force --sign "$identity")
  if [[ "$identity" != "-" ]]; then
    codesign_args+=(--options runtime --timestamp)
    if [[ -n "$entitlements" ]]; then
      [[ -f "$entitlements" ]] || release_error "Entitlements 文件不存在：$entitlements"
      codesign_args+=(--entitlements "$entitlements")
    fi
  fi

  /usr/bin/codesign "${codesign_args[@]}" "$app_bundle"
}

verify_macos_app_bundle() {
  local app_bundle="$1"

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app_bundle"
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_bundle/Contents/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_bundle/Contents/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app_bundle/Contents/Info.plist" >/dev/null
}

assess_macos_app_bundle() {
  local app_bundle="$1"
  local identity="$2"

  if [[ "$identity" == "-" ]]; then
    release_warn "当前为 ad-hoc 签名，跳过 Gatekeeper 评估。正式发布请传入 --identity \"Developer ID Application: ...\"。"
    return 0
  fi

  /usr/sbin/spctl --assess --type execute --verbose=4 "$app_bundle"
}

create_app_zip() {
  local app_bundle="$1"
  local zip_path="$2"

  rm -f "$zip_path"
  /usr/bin/ditto -c -k --keepParent "$app_bundle" "$zip_path"
}

create_app_dmg() {
  local app_name="$1"
  local app_bundle="$2"
  local dmg_path="$3"
  local volume_name="$4"
  local staging_dir="$5"

  rm -rf "$staging_dir" "$dmg_path"
  mkdir -p "$staging_dir"

  /usr/bin/ditto "$app_bundle" "$staging_dir/$app_name.app"
  ln -s /Applications "$staging_dir/Applications"

  hdiutil create \
    -quiet \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -ov \
    "$dmg_path"

  rm -rf "$staging_dir"
}

notarize_macos_app_bundle() {
  local app_bundle="$1"
  local notary_zip="$2"
  local notary_profile="${3:-}"

  create_app_zip "$app_bundle" "$notary_zip"

  local submit_args=(notarytool submit "$notary_zip" --wait)
  if [[ -n "$notary_profile" ]]; then
    submit_args+=(--keychain-profile "$notary_profile")
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
    submit_args+=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APP_SPECIFIC_PASSWORD")
  else
    release_error "启用 notarization 时，需要设置 NOTARY_PROFILE，或设置 APPLE_ID、APPLE_TEAM_ID、APP_SPECIFIC_PASSWORD。"
  fi

  xcrun "${submit_args[@]}"
  xcrun stapler staple "$app_bundle"
  xcrun stapler validate "$app_bundle"
}
