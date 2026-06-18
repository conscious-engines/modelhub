#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/just_scripts/lib/common.sh"
cd "$ROOT"

SCHEME="modelhub"
CONFIG="Debug"

info "run: building $SCHEME ($CONFIG)…"

SIGN_FLAGS="CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"

xcodebuild \
    -project modelhub.xcodeproj \
    -target "$SCHEME" \
    -configuration "$CONFIG" \
    $SIGN_FLAGS \
    build 2>&1 | tail -5

APP_PATH="${ROOT}/build/${CONFIG}/${SCHEME}.app"
if [ -d "$APP_PATH" ]; then
    info "run: launching $APP_PATH"
    open "$APP_PATH"
else
    # Fallback: find the .app anywhere under DerivedData
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${SCHEME}.app" -type d 2>/dev/null | head -1)
    if [ -n "$APP_PATH" ]; then
        info "run: launching $APP_PATH"
        open "$APP_PATH"
    else
        die "Could not find built app. Try 'just build' first."
    fi
fi
