#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="StandPrototype"
BG3_CONFIG="${1:-$HOME/.local/share/Larian Studios/Baldur's Gate 3}"
TARGET="$BG3_CONFIG/Mods/$MOD_NAME"

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  rm -rf "$TARGET"
  echo "Removed $TARGET"
else
  echo "Nothing to remove at $TARGET"
fi
