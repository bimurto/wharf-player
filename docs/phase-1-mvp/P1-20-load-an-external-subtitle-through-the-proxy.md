# P1-20: Load an external subtitle through the proxy

**Status:** Built, needs manual check  
**Requirements:** P1-T2  
**Depends on:** P1-18, P1-19  

## What

Add a discovered subtitle to mpv.

## Acceptance criteria

- [x] The subtitle is read through the loopback proxy (token URL) and added with `sub-add`
- [x] It appears in the track list and can be selected
- [x] Failure to load shows a message and does not stop playback
