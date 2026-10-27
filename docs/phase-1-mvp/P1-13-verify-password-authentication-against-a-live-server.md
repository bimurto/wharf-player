# P1-13: Verify password authentication against a live server

**Status:** Partly verified (owner reported it works)  
**Requirements:** P1-S7  
**Depends on:** P1-08  

## What

Password auth is implemented but has never run against a real server.

## Acceptance criteria

- [x] Add a password-auth server, Test Connection succeeds (owner-confirmed)
- [x] Browse and play a video using it (owner-confirmed)
- [ ] Wrong password fails once with a clear message and is not retried
- [ ] The password never appears in logs or in stored JSON

## Notes

Needs a server and password the owner is willing to use for testing.
