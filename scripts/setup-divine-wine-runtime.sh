#!/usr/bin/env bash
set -euo pipefail

# Installs Wine runtime dependencies so Divine.exe can run when dll backend is broken.

usage() {
  cat <<USAGE
Usage: $0 [--wineprefix PATH]

Installs .NET Desktop Runtime 8 in Wine for Divine.exe fallback backend.

Options:
  --wineprefix PATH   Wine prefix (default: ~/.wine-divine)
USAGE
}

WINEPREFIX_PATH="$HOME/.wine-divine"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wineprefix)
      WINEPREFIX_PATH="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if ! command -v pacman >/dev/null 2>&1; then
  echo "This script targets Arch Linux." >&2
  exit 1
fi

echo "Installing Wine helper dependencies..."
sudo pacman -Sy --needed --noconfirm wine winetricks cabextract p7zip unzip

export WINEPREFIX="$WINEPREFIX_PATH"
export WINEARCH=win64

if [[ ! -d "$WINEPREFIX" ]]; then
  echo "Initializing Wine prefix: $WINEPREFIX"
  wineboot -u
fi

echo "Installing .NET Desktop Runtime 8 via winetricks..."
# Prefer desktop runtime; if unavailable in current winetricks, fall back to dotnet8 runtime.
if ! winetricks -q dotnetdesktop8; then
  echo "dotnetdesktop8 failed or unavailable, trying dotnet8..."
  winetricks -q dotnet8
fi

echo ""
echo "Wine runtime setup complete."
echo "Use build with:"
echo "  WINEPREFIX=$WINEPREFIX DIVINE_BACKEND=wine ./scripts/build.sh"
