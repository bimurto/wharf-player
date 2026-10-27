# P2-05: Ad-hoc code signing

**Status:** Todo  
**Requirements:** P2-5  
**Depends on:** P2-03  

## What

Sign the bundle and its libraries.

## Acceptance criteria

- [ ] `codesign --verify --deep` passes
- [ ] First launch works after the Gatekeeper right-click Open
- [ ] Every bundled `.dylib` is signed

## Notes

Matches the Electron build's `identity: "-"`.
