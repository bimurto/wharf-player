# P1-24: Guard against stale subtitle discovery

**Status:** Done  
**Requirements:** P1-T6  
**Depends on:** P1-19, P1-20  

## What

A slow discovery result must not override the user's choice.

## Acceptance criteria

- [x] Results from a previous video are ignored after another video starts
- [x] A track chosen by the user during discovery is preserved
- [x] Unit test with a fake lister that delays one response
