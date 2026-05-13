#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$MOD_ROOT/.env"

NO_INSTALL=0
ALLOW_STAGED=0

usage() {
  cat <<USAGE
Usage: $0 [--no-install] [--allow-staged]

Options:
  --no-install    Skip install step entirely (container-safe)
  --allow-staged  Return success when .pak fails but staged layout exists
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-install)
      NO_INSTALL=1; shift ;;
    --allow-staged)
      ALLOW_STAGED=1; shift ;;
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

cd "$MOD_ROOT"

echo "[1/5] Static validation"
./scripts/validate_static.py

echo "[2/5] Build attempt"
set +e
./scripts/build.sh --print-config
BUILD_RC=$?
set -e

if [[ $BUILD_RC -eq 0 && -f "$MOD_ROOT/dist/StandPrototype.pak" ]]; then
  echo "[3/5] SUCCESS: dist/StandPrototype.pak produced"
  if [[ $NO_INSTALL -eq 0 ]]; then
    echo "[4/5] Install"
    if [[ -n "${BG3_DATA_ROOT:-}" && -d "${BG3_DATA_ROOT}/Data" ]]; then
      ./scripts/install.sh --symlink
    else
      echo "Skipping install: BG3_DATA_ROOT missing or not mounted with Data/."
    fi
  else
    echo "[4/5] Install skipped (--no-install)"
  fi
  echo "[5/5] Modsettings snippet"
  ./scripts/print_modsettings_snippet.sh
  exit 0
fi

echo "[3/5] Packaging failed (exit $BUILD_RC). Preserving staged layout."
mkdir -p dist/.build_stage/Mods/StandPrototype
cp -f meta.lsx dist/.build_stage/Mods/StandPrototype/meta.lsx
if [[ -d Public ]]; then
  rm -rf dist/.build_stage/Public
  cp -a Public dist/.build_stage/Public
fi
if [[ -d ScriptExtender ]]; then
  rm -rf dist/.build_stage/ScriptExtender
  cp -a ScriptExtender dist/.build_stage/ScriptExtender
fi
if [[ -d Assets ]]; then
  rm -rf dist/.build_stage/Assets
  cp -a Assets dist/.build_stage/Assets
fi
if [[ -d Localization ]]; then
  rm -rf dist/.build_stage/Localization
  cp -a Localization dist/.build_stage/Localization
fi

if [[ $NO_INSTALL -eq 0 ]]; then
  echo "[4/5] Install"
  if [[ -n "${BG3_DATA_ROOT:-}" && -d "${BG3_DATA_ROOT}/Data" ]]; then
    ./scripts/install.sh --symlink
  else
    echo "Skipping install: BG3_DATA_ROOT missing or not mounted with Data/."
  fi
else
  echo "[4/5] Install skipped (--no-install)"
fi

echo "[5/5] Modsettings snippet"
./scripts/print_modsettings_snippet.sh

if [[ -d "$MOD_ROOT/dist/.build_stage" ]]; then
  if [[ $ALLOW_STAGED -eq 1 ]]; then
    echo "PARTIAL: staging ready, .pak blocked by Divine"
    echo "Staged path: $MOD_ROOT/dist/.build_stage"
    exit 0
  fi
  echo "PARTIAL: staging ready, .pak blocked by Divine"
  echo "Staged path: $MOD_ROOT/dist/.build_stage"
  exit 2
fi

echo "FAIL: neither .pak nor staging output available"
exit 3
