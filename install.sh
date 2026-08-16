#!/usr/bin/env sh
set -eu

VERSION="${1:-${RESGR_LATEST_VERSION:-latest}}"
BINDIR="/usr/local/bin"

case "$(uname -s)" in Linux) os=linux ;; Darwin) os=macos ;; *) exit 1 ;; esac
case "$(uname -m)" in x86_64|amd64) arch=x86_64 ;; arm64|aarch64) arch=aarch64 ;; *) exit 1 ;; esac

if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/iiojib/resgr/releases/latest/download/resgr-${arch}-${os}.tar.gz"
else
  URL="https://github.com/iiojib/resgr/releases/download/v${VERSION#v}/resgr-${arch}-${os}.tar.gz"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' 0
curl -fsSL "$URL" -o "$tmp/resgr.tar.gz"
tar -xzf "$tmp/resgr.tar.gz" -C "$tmp"

if ! { [ -w "$BINDIR" ] || { [ ! -e "$BINDIR" ] && [ -w "$(dirname "$BINDIR")" ]; }; }; then
  BINDIR="$HOME/.local/bin"
fi

mkdir -p "$BINDIR"
cp "$tmp/resgr" "$BINDIR/resgr"

echo "installed resgr ${VERSION#v} to ${BINDIR}/resgr"
if [ "$BINDIR" = "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "add $HOME/.local/bin to PATH" ;;
  esac
fi
