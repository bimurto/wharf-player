# P1-11: Library state: folder memory and stale responses

**Status:** Done  
**Requirements:** P1-L4, P1-L5, P1-L6  
**Commits:** 4554fd5  
**Depends on:** P1-10  

## What

`LibraryModel` keeps sort, search and folder across navigation and playback.

## Acceptance criteria

- [x] Re-attaching the same server keeps folder, listing and search and does not reload
- [x] A different server starts at its home folder; switching back restores its last folder
- [x] A slow older response never overwrites a newer one
- [x] A failed listing keeps its host-key issue so the trust dialog can show
- [x] Seven unit tests with a fake directory lister
