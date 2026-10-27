# P1-01: Connection profiles and Keychain secrets

**Status:** Done  
**Requirements:** P1-S1, P1-S2  
**Commits:** 86296e9  

## What

Model saved servers and store passwords and passphrases in the Keychain, not in profile JSON.

## Acceptance criteria

- [x] `ConnectionProfile` holds label, host, port, user, password or key auth, default directory
- [x] `ProfileStore` saves, replaces by id and deletes; deleting also removes the secret
- [x] A nil secret keeps the stored one; an empty one clears it
- [x] `url(path:)` never contains credentials
- [x] Unit tests, including a real Keychain round trip under a throwaway service name
