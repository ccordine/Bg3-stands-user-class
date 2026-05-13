#!/usr/bin/env bash
set -euo pipefail

# Arch Linux setup for building BG3 mods with divine.
# Installs system dependencies and downloads divine (LSLib/ExportTool) to ~/.local/share,
# then installs a wrapper at ~/.local/bin/divine.

usage() {
  cat <<USAGE
Usage: $0 [--prefix PATH] [--version TAG]

Options:
  --prefix PATH   Install location for divine binary (default: ~/.local/bin)
  --version TAG   LSLib release tag (default: latest)

Example:
  ./scripts/setup-arch.sh
  ./scripts/setup-arch.sh --prefix /usr/local/bin
USAGE
}

PREFIX="$HOME/.local/bin"
VERSION="latest"
TOOLS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/standprototype-tools/divine"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="${2:-}"; shift 2 ;;
    --version)
      VERSION="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Linux (Arch) only." >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman not found. This script targets Arch Linux." >&2
  exit 1
fi

echo "Installing system dependencies via pacman..."
sudo pacman -Sy --needed --noconfirm \
  base-devel \
  curl \
  wget \
  jq \
  unzip \
  tar \
  git \
  dotnet-runtime \
  dotnet-sdk \
  icu \
  zlib \
  wine

mkdir -p "$PREFIX"

REPO="Norbyte/lslib"
API_URL="https://api.github.com/repos/${REPO}/releases"

if [[ "$VERSION" == "latest" ]]; then
  RELEASE_JSON="$(curl -fsSL "${API_URL}/latest")"
else
  RELEASE_JSON="$(curl -fsSL "${API_URL}/tags/${VERSION}")"
fi

ASSET_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[]?.browser_download_url' | grep -Ei 'divine.*(linux|lin).*(x64|amd64)?.*\.(zip|tar\.gz)$' | head -n1 || true)"
if [[ -z "$ASSET_URL" ]]; then
  ASSET_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[]?.browser_download_url' | grep -Ei 'exporttool.*\.(zip|tar\.gz)$' | head -n1 || true)"
fi
if [[ -z "$ASSET_URL" ]]; then
  ASSET_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[]?.browser_download_url' | grep -Ei '(lslib|divine).*\.(zip|tar\.gz)$' | head -n1 || true)"
fi

if [[ -z "$ASSET_URL" ]]; then
  echo "Could not find a usable divine/exporttool asset in ${REPO} release metadata." >&2
  echo "Open releases and install manually:" >&2
  echo "https://github.com/${REPO}/releases" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ARCHIVE="$TMP_DIR/release_asset"

echo "Downloading divine asset: $ASSET_URL"
curl -fL "$ASSET_URL" -o "$ARCHIVE"

EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR"

if [[ "$ASSET_URL" =~ \.zip$ ]]; then
  unzip -q "$ARCHIVE" -d "$EXTRACT_DIR"
else
  tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"
fi

mkdir -p "$TOOLS_DIR"
rm -rf "$TOOLS_DIR"/*
cp -a "$EXTRACT_DIR"/. "$TOOLS_DIR"/

DIVINE_EXE="$(find "$TOOLS_DIR" -type f -iname 'divine.exe' | head -n1 || true)"
DIVINE_DLL="$(find "$TOOLS_DIR" -type f -iname 'divine.dll' | head -n1 || true)"
DIVINE_NATIVE="$(find "$TOOLS_DIR" -type f -name 'divine' | head -n1 || true)"

if [[ -z "$DIVINE_EXE" && -z "$DIVINE_DLL" && -z "$DIVINE_NATIVE" ]]; then
  echo "Downloaded archive did not contain divine executable artifacts." >&2
  exit 1
fi

TARGET="$PREFIX/divine"
cat > "$TARGET" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
TOOLS_DIR="$TOOLS_DIR"
DIVINE_NATIVE="$DIVINE_NATIVE"
DIVINE_DLL="$DIVINE_DLL"
DIVINE_EXE="$DIVINE_EXE"

BACKEND="\${DIVINE_BACKEND:-auto}" # auto|native|dll|wine

run_native() {
  [[ -n "\$DIVINE_NATIVE" && -x "\$DIVINE_NATIVE" ]] && exec "\$DIVINE_NATIVE" "\$@"
  return 1
}
run_dll() {
  if [[ -n "\$DIVINE_DLL" && -f "\$DIVINE_DLL" ]]; then
    export DOTNET_ROLL_FORWARD=Major
    exec dotnet "\$DIVINE_DLL" "\$@"
  fi
  return 1
}
run_wine() {
  [[ -n "\$DIVINE_EXE" && -f "\$DIVINE_EXE" ]] && exec wine "\$DIVINE_EXE" "\$@"
  return 1
}

case "\$BACKEND" in
  native) run_native "\$@" ;;
  dll) run_dll "\$@" ;;
  wine) run_wine "\$@" ;;
  auto)
    run_native "\$@" || run_dll "\$@" || run_wine "\$@"
    ;;
  *)
    echo "Invalid DIVINE_BACKEND=\$BACKEND (use auto|native|dll|wine)" >&2
    exit 1
    ;;
esac
echo "divine runtime not found under \$TOOLS_DIR" >&2
exit 1
WRAP
chmod +x "$TARGET"

if [[ ":$PATH:" != *":$PREFIX:"* ]]; then
  echo ""
  echo "Add this to your shell rc if needed:"
  echo "export PATH=\"$PREFIX:\$PATH\""
fi

echo ""
echo "Installed divine wrapper to: $TARGET"
"$TARGET" --help >/dev/null 2>&1 || true

echo ""
echo "Dependency check:"
for cmd in divine dotnet jq unzip curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [ok] $cmd -> $(command -v "$cmd")"
  else
    echo "  [missing] $cmd"
  fi
done

echo ""
echo "Next build command:"
echo "  ./scripts/build.sh"
