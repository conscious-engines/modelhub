#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/just_scripts/lib/common.sh"
cd "$ROOT"

SCHEME="${1:-modelhub}"
CONFIG="${2:-Debug}"

info "build: xcodebuild $SCHEME ($CONFIG)…"
xcodebuild \
    -project modelhub.xcodeproj \
    -target "$SCHEME" \
    -configuration "$CONFIG" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build | xcpretty 2>/dev/null || \
xcodebuild \
    -project modelhub.xcodeproj \
    -target "$SCHEME" \
    -configuration "$CONFIG" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build

green "Build succeeded."
