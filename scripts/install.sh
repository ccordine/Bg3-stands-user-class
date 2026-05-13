#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="StandPrototype"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$MOD_ROOT/.env"

usage() {
  cat <<USAGE
Usage: $0 [--bg3-data PATH] [--bg3-config PATH] [--symlink] [--env-file PATH]

Installs ${MOD_NAME} for BG3 on Linux/Proton by copying or symlinking the mod
folder into the BG3 Mods directory.

Options:
  --bg3-data PATH    BG3 game install root (folder containing Data/)
  --bg3-config PATH  BG3 config root (folder containing Mods/)
  --symlink          Symlink instead of copy (recommended for development)
  --env-file PATH    Environment file (default: <mod-root>/.env)
USAGE
}

BG3_DATA=""
BG3_CONFIG=""
USE_SYMLINK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bg3-data)
      BG3_DATA="${2:-}"; shift 2 ;;
    --bg3-config)
      BG3_CONFIG="${2:-}"; shift 2 ;;
    --symlink)
      USE_SYMLINK=1; shift ;;
    --env-file)
      ENV_FILE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -z "$BG3_DATA" && -n "${BG3_DATA_ROOT:-}" ]]; then
  BG3_DATA="$BG3_DATA_ROOT"
fi
if [[ -z "$BG3_CONFIG" && -n "${BG3_CONFIG_ROOT:-}" ]]; then
  BG3_CONFIG="$BG3_CONFIG_ROOT"
fi

DEFAULT_DATA_CANDIDATES=(
  "$HOME/.steam/steam/steamapps/common/Baldurs Gate 3"
  "$HOME/.local/share/Steam/steamapps/common/Baldurs Gate 3"
)

DEFAULT_CONFIG_CANDIDATES=(
  "$HOME/.local/share/Larian Studios/Baldur's Gate 3"
  "$HOME/.steam/steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3"
  "$HOME/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3"
)

pick_existing() {
  local arr_name="$1"
  local -n arr_ref="$arr_name"
  for p in "${arr_ref[@]}"; do
    if [[ -d "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

if [[ -z "$BG3_DATA" ]]; then
  BG3_DATA="$(pick_existing DEFAULT_DATA_CANDIDATES || true)"
fi

if [[ -z "$BG3_CONFIG" ]]; then
  BG3_CONFIG="$(pick_existing DEFAULT_CONFIG_CANDIDATES || true)"
fi

if [[ -z "$BG3_DATA" || -z "$BG3_CONFIG" ]]; then
  echo "Could not auto-detect BG3 paths." >&2
  echo "Pass --bg3-data and --bg3-config explicitly, or configure .env." >&2
  exit 1
fi

if [[ ! -d "$BG3_DATA/Data" ]]; then
  echo "Invalid --bg3-data path: missing Data/ in $BG3_DATA" >&2
  exit 1
fi

mkdir -p "$BG3_CONFIG/Mods"
TARGET="$BG3_CONFIG/Mods/$MOD_NAME"

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  rm -rf "$TARGET"
fi

if [[ $USE_SYMLINK -eq 1 ]]; then
  ln -s "$MOD_ROOT" "$TARGET"
  MODE="symlink"
else
  cp -a "$MOD_ROOT" "$TARGET"
  MODE="copy"
fi

cat <<DONE
Installed $MOD_NAME using $MODE mode.

Source: $MOD_ROOT
Target: $TARGET

Next:
1. Build/package from toolkit as usual (this script stages source only).
2. Ensure Script Extender is installed in game root.
3. Add module entry to modsettings.lsx and enable the mod.
DONE
