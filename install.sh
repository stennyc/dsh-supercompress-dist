#!/bin/sh
# dsh-supercompress public installer (unix): fetch the current platform's
# tarball from the dist repo's releases branch, verify the checksum, extract.
# Then follow the README's install step in your DSH host (profile dir / the
# dsh CLI).
#
# Usage: install.sh [version]
#   (no arg)      the newest version on the releases branch
#   install.sh 0.1.0     that exact version
#
# Note: the package itself carries NO install scripts (the security posture —
# the host side executes nothing beyond the normal plugin load). This script
# only fetches + verifies + extracts; the host wiring is yours (README).
set -eu
BASE="https://raw.githubusercontent.com/stennyc/dsh-supercompress-dist/releases"
ARG="${1:-}"
VER="$ARG"

if [ -z "$VER" ]; then
  # the newest version line on the branch (any target's row; every version
  # ships all four targets).
  VER=$(curl -fsSL "$BASE/SHA256SUMS" | sed -n 's/^.* dsh-supercompress-\([0-9][0-9.]*\)-\(linux-x64\|linux-arm64\|darwin-x64\|darwin-arm64\)\.tar\.gz$/\1/p' | sort -u | tail -1)
fi
[ -n "$VER" ] || { echo "no version found on the releases branch" >&2; exit 1; }

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$OS-$ARCH" in
  linux-x86_64|linux-amd64) TARGET="linux-x64" ;;
  linux-aarch64|linux-arm64) TARGET="linux-arm64" ;;
  darwin-x86_64|darwin-amd64) TARGET="darwin-x64" ;;
  darwin-arm64) TARGET="darwin-arm64" ;;
  *) echo "unsupported platform: $OS-$ARCH (the releases branch ships: linux-x64, linux-arm64, darwin-x64, darwin-arm64; Windows is not supported — the daemon uses syscall.Flock, Unix-only)" >&2; exit 1 ;;
esac

F="dsh-supercompress-$VER-$TARGET.tar.gz"
echo "installing $F"
curl -fL -o "$F" "$BASE/$F"
curl -fL -o SHA256SUMS "$BASE/SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
  grep " $F$" SHA256SUMS | sha256sum -c -
else
  WANT=$(grep " $F$" SHA256SUMS | cut -d' ' -f1)
  GOT=$(shasum -a 256 "$F" | cut -d' ' -f1)
  [ "$WANT" = "$GOT" ] || { echo "CHECKSUM MISMATCH for $F" >&2; exit 1; }
  echo "$F: checksum ok"
fi
rm -f SHA256SUMS
tar -xzf "$F"
rm -f "$F"
DIR="dsh-supercompress-$VER"
echo ""
echo "extracted: $(pwd)/$DIR"
echo ""
echo "next (in your DSH host): add the extracted directory as a file: dependency in your profile's package.json:"
echo "  cd <your-dsh-profile-dir>"
echo "  pnpm add $(pwd)/$DIR"
echo "or, on a dsh-Go host:  dsh plugin --profile <your-app-profile> add $(pwd)/$DIR"
echo "then reload the plugin (desktop: restart the DSH host process)."
