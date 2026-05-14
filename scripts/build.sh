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

MODULE_UUID="$(sed -n 's/.*id="UUID" type="FixedString" value="\([^"]*\)".*/\1/p' "$MOD_ROOT/meta.lsx" | head -n1)"
if [[ -z "$MODULE_UUID" ]]; then
  echo "Error: could not parse module UUID from $MOD_ROOT/meta.lsx" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
MOD_ROOT="$(realpath "$MOD_ROOT")"
OUT_DIR="$(realpath "$OUT_DIR")"
PAK_PATH="$OUT_DIR/${MOD_NAME}.pak"
STAGE_DIR="$OUT_DIR/.build_stage"
STAGE_DIR_FALLBACK="$OUT_DIR/.build_stage.${USER:-user}"

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

prepare_stage_dir() {
  local candidate="$1"
  if rm -rf "$candidate" 2>/dev/null; then
    mkdir -p "$candidate/Mods/$MOD_NAME" 2>/dev/null && return 0
  fi
  return 1
}

if ! prepare_stage_dir "$STAGE_DIR"; then
  echo "Warning: default stage dir not writable: $STAGE_DIR" >&2
  if prepare_stage_dir "$STAGE_DIR_FALLBACK"; then
    STAGE_DIR="$STAGE_DIR_FALLBACK"
    echo "Using fallback stage dir: $STAGE_DIR" >&2
  else
    TMP_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/${MOD_NAME}.build_stage.XXXXXX")"
    STAGE_DIR="$TMP_STAGE"
    mkdir -p "$STAGE_DIR/Mods/$MOD_NAME"
    echo "Using temp stage dir: $STAGE_DIR" >&2
  fi
fi

# Build from a canonical BG3 package layout:
#   Mods/<ModName>/meta.lsx
#   Public/<ModName>/...
#   Mods/<ModName>/ScriptExtender/...
if [[ -f "$MOD_ROOT/meta.lsx" ]]; then
  cp "$MOD_ROOT/meta.lsx" "$STAGE_DIR/Mods/$MOD_NAME/meta.lsx"
fi
if [[ -d "$MOD_ROOT/Public" ]]; then
  cp -a "$MOD_ROOT/Public" "$STAGE_DIR/Public"
fi
if [[ -d "$MOD_ROOT/ScriptExtender" ]]; then
  cp -a "$MOD_ROOT/ScriptExtender" "$STAGE_DIR/Mods/$MOD_NAME/ScriptExtender"
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
GAME_FLAG_MANDATORY=0
if grep -q -- "-g, --game" <<<"$DIVINE_HELP" && ! grep -q -- "-g, --game\\[optional\\]" <<<"$DIVINE_HELP"; then
  GAME_FLAG_MANDATORY=1
fi

to_wine_path() {
  local p="$1"
  if [[ "$p" == file://* ]]; then
    p="${p#file://}"
  fi
  if [[ "$p" =~ ^[A-Za-z]:\\ ]]; then
    printf '%s\n' "$p"
    return 0
  fi
  p="${p//\//\\}"
  printf 'Z:%s\n' "$p"
}

pak_has_payload() {
  local p="$1"
  [[ -f "$p" ]] || return 1
  local size=0
  size="$(stat -c%s "$p" 2>/dev/null || echo 0)"
  [[ "$size" -gt 64 ]]
}

LAST_DIVINE_OUTPUT=""
LAST_DIVINE_RC=0

is_relative_uri_exception() {
  [[ "${LAST_DIVINE_OUTPUT:-}" == *"This operation is not supported for a relative URI."* ]]
}

run_divine() {
  local src="$1"
  local dst="$2"
  local gd="${3:-}"
  local force_no_game="${4:-0}"
  local src_arg="$src"
  local dst_arg="$dst"
  local gd_arg="$gd"
  local supports_game_flag=0

  if [[ "${DIVINE_BACKEND:-auto}" == "wine" ]]; then
    src_arg="$(to_wine_path "$src_arg")"
    dst_arg="$(to_wine_path "$dst_arg")"
    if [[ -n "$gd_arg" ]]; then
      gd_arg="$(to_wine_path "$gd_arg")"
    fi
  fi

  if [[ "$force_no_game" -eq 0 ]] && grep -qE -- '(^|[[:space:]])-g([[:space:]]|,|$)|--game' <<<"$DIVINE_HELP"; then
    supports_game_flag=1
  fi

  local args=(-a create-package -s "$src_arg" -d "$dst_arg")
  if [[ $supports_game_flag -eq 1 ]]; then
    args=(-a create-package -g bg3 -s "$src_arg" -d "$dst_arg")
  fi
  if [[ -n "$gd" && $HAS_GAME_DATA_FLAG -eq 1 ]]; then
    args+=("--game-data-path" "$gd_arg")
  fi

  local cmd_output=""
  local rc=0
  cmd_output="$("$DIVINE_BIN" "${args[@]}" 2>&1)"
  rc=$?

  LAST_DIVINE_OUTPUT="$cmd_output"
  LAST_DIVINE_RC="$rc"

  if [[ -n "$cmd_output" ]]; then
    printf '%s\n' "$cmd_output" >&2
  fi

  return "$rc"
}

run_divine_legacy_wine() {
  local src="$1"
  local dst="$2"
  local gd="${3:-}"
  local legacy_exe="$HOME/.local/share/lslib-tools/v1.19.3/Tools/Divine.exe"

  command -v wine >/dev/null 2>&1 || return 1
  [[ -f "$legacy_exe" ]] || return 1

  local src_arg dst_arg gd_arg
  src_arg="$(to_wine_path "$src")"
  dst_arg="$(to_wine_path "$dst")"
  gd_arg=""
  if [[ -n "$gd" ]]; then
    gd_arg="$(to_wine_path "$gd")"
  fi

  local args=(-a create-package -g bg3 -s "$src_arg" -d "$dst_arg")
  if [[ -n "$gd_arg" && $HAS_GAME_DATA_FLAG -eq 1 ]]; then
    args+=("--game-data-path" "$gd_arg")
  fi

  local wineprefix="${WINEPREFIX:-$HOME/.wine-divine}"
  WINEPREFIX="$wineprefix" WINEDEBUG=-all wine "$legacy_exe" "${args[@]}"
}

to_file_uri() {
  local p="$1"
  printf 'file://%s\n' "$p"
}

set +e
run_divine "$STAGE_DIR" "$PAK_PATH" "${GAME_DATA:-}" 0
FIRST_RC=$?
set -e
if [[ $FIRST_RC -eq 0 ]] && ! pak_has_payload "$PAK_PATH"; then
  echo "Primary packaging produced an empty package; treating as failure." >&2
  FIRST_RC=86
fi
if [[ $FIRST_RC -ne 0 ]]; then
  SECOND_RC="$FIRST_RC"
  if is_relative_uri_exception; then
    echo "Detected Divine relative-URI runtime fault; skipping file:// URI retry." >&2
  else
    echo "Normal path invocation failed with exit code $FIRST_RC; retrying with file:// URI paths..." >&2
    SRC_URI="$(to_file_uri "$STAGE_DIR")"
    DST_URI="$(to_file_uri "$PAK_PATH")"
    GD_URI=""
    if [[ -n "${GAME_DATA:-}" ]]; then
      GD_URI="$(to_file_uri "$GAME_DATA")"
    fi
    set +e
    run_divine "$SRC_URI" "$DST_URI" "$GD_URI" 0
    SECOND_RC=$?
    set -e
    if [[ $SECOND_RC -eq 0 ]] && ! pak_has_payload "$PAK_PATH"; then
      echo "URI packaging produced an empty package; treating as failure." >&2
      SECOND_RC=86
    fi
  fi
  if [[ $SECOND_RC -ne 0 ]]; then
    echo "Fallback URI invocation also failed with exit code $SECOND_RC." >&2
    THIRD_RC="$SECOND_RC"
    if [[ $GAME_FLAG_MANDATORY -eq 0 ]]; then
      echo "Retrying once without game flag forcing (compat mode)..." >&2
      set +e
      run_divine "$STAGE_DIR" "$PAK_PATH" "${GAME_DATA:-}" 1
      THIRD_RC=$?
      set -e
      if [[ $THIRD_RC -eq 0 ]] && ! pak_has_payload "$PAK_PATH"; then
        echo "Compat packaging produced an empty package; treating as failure." >&2
        THIRD_RC=86
      fi
      if [[ $THIRD_RC -ne 0 ]]; then
        echo "Compat mode also failed with exit code $THIRD_RC." >&2
      fi
    else
      echo "Compat mode skipped: installed Divine requires -g/--game." >&2
    fi
    if [[ $THIRD_RC -ne 0 ]]; then
      echo "Attempting legacy Wine fallback (Divine v1.19.3)..." >&2
      set +e
      run_divine_legacy_wine "$STAGE_DIR" "$PAK_PATH" "${GAME_DATA:-}"
      LEGACY_RC=$?
      set -e
      if [[ $LEGACY_RC -eq 0 ]] && pak_has_payload "$PAK_PATH"; then
        echo "Legacy Wine fallback succeeded." >&2
      else
        echo "Legacy Wine fallback failed with exit code ${LEGACY_RC:-1}." >&2
        echo "Hint: this Divine build is likely incompatible with Linux path handling." >&2
        exit "${LEGACY_RC:-1}"
      fi
    fi
  fi
fi

if [[ ! -f "$PAK_PATH" ]] || ! pak_has_payload "$PAK_PATH"; then
  echo "Build failed: expected output not found: $PAK_PATH" >&2
  exit 1
fi

echo "Built package: $PAK_PATH"
