# P2-01: Real app bundle

**Status:** Built, needs manual check  
**Requirements:** P2-1  
**Depends on:** P1-25  

## What

Build `Wharf.app` with `Info.plist`, bundle identifier, version and the existing icon.

## Acceptance criteria

- [ ] Launches from Finder with a Dock icon and menu bar
- [ ] No `setActivationPolicy` workaround needed
- [ ] Icon reused from the Electron repo's `icon.icns`

## Notes

Choose the bundle identifier before saving real user data to it.

## Implementation

- `scripts/build-app.sh` builds release and assembles `build/Wharf.app`.
- Version: `VERSION` file (single source). Bundle id: `io.bimurto.wharf` (`BUNDLE_ID` env override; confirm in P2-06 before saving real data).
- Icon: copied from the Electron repo's `build/icon.icns`.
- Still links Homebrew libmpv/libssh (P2-02/03).
- `setActivationPolicy(.regular)` kept in `App.swift` until a Finder launch is confirmed and `swift run` is rechecked.
