# P2-06: Bundle identifier for stored data

**Status:** Todo  
**Requirements:** P2-6  
**Depends on:** P2-01, P2-05  

## What

Make `UserDefaults` and the Keychain stable across rebuilds.

## Acceptance criteria

- [ ] Profiles and recents live under the bundle identifier's defaults domain
- [ ] Existing saved servers from `swift run` (domain `SFTPPlayer`) migrate once
- [ ] Keychain access does not prompt on every rebuild

## Notes

Today the unbundled binary uses a process-name domain and may re-prompt for Keychain access.
