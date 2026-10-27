# P1-02: Remote directory listing, sorting and search

**Status:** Done  
**Requirements:** P1-L1, P1-L2, P1-L3  
**Commits:** f61ce82  
**Depends on:** P0-05  

## What

List a remote folder over libssh and provide sorting and filtering as pure functions.

## Acceptance criteria

- [x] Entries carry name, folder flag, size and modified date; symlinked folders show as folders
- [x] Sort by name (natural order) or last updated, both directions; folders first; undated last
- [x] Case-insensitive search by name
- [x] The server resolves `.` to an absolute path for breadcrumbs
- [x] Unit tests for ordering, search, breadcrumbs and video detection
