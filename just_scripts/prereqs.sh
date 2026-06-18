#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/just_scripts/lib/common.sh"
cd "$ROOT"

info "pre: checking prerequisites…"

fail=0
need_cmd xcodebuild "install Xcode from the Mac App Store or https://developer.apple.com/xcode" || fail=1
need_cmd xcrun      "install Xcode command-line tools: xcode-select --install"                   || fail=1

# Require Xcode 15+ (project targets macOS 26)
if command -v xcodebuild >/dev/null 2>&1; then
    xcode_major=$(xcodebuild -version 2>/dev/null | awk '/^Xcode/ {split($2,a,"."); print a[1]}')
    if [ -n "$xcode_major" ] && [ "$xcode_major" -lt 15 ]; then
        red "✗ Xcode $xcode_major detected — version 15 or newer required"
        fail=1
    else
        green "✓  Xcode version OK ($xcode_major)"
    fi
fi

if [ "$fail" -ne 0 ]; then
    red "Some prerequisites are missing. Install them and rerun 'just pre'."
    exit 1
fi

green "All prerequisites satisfied."
