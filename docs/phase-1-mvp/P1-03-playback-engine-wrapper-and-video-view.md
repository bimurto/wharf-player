# P1-03: Playback engine wrapper and video view

**Status:** Done  
**Requirements:** P1-P1  
**Commits:** f6def21  
**Depends on:** P0-01  

## What

`MPVPlayer` owns the libmpv handle and publishes state; `MPVVideoView` renders it.

## Acceptance criteria

- [x] Position, duration, pause, volume, speed and title are observable
- [x] load (with a start position), seek, pause, volume and speed commands work
- [x] Playback errors are reported
- [x] Shutdown frees the render context before the handle
