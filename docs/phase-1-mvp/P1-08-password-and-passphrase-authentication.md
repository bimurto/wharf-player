# P1-08: Password and passphrase authentication

**Status:** Done  
**Requirements:** P1-S1  
**Commits:** 99d6e0f  
**Depends on:** P1-01  

## What

Support account passwords and encrypted keys in the connection layer.

## Acceptance criteria

- [x] `SFTPTarget` carries a password or key passphrase; password auth is used when a password is set
- [x] 15 s connect timeout; user's ssh config is ignored for the same behaviour on every machine
- [x] Unit tests for target construction

## Notes

Live verification is a separate ticket: P1-13.
