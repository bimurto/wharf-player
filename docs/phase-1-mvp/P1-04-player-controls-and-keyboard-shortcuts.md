# P1-04: Player controls and keyboard shortcuts

**Status:** Done  
**Requirements:** P1-P1, P1-P2, P1-P3  
**Commits:** f6def21, 4554fd5  
**Depends on:** P1-03  

## What

A control bar over the video, plus keyboard control.

## Acceptance criteria

- [x] Play/pause, seek slider (commits on release), volume to 130%, speed menu, fullscreen
- [x] Space, left/right (10 s; 60 s with Shift), up/down volume, F or double-click fullscreen
- [x] Controls hide after 2.8 s of no mouse movement while playing; stay while paused or before media loads
- [x] Controls reappear on mouse movement, including after the sidebar closes (own tracking area)

## Notes

Two bugs fixed here: idle window showed nothing, and SwiftUI hover went stale after a layout change.
