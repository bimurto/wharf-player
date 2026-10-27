# P1-16: Merge duplicate recents

**Status:** Todo  
**Requirements:** P1-R5  
**Depends on:** P1-06  

## What

Entries stored by an older build with an explicit `:22` show the same file twice.

## Acceptance criteria

- [ ] Normalize the default port when recording and looking up
- [ ] Existing duplicates are merged on load, keeping the newest position
- [ ] Unit test with a `:22` and a portless URL for the same file
