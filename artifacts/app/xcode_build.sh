#!/usr/bin/env bash
# Usage: xcode_build.sh [archive]
# Project-local builder. Generates the Xcode project via XcodeGen (if present)
# and then invokes xcodebuild against the HaoYunDiary scheme.
# Exits 0 on success; non-zero on failure.

set -u
MODE="${1:-build}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

SCHEME="HaoYunDiary"
PROJ="HaoYunDiary.xcodeproj"

# 1) Generate the Xcode project from project.yml (XcodeGen).
if [[ -f "project.yml" ]]; then
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --spec project.yml --project . || {
      echo "XCODEGEN_FAIL" >&2
      exit 3
    }
  else
    echo "xcodegen not installed; skipping generation. Falling back to Package.swift if present." >&2
  fi
fi

# 2) Build or archive.
if [[ -d "$PROJ" ]]; then
  if [[ "$MODE" == "archive" ]]; then
    ARCHIVE_PATH="$APP_DIR/build/HaoYunDiary.xcarchive"
    xcodebuild -project "$PROJ" -scheme "$SCHEME" \
      -configuration Release archive -archivePath "$ARCHIVE_PATH" \
      -destination 'generic/platform=iOS' \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
      | tail -n 120
    if [[ -d "$ARCHIVE_PATH" ]]; then
      echo "ARCHIVE_OK $ARCHIVE_PATH"
    else
      echo "ARCHIVE_FAIL" >&2
      exit 2
    fi
  else
    xcodebuild -project "$PROJ" -scheme "$SCHEME" \
      -destination 'generic/platform=iOS Simulator' build \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
      | tail -n 80
  fi
elif [[ -f "Package.swift" ]]; then
  swift build 2>&1 | tail -n 80
else
  echo "no xcodeproj or Package.swift in $APP_DIR — skipping" >&2
  exit 0
fi
