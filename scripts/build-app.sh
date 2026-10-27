#!/bin/zsh
# Builds the release binary and assembles "build/Wharf.app".
# Usage: scripts/build-app.sh
# Version comes from the VERSION file; override the icon source with ICON_SRC.
set -euo pipefail
cd "${0:A:h}/.."

NAME="Wharf"
EXE="SFTPPlayer"
BUNDLE_ID="${BUNDLE_ID:-io.bimurto.wharf}"
VERSION="$(<VERSION)"
ICON_SRC="${ICON_SRC:-$HOME/Work/personal/vibecoding/sftp-media-player/build/icon.icns}"
APP="build/$NAME.app"
AUTHOR="$(git config user.name)"

swift build -c release --product "$EXE"
BIN="$(swift build -c release --show-bin-path)/$EXE"

rm -rf "build/$NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXE"
cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$NAME</string>
    <key>CFBundleDisplayName</key><string>$NAME</string>
    <key>CFBundleExecutable</key><string>$EXE</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
    <key>NSHumanReadableCopyright</key><string>Copyright (C) 2026 $AUTHOR. Licensed under the GNU General Public License v3.0 or later; see LICENSE. Bundles mpv, FFmpeg and other libraries under their own licences (THIRD-PARTY-NOTICES.md).</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

scripts/bundle-libs.sh "$APP"
# Notices and licences go in before relocate-libs.sh, which signs the finished bundle.
scripts/gen-notices.sh "$APP"
cp LICENSE THIRD-PARTY-NOTICES.md SOURCE-OFFER.md "$APP/Contents/Resources/"
scripts/relocate-libs.sh "$APP"
scripts/verify-bundle.sh "$APP"

plutil -lint "$APP/Contents/Info.plist"
echo "Built $APP"
