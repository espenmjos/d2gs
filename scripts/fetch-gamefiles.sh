#!/bin/sh
# Downloads the D2GS server binaries and Diablo II game files into a directory.
# Files that already exist are kept; everything is verified against gamefiles.md5.
#
#   scripts/fetch-gamefiles.sh [dir]     (default: ./gamefiles)
set -eu

DIR="${1:-gamefiles}"
CDN="${CDN:-http://cdn.pvpgn.pro/diablo2}"
MAGIC_BUILDER_VERSION="${MAGIC_BUILDER_VERSION:-2.29}"
SUMS="$(cd "$(dirname "$0")" && pwd)/gamefiles.md5"

mkdir -p "$DIR"
cd "$DIR"

fetch() {  # fetch URL FILE
  [ -s "$2" ] && return 0
  echo "Downloading $2"
  wget -q -O "$2.part" "$1" && mv "$2.part" "$2"
}

# D2GS 1.13d server binaries from PvPGN Magic Builder
if [ ! -s D2GS.exe ]; then
  echo "Downloading D2GS from pvpgn-magic-builder $MAGIC_BUILDER_VERSION"
  wget -q -O- "https://github.com/pvpgn/pvpgn-magic-builder/archive/v${MAGIC_BUILDER_VERSION}.tar.gz" \
    | tar xz --strip-components=5 \
        "pvpgn-magic-builder-${MAGIC_BUILDER_VERSION}/module/include/d2gs/1.13d"
  rm -f d2gs.reg d2gs_install.bat d2gs_uninstall.bat
fi

for f in D2Client.dll D2CMP.dll D2Common.dll D2Game.dll D2gfx.dll D2Lang.dll \
         D2MCPClient.dll D2Net.dll D2sound.dll D2Win.dll Fog.dll Storm.dll; do
  fetch "$CDN/1.13d/$f" "$f"
done
fetch "$CDN/1.14d/Patch_D2.mpq" Patch_D2.mpq
fetch "$CDN/1.14d/ijl11.dll"    ijl11.dll
for f in d2data.mpq d2exp.mpq d2sfx.mpq d2speech.mpq; do
  fetch "$CDN/$f" "$f"
done

echo "Verifying checksums"
md5sum --quiet -c "$SUMS"
echo "Game files OK in $DIR"
