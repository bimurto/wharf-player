# P2-07: DMG

**Status:** Done  
**Requirements:** P2-7  
**Depends on:** P2-05  

## What

Package the app as a disk image.

## Acceptance criteria

- [x] Output named `Wharf-<version>-<arch>.dmg` (owner chose the Wharf name over the original `SFTP-Media-Player-<version>-<arch>.dmg`), e.g. `build/Wharf-1.0.0-arm64.dmg`, with a `.sha256` next to it
- [x] Mounting and dragging to Applications works (owner-confirmed). Mounting read-only, the `Applications` symlink, `codesign --verify --deep --strict` and `scripts/verify-bundle.sh` on the mounted app were checked.

## Implementation

`scripts/build-dmg.sh` runs `scripts/build-app.sh`, stages `build/dmg-staging/` (Wharf.app via `ditto`, plus an `Applications` symlink), runs `hdiutil create -volname Wharf -format UDZO`, removes the staging folder, and writes `build/Wharf-<version>-<arch>.dmg.sha256` with `shasum -a 256`. Version comes from `VERSION`, arch from `uname -m`. No Finder window layout.

**Signing:** the app inside is ad-hoc signed only; the image is not signed or notarised. Other Macs show a Gatekeeper warning. Use right-click then Open, or run `xattr -dr com.apple.quarantine /Applications/Wharf.app`.
