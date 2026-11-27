#!/bin/sh
# dsh-supercompress public installer (unix): fetch the current platform's
# tarball from the dist repo's releases branch, verify the checksum, extract.
# Then follow the README's install step in your DSH host (profile dir / the
# dsh CLI).
#
# Usage: install.sh [version] [variant]
#   (no args)        newest version, the host-generation-matched variant
#   install.sh 0.2.0 that exact version, auto-detected variant
#   install.sh 0.2.0 rc1host   force the RC1HOST variant (the rc.1 phone host)
#   install.sh 0.2.0 full      force the FULL variant (the rc.5+ host)
#
# VARIANT (host generation): the 0.2.0+ dist ships two host-generation builds
# (the dsh-tools export + the llm/tokenMeter DI tokens differ between the rc.1
# phone host and the rc.5+ host). Auto-detect: read the local DSH host version
# (`dsh --version`), the rc generation < 5 -> rc1host, else full. Pass the
# second arg to override (the phone proot where `dsh` is not on PATH: the
# default falls back to full — pass `rc1host` explicitly there).
#
# Note: the package itself carries NO install scripts (the security posture —
# the host side executes nothing beyond the normal plugin load). This script
# only fetches + verifies + extracts; the host wiring is yours (README).
set -eu
BASE="https://raw.githubusercontent.com/stennyc/dsh-supercompress-dist/releases"
ARG_VER="${1:-}"
ARG_VARIANT="${2:-}"
VER="$ARG_VER"

if [ -z "$VER" ]; then
  # the newest version line on the branch (any target / any variant's row;
  # every version ships all four targets x both variants).
  VER=$(curl -fsSL "$BASE/SHA256SUMS" \
    | sed -n 's/.* dsh-supercompress-\([0-9][0-9.]*\)-\(full\|rc1host\)-\(linux-x64\|linux-arm64\|darwin-x64\|darwin-arm64\)\.tar\.gz$/\1/p' \
    | sort -u | tail -1)
fi
[ -n "$VER" ] || { echo "no version found on the releases branch" >&2; exit 1; }

# ── the host-generation variant ──────────────────────────────────────────────
VARIANT="$ARG_VARIANT"
if [ -z "$VARIANT" ]; then
  # auto-detect from the local DSH host version: the rc generation < 5 = the
  # rc.1 phone host -> rc1host; else (rc.5+ / stable) -> full.
  DSHVER="$(dsh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?' | head -1 || true)"
  RCGEN="$(printf '%s' "$DSHVER" | sed -n 's/.*rc\.\([0-9][0-9]*\).*/\1/p')"
  if [ -n "$RCGEN" ]; then
    if [ "$RCGEN" -lt 5 ]; then VARIANT="rc1host"; else VARIANT="full"; fi
  else
    VARIANT="full"   # no detectable rc marker (desktop / stable host default)
    echo "note: could not auto-detect the DSH host generation; defaulting to the FULL variant."
    echo "      on the rc.1 phone host (where `dsh` is not on PATH) run: $0 $VER rc1host"
  fi
fi
[ "$VARIANT" = "full" ] || [ "$VARIANT" = "rc1host" ] \
  || { echo "variant must be 'full' or 'rc1host' (got: $VARIANT)" >&2; exit 1; }

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$OS-$ARCH" in
  linux-x86_64|linux-amd64) TARGET="linux-x64" ;;
  linux-aarch64|linux-arm64) TARGET="linux-arm64" ;;
  darwin-x86_64|darwin-amd64) TARGET="darwin-x64" ;;
  darwin-arm64) TARGET="darwin-arm64" ;;
  *) echo "unsupported platform: $OS-$ARCH (the releases branch ships: linux-x64, linux-arm64, darwin-x64, darwin-arm64; Windows is not supported — the daemon uses syscall.Flock, Unix-only)" >&2; exit 1 ;;
esac

F="dsh-supercompress-$VER-$VARIANT-$TARGET.tar.gz"
echo "installing $F (variant: $VARIANT)"
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
if [ "$VARIANT" = "rc1host" ]; then
  echo ""
  echo "variant note: this is the RC1HOST build (the rc.1 host generation). The LLM + tokenMeter"
  echo "faces run their deterministic floor here — on rc.1 the core window compaction is data-plane"
  echo "only (ledger/recall/drill). For the full feature set, use the FULL variant on an rc.5+ host."
fi
