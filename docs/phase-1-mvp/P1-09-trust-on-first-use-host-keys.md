# P1-09: Trust-on-first-use host keys

**Status:** Done  
**Requirements:** P1-S6  
**Commits:** 99d6e0f  
**Depends on:** P1-08  

## What

Replace the `known_hosts` requirement with an in-app trust prompt.

## Acceptance criteria

- [x] App-owned known-hosts file under Application Support; `~/.ssh/known_hosts` is never touched
- [x] Unknown host: stop before authenticating and show the SHA256 fingerprint with Trust and Cancel
- [x] Trust re-checks the fingerprint matches what was shown before saving it
- [x] Changed key: refuse with no override; Forget Host Key in the server editor resets it
- [x] Verified live against the seedbox, including a corrupted key

## Notes

Not in the original plan; added because requiring `ssh` first was unacceptable.
