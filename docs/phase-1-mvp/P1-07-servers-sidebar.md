# P1-07: Servers sidebar

**Status:** Done  
**Requirements:** P1-S1, P1-S3, P1-S4, P1-S5  
**Commits:** 99d6e0f  
**Depends on:** P1-01  

## What

Add, edit, delete and use saved servers from the sidebar.

## Acceptance criteria

- [x] Add/Edit sheet with label, host, port, user, password or key, passphrase, default directory
- [x] Blank secret on edit keeps the saved one; switching auth type clears it
- [x] Test Connection reports the real failure or the entry count
- [x] Delete asks first and removes the Keychain item
- [x] Use makes the server current and opens the Library at its default directory
