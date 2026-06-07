#!/usr/bin/env bash
# Shared helpers for just_scripts

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
info()   { printf "▶ %s\n" "$*"; }
die()    { red "✗ $*"; exit 1; }

need_cmd() {
    local cmd="$1" hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        red "✗ missing: $cmd — $hint"
        return 1
    fi
    green "✓  $cmd ($(command -v "$cmd"))"
}
