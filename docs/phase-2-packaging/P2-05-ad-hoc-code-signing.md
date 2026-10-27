# P2-05: Ad-hoc code signing

**Status:** Done  
**Requirements:** P2-5  
**Depends on:** P2-03  

## What

Sign the bundle and its libraries.

## Acceptance criteria

- [x] `codesign --verify --deep` passes (scripts/verify-bundle.sh)
- [x] First launch works after the Gatekeeper right-click Open (owner-confirmed)
- [x] Every bundled `.dylib` is signed (scripts/relocate-libs.sh, checked by verify-bundle.sh)

## Notes

Matches the Electron build's `identity: "-"`.
