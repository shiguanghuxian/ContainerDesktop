#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ContainerDesktop"
BUNDLE_ID="com.shiguanghuxian.ContainerDesktop"
MIN_SYSTEM_VERSION="26.0"
TERMINAL_APP_NAME="Docker Compatibility Terminal"
TERMINAL_APP_EXECUTABLE="DockerCompatibilityTerminal"
TERMINAL_BUNDLE_ID="$BUNDLE_ID.DockerCompatibilityTerminal"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$ROOT_DIR/script/lib"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
TERMINAL_ICON_SOURCE="$ROOT_DIR/Resources/DockerCompatibilityTerminalIcon.icns"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/dist/release"

# shellcheck source=script/lib/macos_bundle.sh
source "$LIB_DIR/macos_bundle.sh"

VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
CODESIGN_ENTITLEMENTS="${CODESIGN_ENTITLEMENTS:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
RUN_TESTS=1
CREATE_ZIP=1
CREATE_DMG=1
RUN_NOTARIZATION=0
CLEAN_BUILD=0

usage() {
  cat <<EOF
usage:
  $0 --version 1.0.0 [options]
  $0 1.0.0 [options]

options:
  --version VERSION        正式版版本号，会写入 CFBundleShortVersionString。
  --build BUILD           构建号，会写入 CFBundleVersion；默认使用 git commit 数量。
  --output DIR            发布产物目录，默认 dist/release。
  --identity IDENTITY     codesign 身份；默认使用 CODESIGN_IDENTITY，未设置时使用 ad-hoc 签名。
  --entitlements FILE     codesign entitlements 文件。
  --notarize              提交 Apple notarization，要求 Developer ID 签名。
  --notary-profile NAME   notarytool keychain profile；也可用 NOTARY_PROFILE。
  --skip-tests            跳过 swift test。
  --clean                 先执行 swift package clean。
  --no-zip                不生成 zip。
  --no-dmg                不生成 dmg。
  -h, --help              显示帮助。

notarization env:
  NOTARY_PROFILE=profile-name
  或 APPLE_ID、APPLE_TEAM_ID、APP_SPECIFIC_PASSWORD
EOF
}

default_build_number() {
  if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT_DIR" rev-list --count HEAD
  else
    date +%Y%m%d%H%M%S
  fi
}

git_commit_short() {
  git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf "unknown"
}

validate_inputs() {
  [[ -n "$VERSION" ]] || release_error "必须通过 --version 或 VERSION 环境变量指定正式版版本号，例如：$0 --version 1.0.0"
  [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || release_error "版本号必须是 1.0 或 1.0.0 这类数字版本：$VERSION"

  if [[ -z "$BUILD_NUMBER" ]]; then
    BUILD_NUMBER="$(default_build_number)"
  fi
  [[ "$BUILD_NUMBER" =~ ^[0-9A-Za-z.-]+$ ]] || release_error "构建号只能包含数字、字母、点和短横线：$BUILD_NUMBER"

  if [[ "$RUN_NOTARIZATION" -eq 1 && "$CODESIGN_IDENTITY" == "-" ]]; then
    release_error "notarization 不能使用 ad-hoc 签名，请传入 --identity \"Developer ID Application: ...\"。"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        VERSION="${2:-}"
        shift 2
        ;;
      --build)
        BUILD_NUMBER="${2:-}"
        shift 2
        ;;
      --output)
        OUTPUT_DIR="${2:-}"
        shift 2
        ;;
      --identity)
        CODESIGN_IDENTITY="${2:-}"
        shift 2
        ;;
      --entitlements)
        CODESIGN_ENTITLEMENTS="${2:-}"
        shift 2
        ;;
      --notarize)
        RUN_NOTARIZATION=1
        shift
        ;;
      --notary-profile)
        NOTARY_PROFILE="${2:-}"
        shift 2
        ;;
      --skip-tests)
        RUN_TESTS=0
        shift
        ;;
      --clean)
        CLEAN_BUILD=1
        shift
        ;;
      --no-zip)
        CREATE_ZIP=0
        shift
        ;;
      --no-dmg)
        CREATE_DMG=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        release_error "未知参数：$1"
        ;;
      *)
        if [[ -z "$VERSION" ]]; then
          VERSION="$1"
          shift
        else
          release_error "未知位置参数：$1"
        fi
        ;;
    esac
  done
}

write_manifest() {
  local manifest_path="$1"
  local app_bundle="$2"
  local zip_path="$3"
  local dmg_path="$4"
  local appcast_path="$5"

  cat >"$manifest_path" <<EOF
app: $APP_NAME
bundle_id: $BUNDLE_ID
version: $VERSION
build: $BUILD_NUMBER
minimum_system_version: $MIN_SYSTEM_VERSION
git_commit: $(git_commit_short)
swift: $(swift --version | head -n 1)
app_bundle: $app_bundle
zip: $zip_path
dmg: $dmg_path
appcast: $appcast_path
EOF
}

write_checksums() {
  local checksum_path="$1"
  shift

  : >"$checksum_path"
  for artifact in "$@"; do
    if [[ -f "$artifact" ]]; then
      shasum -a 256 "$artifact" >>"$checksum_path"
    fi
  done
}

release_notes_for_version() {
  if [[ -n "${CONTAINER_DESKTOP_RELEASE_NOTES_FILE:-}" ]]; then
    if [[ -f "$CONTAINER_DESKTOP_RELEASE_NOTES_FILE" ]]; then
      cat "$CONTAINER_DESKTOP_RELEASE_NOTES_FILE"
      return
    fi
    release_error "Release notes file does not exist: $CONTAINER_DESKTOP_RELEASE_NOTES_FILE"
  fi

  local notes_path="$ROOT_DIR/Packaging/release-notes/$VERSION.md"
  if [[ -f "$notes_path" ]]; then
    cat "$notes_path"
  else
    printf "ContainerDesktop %s\n" "$VERSION"
  fi
}

write_appcast() {
  local appcast_path="$1"
  local zip_path="$2"

  if [[ -z "$zip_path" || ! -f "$zip_path" ]]; then
    release_warn "跳过 appcast 生成：没有 zip 更新包。"
    return
  fi

  local release_tag="${CONTAINER_DESKTOP_RELEASE_TAG:-$VERSION}"
  local release_base_url="${CONTAINER_DESKTOP_RELEASE_BASE_URL:-https://github.com/shiguanghuxian/ContainerDesktop/releases/download/$release_tag}"
  local release_page_url="${CONTAINER_DESKTOP_RELEASE_PAGE_URL:-https://github.com/shiguanghuxian/ContainerDesktop/releases/tag/$release_tag}"
  local published_at
  published_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local sha256
  sha256="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
  local release_notes_path
  release_notes_path="$(mktemp)"
  release_notes_for_version >"$release_notes_path"

  APPCAST_PATH="$appcast_path" \
  VERSION="$VERSION" \
  RELEASE_TAG="$release_tag" \
  RELEASE_PAGE_URL="$release_page_url" \
  RELEASE_BASE_URL="$release_base_url" \
  RELEASE_NOTES_PATH="$release_notes_path" \
  PUBLISHED_AT="$published_at" \
  ZIP_PATH="$zip_path" \
  ZIP_SHA256="$sha256" \
  ARCH="$ARCH" \
  python3 <<'PY'
import json
import os
import pathlib

zip_path = pathlib.Path(os.environ["ZIP_PATH"])
base_url = os.environ["RELEASE_BASE_URL"].rstrip("/")
arch = os.environ["ARCH"]
name = zip_path.name
release_notes = pathlib.Path(os.environ["RELEASE_NOTES_PATH"]).read_text(encoding="utf-8")

payload = {
    "version": os.environ["VERSION"],
    "tag_name": os.environ["RELEASE_TAG"],
    "title": f"ContainerDesktop {os.environ['VERSION']}",
    "published_at": os.environ["PUBLISHED_AT"],
    "release_notes": release_notes,
    "html_url": os.environ["RELEASE_PAGE_URL"],
    "assets": {
        arch: {
            "name": name,
            "download_url": f"{base_url}/{name}",
            "size": zip_path.stat().st_size,
            "sha256": os.environ["ZIP_SHA256"],
        }
    },
}

pathlib.Path(os.environ["APPCAST_PATH"]).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  rm -f "$release_notes_path"
}

parse_args "$@"
validate_inputs

require_tool swift
require_tool git
require_tool shasum
require_tool python3
require_xcrun_tool codesign
require_xcrun_tool ditto
if [[ "$CREATE_DMG" -eq 1 ]]; then
  require_xcrun_tool hdiutil
fi
if [[ "$RUN_NOTARIZATION" -eq 1 ]]; then
  require_xcrun_tool notarytool
  require_xcrun_tool stapler
fi

ARCH="$(uname -m)"
RELEASE_NAME="$APP_NAME-$VERSION-$BUILD_NUMBER-$ARCH"
WORK_DIR="$OUTPUT_DIR/$RELEASE_NAME"
APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
TERMINAL_APP_BUNDLE="$APP_BUNDLE/Contents/Applications/$TERMINAL_APP_NAME.app"
ZIP_PATH="$OUTPUT_DIR/$RELEASE_NAME.zip"
DMG_PATH="$OUTPUT_DIR/$RELEASE_NAME.dmg"
NOTARY_ZIP="$WORK_DIR/$RELEASE_NAME-notary.zip"
CHECKSUM_PATH="$OUTPUT_DIR/$RELEASE_NAME-SHA256SUMS.txt"
MANIFEST_PATH="$WORK_DIR/release-manifest.txt"
APPCAST_PATH="$OUTPUT_DIR/appcast.json"

cd "$ROOT_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

release_log "准备正式发布包：$RELEASE_NAME"

if [[ "$RUN_TESTS" -eq 1 ]]; then
  release_log "运行测试"
  swift test
else
  release_warn "已跳过测试"
fi

if [[ "$CLEAN_BUILD" -eq 1 ]]; then
  release_log "清理 SwiftPM 构建缓存"
  swift package clean
fi

release_log "构建 Release 可执行文件"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

release_log "生成 app bundle"
create_macos_app_bundle \
  "$APP_NAME" \
  "$BUNDLE_ID" \
  "$VERSION" \
  "$BUILD_NUMBER" \
  "$MIN_SYSTEM_VERSION" \
  "$BUILD_BINARY" \
  "$ICON_SOURCE" \
  "$APP_BUNDLE"

create_docker_compatibility_terminal_app_bundle \
  "$TERMINAL_APP_NAME" \
  "$TERMINAL_APP_EXECUTABLE" \
  "$TERMINAL_BUNDLE_ID" \
  "$VERSION" \
  "$BUILD_NUMBER" \
  "$MIN_SYSTEM_VERSION" \
  "$BUILD_BINARY" \
  "$TERMINAL_ICON_SOURCE" \
  "$APP_BUNDLE"

release_log "签名 Docker 兼容终端 app bundle"
sign_macos_app_bundle "$TERMINAL_APP_BUNDLE" "$CODESIGN_IDENTITY" "$CODESIGN_ENTITLEMENTS"

release_log "签名 app bundle"
sign_macos_app_bundle "$APP_BUNDLE" "$CODESIGN_IDENTITY" "$CODESIGN_ENTITLEMENTS"

release_log "校验 app bundle"
verify_macos_app_bundle "$APP_BUNDLE"

if [[ "$RUN_NOTARIZATION" -eq 1 ]]; then
  release_log "提交 notarization"
  notarize_macos_app_bundle "$APP_BUNDLE" "$NOTARY_ZIP" "$NOTARY_PROFILE"
fi

assess_macos_app_bundle "$APP_BUNDLE" "$CODESIGN_IDENTITY"

ARTIFACTS=()
if [[ "$CREATE_ZIP" -eq 1 ]]; then
  release_log "生成 zip"
  create_app_zip "$APP_BUNDLE" "$ZIP_PATH"
  ARTIFACTS+=("$ZIP_PATH")
else
  ZIP_PATH=""
fi

if [[ "$CREATE_DMG" -eq 1 ]]; then
  release_log "生成 dmg"
  create_app_dmg "$APP_NAME" "$APP_BUNDLE" "$DMG_PATH" "$APP_NAME $VERSION" "$WORK_DIR/dmg-root"
  ARTIFACTS+=("$DMG_PATH")
else
  DMG_PATH=""
fi

if [[ ${#ARTIFACTS[@]} -gt 0 ]]; then
  write_checksums "$CHECKSUM_PATH" "${ARTIFACTS[@]}"
else
  write_checksums "$CHECKSUM_PATH"
fi
write_appcast "$APPCAST_PATH" "$ZIP_PATH"
write_manifest "$MANIFEST_PATH" "$APP_BUNDLE" "$ZIP_PATH" "$DMG_PATH" "$APPCAST_PATH"

release_log "发布包已生成"
printf "app: %s\n" "$APP_BUNDLE"
[[ -n "$ZIP_PATH" ]] && printf "zip: %s\n" "$ZIP_PATH"
[[ -n "$DMG_PATH" ]] && printf "dmg: %s\n" "$DMG_PATH"
[[ -f "$APPCAST_PATH" ]] && printf "appcast: %s\n" "$APPCAST_PATH"
printf "manifest: %s\n" "$MANIFEST_PATH"
printf "checksums: %s\n" "$CHECKSUM_PATH"
