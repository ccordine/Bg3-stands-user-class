#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="StandPrototype"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$MOD_ROOT/.env"

usage() {
  cat <<USAGE
Usage: $0 [--bg3-data PATH] [--bg3-config PATH] [--pak PATH] [--build-if-missing] [--env-file PATH]

Installs ${MOD_NAME}.pak for BG3 on Linux/Proton by copying the package into the
BG3 Mods directory.

Options:
  --bg3-data PATH    BG3 game install root (folder containing Data/)
  --bg3-config PATH  BG3 config root (folder containing Mods/)
  --pak PATH         Path to .pak file (default: <mod-root>/dist/StandPrototype.pak)
  --build-if-missing Build package automatically if --pak does not exist
  --env-file PATH    Environment file (default: <mod-root>/.env)
USAGE
}

BG3_DATA=""
BG3_CONFIG=""
PAK_PATH="$MOD_ROOT/dist/${MOD_NAME}.pak"
BUILD_IF_MISSING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bg3-data)
      BG3_DATA="${2:-}"; shift 2 ;;
    --bg3-config)
      BG3_CONFIG="${2:-}"; shift 2 ;;
    --pak)
      PAK_PATH="${2:-}"; shift 2 ;;
    --build-if-missing)
      BUILD_IF_MISSING=1; shift ;;
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
  "$HOME/.steam/steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3"
  "$HOME/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3"
  "$HOME/.local/share/Larian Studios/Baldur's Gate 3"
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

if [[ -z "$BG3_CONFIG" ]]; then
  BG3_CONFIG="$(pick_existing DEFAULT_CONFIG_CANDIDATES || true)"
fi

if [[ -z "$BG3_DATA" ]]; then
  BG3_DATA="$(pick_existing DEFAULT_DATA_CANDIDATES || true)"
fi

if [[ -z "$BG3_CONFIG" ]]; then
  echo "Could not auto-detect BG3 config path." >&2
  echo "Pass --bg3-config explicitly, or configure .env." >&2
  exit 1
fi

if [[ -n "$BG3_DATA" && ! -d "$BG3_DATA/Data" ]]; then
  echo "Warning: --bg3-data path is invalid (missing Data/): $BG3_DATA" >&2
  BG3_DATA=""
fi

if [[ ! -f "$PAK_PATH" && $BUILD_IF_MISSING -eq 1 ]]; then
  echo "Package not found at $PAK_PATH; attempting build..."
  if [[ -n "$BG3_DATA" ]]; then
    "$MOD_ROOT/scripts/build.sh" --mod-root "$MOD_ROOT" --out-dir "$MOD_ROOT/dist" --game-data "$BG3_DATA/Data"
  else
    "$MOD_ROOT/scripts/build.sh" --mod-root "$MOD_ROOT" --out-dir "$MOD_ROOT/dist"
  fi
fi

if [[ ! -f "$PAK_PATH" ]]; then
  echo "FATAL: package not found: $PAK_PATH" >&2
  echo "Build first with ./scripts/build.sh, or pass --build-if-missing." >&2
  exit 1
fi

mkdir -p "$BG3_CONFIG/Mods"
TARGET_PAK="$BG3_CONFIG/Mods/${MOD_NAME}.pak"
LEGACY_TARGET="$BG3_CONFIG/Mods/$MOD_NAME"

# Remove legacy source-folder installs that BG3 does not load as mod packages.
if [[ -e "$LEGACY_TARGET" || -L "$LEGACY_TARGET" ]]; then
  rm -rf "$LEGACY_TARGET"
fi
rm -f "$TARGET_PAK"
cp -f "$PAK_PATH" "$TARGET_PAK"

cat <<DONE
Installed $MOD_NAME package.

Source package: $PAK_PATH
Target package: $TARGET_PAK

Next:
1. Enable module in modsettings: ./scripts/enable-modsettings.sh
2. Launch BG3 and start a new character.
DONE
