#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="StandPrototype"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$MOD_ROOT/.env"
OUT_DIR="$MOD_ROOT/dist"
SRC_DEFAULT="$OUT_DIR/.build_stage.${USER:-user}"
SRC_FALLBACK="$OUT_DIR/.build_stage"
PAK_PATH="$OUT_DIR/${MOD_NAME}.pak"
TOOLS_ROOT="${TOOLS_ROOT:-$HOME/.local/share/lslib-tools}"
LOG_PATH="$OUT_DIR/package-native.log"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

mkdir -p "$OUT_DIR"
: >"$LOG_PATH"

log() { echo "$*" | tee -a "$LOG_PATH"; }
run() { log "+ $*"; "$@" >>"$LOG_PATH" 2>&1; }

if [[ -d "$SRC_DEFAULT" ]]; then
  SRC="$SRC_DEFAULT"
elif [[ -d "$SRC_FALLBACK" ]]; then
  SRC="$SRC_FALLBACK"
else
  log "FATAL: no staged source found. expected one of:"
  log "  $SRC_DEFAULT"
  log "  $SRC_FALLBACK"
  exit 1
fi

SRC="$(realpath "$SRC")"
OUT_DIR="$(realpath "$OUT_DIR")"
PAK_PATH="$OUT_DIR/${MOD_NAME}.pak"

log "pwd=$(pwd)"
log "MOD_ROOT=$(realpath "$MOD_ROOT")"
log "SRC=$SRC"
log "DST=$PAK_PATH"

if ! command -v dotnet >/dev/null 2>&1; then
  log "FATAL: dotnet not found."
  exit 1
fi

fetch_release() {
  local tag="$1"
  local dir="$TOOLS_ROOT/$tag"
  local zip="$dir/ExportTool-$tag.zip"
  mkdir -p "$dir"
  if [[ ! -f "$zip" ]]; then
    run wget -O "$zip" "https://github.com/Norbyte/lslib/releases/download/$tag/ExportTool-$tag.zip"
  fi
  if [[ ! -f "$dir/Packed/Tools/Divine.dll" ]]; then
    run unzip -o "$zip" -d "$dir"
  fi
  echo "$dir/Packed/Tools/Divine.dll"
}

try_pack() {
  local divine_dll="$1"
  rm -f "$PAK_PATH"
  log "Trying Divine: $divine_dll"
  if run dotnet "$divine_dll" -a create-package -g bg3 -s "$SRC" -d "$PAK_PATH"; then
    return 0
  fi
  return 1
}

# Candidate tags: newest first, then known older tags.
TAGS=(v1.20.4 v1.20.3 v1.20.2 v1.20.1 v1.20.0 v1.19.5 v1.19.4 v1.19.3)

for tag in "${TAGS[@]}"; do
  log "---- release $tag ----"
  set +e
  DLL_PATH="$(fetch_release "$tag")"
  rc=$?
  set -e
  if [[ $rc -ne 0 || ! -f "$DLL_PATH" ]]; then
    log "skip $tag: failed to fetch/unpack"
    continue
  fi
  if try_pack "$DLL_PATH"; then
    log "SUCCESS: $PAK_PATH"
    ls -lah "$PAK_PATH" | tee -a "$LOG_PATH"
    exit 0
  fi
done

log "FATAL: failed to package with all tested LSLib releases."
log "See log: $LOG_PATH"
exit 2
