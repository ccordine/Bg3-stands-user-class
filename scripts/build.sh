#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="StandPrototype"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$MOD_ROOT/dist"
PAK_PATH="$OUT_DIR/${MOD_NAME}.pak"
ENV_FILE="$MOD_ROOT/.env"

usage() {
  cat <<USAGE
Usage: $0 [--mod-root PATH] [--out-dir PATH] [--game-data PATH] [--env-file PATH] [--print-config]

Builds ${MOD_NAME}.pak from the mod source directory using divine (LSLib CLI).

Options:
  --mod-root PATH   Mod root directory (default: repo root)
  --out-dir PATH    Output directory for .pak (default: <mod-root>/dist)
  --game-data PATH  BG3 Data directory path (optional but recommended)
  --env-file PATH   Environment file (default: <mod-root>/.env)
  --print-config    Print resolved config before build

Requirements:
  - divine must be installed and executable.
USAGE
}

GAME_DATA=""
PRINT_CONFIG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mod-root)
      MOD_ROOT="${2:-}"; shift 2 ;;
    --out-dir)
      OUT_DIR="${2:-}"; shift 2 ;;
    --game-data)
      GAME_DATA="${2:-}"; shift 2 ;;
    --env-file)
      ENV_FILE="${2:-}"; shift 2 ;;
    --print-config)
      PRINT_CONFIG=1; shift ;;
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

if [[ -z "$GAME_DATA" && -n "${BG3_DATA_PATH:-}" ]]; then
  GAME_DATA="$BG3_DATA_PATH"
fi
if [[ -z "$GAME_DATA" && -n "${BG3_DATA_ROOT:-}" ]]; then
  GAME_DATA="${BG3_DATA_ROOT%/}/Data"
fi

DIVINE_BIN="${DIVINE_BIN:-}"
if [[ -n "$DIVINE_BIN" && ! -x "$DIVINE_BIN" ]]; then
  DIVINE_BIN=""
fi
if [[ -z "$DIVINE_BIN" ]]; then
  if command -v divine >/dev/null 2>&1; then
    DIVINE_BIN="$(command -v divine)"
  elif [[ -x "$HOME/.local/bin/divine" ]]; then
    DIVINE_BIN="$HOME/.local/bin/divine"
  fi
fi

if [[ -z "$DIVINE_BIN" || ! -x "$DIVINE_BIN" ]]; then
  echo "Error: divine not found in PATH or ~/.local/bin/divine." >&2
  echo "Run ./scripts/setup-arch.sh and retry." >&2
  exit 1
fi

if [[ ! -f "$MOD_ROOT/meta.lsx" ]]; then
  echo "Error: meta.lsx not found at $MOD_ROOT/meta.lsx" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
MOD_ROOT="$(realpath "$MOD_ROOT")"
OUT_DIR="$(realpath "$OUT_DIR")"
PAK_PATH="$OUT_DIR/${MOD_NAME}.pak"
STAGE_DIR="$OUT_DIR/.build_stage"

if [[ -z "$GAME_DATA" ]]; then
  CANDIDATES=(
    "$HOME/.steam/steam/steamapps/common/Baldurs Gate 3/Data"
    "$HOME/.local/share/Steam/steamapps/common/Baldurs Gate 3/Data"
  )
  for c in "${CANDIDATES[@]}"; do
    if [[ -d "$c" ]]; then
      GAME_DATA="$c"
      break
    fi
  done
fi

if [[ -z "$GAME_DATA" || ! -d "$GAME_DATA" ]]; then
  echo "Warning: --game-data not set or invalid. Proceeding without explicit game data path." >&2
  echo "If build fails, pass --game-data /path/to/Baldurs Gate 3/Data" >&2
fi

if [[ $PRINT_CONFIG -eq 1 ]]; then
  echo "Resolved config:"
  echo "  MOD_ROOT=$MOD_ROOT"
  echo "  OUT_DIR=$OUT_DIR"
  echo "  ENV_FILE=$ENV_FILE"
  echo "  DIVINE_BIN=${DIVINE_BIN:-<unset>}"
  echo "  GAME_DATA=${GAME_DATA:-<unset>}"
fi

rm -f "$PAK_PATH"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/Mods/$MOD_NAME"

# Build from a canonical BG3 package layout:
#   Mods/<ModName>/meta.lsx
#   Public/<ModName>/...
#   ScriptExtender/...
if [[ -f "$MOD_ROOT/meta.lsx" ]]; then
  cp "$MOD_ROOT/meta.lsx" "$STAGE_DIR/Mods/$MOD_NAME/meta.lsx"
fi
if [[ -d "$MOD_ROOT/Public" ]]; then
  cp -a "$MOD_ROOT/Public" "$STAGE_DIR/Public"
fi
if [[ -d "$MOD_ROOT/ScriptExtender" ]]; then
  cp -a "$MOD_ROOT/ScriptExtender" "$STAGE_DIR/ScriptExtender"
fi
if [[ -d "$MOD_ROOT/Localization" ]]; then
  cp -a "$MOD_ROOT/Localization" "$STAGE_DIR/Localization"
fi
if [[ -d "$MOD_ROOT/Assets" ]]; then
  cp -a "$MOD_ROOT/Assets" "$STAGE_DIR/Assets"
fi

DIVINE_HELP="$("$DIVINE_BIN" --help 2>&1 || true)"
HAS_GAME_DATA_FLAG=0
if grep -q -- "--game-data-path" <<<"$DIVINE_HELP"; then
  HAS_GAME_DATA_FLAG=1
fi

run_divine() {
  local src="$1"
  local dst="$2"
  local gd="${3:-}"
  local supports_game_flag=0
  if grep -qE -- '(^|[[:space:]])-g([[:space:]]|,|$)|--game' <<<"$DIVINE_HELP"; then
    supports_game_flag=1
  fi

  local args=(-a create-package -s "$src" -d "$dst")
  if [[ $supports_game_flag -eq 1 ]]; then
    args=(-a create-package -g bg3 -s "$src" -d "$dst")
  fi
  if [[ -n "$gd" && $HAS_GAME_DATA_FLAG -eq 1 ]]; then
    args+=("--game-data-path" "$gd")
  fi
  "$DIVINE_BIN" "${args[@]}"
}

to_file_uri() {
  local p="$1"
  printf 'file://%s\n' "$p"
}

set +e
run_divine "$STAGE_DIR" "$PAK_PATH" "${GAME_DATA:-}"
FIRST_RC=$?
set -e
if [[ $FIRST_RC -ne 0 ]]; then
  echo "Normal path invocation failed with exit code $FIRST_RC; retrying with file:// URI paths..." >&2
  SRC_URI="$(to_file_uri "$STAGE_DIR")"
  DST_URI="$(to_file_uri "$PAK_PATH")"
  GD_URI=""
  if [[ -n "${GAME_DATA:-}" ]]; then
    GD_URI="$(to_file_uri "$GAME_DATA")"
  fi
  set +e
  run_divine "$SRC_URI" "$DST_URI" "$GD_URI"
  SECOND_RC=$?
  set -e
  if [[ $SECOND_RC -ne 0 ]]; then
    echo "Fallback URI invocation also failed with exit code $SECOND_RC." >&2
    echo "Retrying once without game flag forcing (compat mode)..." >&2
    COMPAT_HELP="$DIVINE_HELP"
    DIVINE_HELP="$(sed 's/-g bg3//g' <<<"$DIVINE_HELP")"
    set +e
    run_divine "$STAGE_DIR" "$PAK_PATH" "${GAME_DATA:-}"
    THIRD_RC=$?
    set -e
    DIVINE_HELP="$COMPAT_HELP"
    if [[ $THIRD_RC -ne 0 ]]; then
      echo "Compat mode also failed with exit code $THIRD_RC." >&2
      echo "Hint: this Divine build is likely incompatible with Linux path handling." >&2
      exit $THIRD_RC
    fi
  fi
fi

if [[ ! -f "$PAK_PATH" ]]; then
  echo "Build failed: expected output not found: $PAK_PATH" >&2
  exit 1
fi

echo "Built package: $PAK_PATH"
