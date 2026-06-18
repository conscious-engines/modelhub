#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/just_scripts/lib/common.sh"
cd "$ROOT"

SCHEME="modelhub"

info "clean: running xcodebuild clean for $SCHEME…"
xcodebuild \
    -project modelhub.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=macOS" \
    clean

green "Clean succeeded."
