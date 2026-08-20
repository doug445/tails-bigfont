#!/usr/bin/env bash
# deploy.sh — install tails-bigfont on this machine (command + shell wiring incl. root).
# Source of record: ~/Projects/tails-bigfont/
set -euo pipefail
cd "$(dirname "$0")"
exec ./install.sh --root "$@"
