# P0-01: Embed mpv in a window

**Status:** Done  
**Requirements:** P0-1  
**Commits:** aa20ae3, f6def21  

## What

Render libmpv output into an app window through the render API, with SwiftUI controls above it.

## Acceptance criteria

- [x] Video draws and resizes cleanly; fullscreen works
- [x] mpv advances: `mpv_render_context_update()` is called before every render (ADVANCED_CONTROL)
- [x] A SwiftUI controls overlay is visible above the video (layer-backed `NSOpenGLView`)

## Notes

Confirmed by eye in the spike and again in the SwiftUI app.
