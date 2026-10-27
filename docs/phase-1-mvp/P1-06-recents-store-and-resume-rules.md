# P1-06: Recents store and resume rules

**Status:** Done  
**Requirements:** P1-R1, P1-R2, P1-R3  
**Commits:** 56ac02a  

## What

Keep up to 20 recent videos with progress and decide where to resume.

## Acceptance criteria

- [x] Newest first, one entry per URL, capped at 20
- [x] Passwords stripped from URLs when storing and looking up
- [x] No resume under 5 s, within the last 10 s, or with unknown duration
- [x] Unit tests for all of the above
