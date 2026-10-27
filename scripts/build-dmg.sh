#!/bin/zsh
# Builds Wharf.app (scripts/build-app.sh) and packages it as "build/Wharf-<version>-<arch>.dmg"
# plus a ".sha256" file. Uses only hdiutil/ditto/shasum. Image is ad-hoc signed app, unnotarised.
# Usage: scripts/build-dmg.sh
set -euo pipefail
cd "${0:A:h}/.."

NAME="Wharf"
VERSION="$(<VERSION)"
ARCH="$(uname -m)"
[[ $ARCH == aarch64 ]] && ARCH="arm64"
STAGE="build/dmg-staging"
DMG="build/$NAME-$VERSION-$ARCH.dmg"

scripts/build-app.sh

# Only ever delete this script's own staging folder and previous outputs.
rm -rf "$STAGE"
rm -f "$DMG" "$DMG.sha256"
mkdir -p "$STAGE"
ditto "build/$NAME.app" "$STAGE/$NAME.app"   # ditto keeps the code signature intact
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "$NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
rm -rf "$STAGE"

( cd build && shasum -a 256 "${DMG:t}" > "${DMG:t}.sha256" )
echo "Built $DMG"
cat "$DMG.sha256"
