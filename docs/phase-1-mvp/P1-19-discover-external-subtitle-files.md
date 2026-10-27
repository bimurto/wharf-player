# P1-19: Discover external subtitle files

**Status:** Todo  
**Requirements:** P1-T2  
**Depends on:** P1-02  

## What

Find subtitle files beside the video and in `Subs`, `Subtitles` and `Sub` folders.

## Acceptance criteria

- [ ] Matching is a pure function: filename-prefix matches first, then others
- [ ] Supports SRT, VTT, ASS and SSA
- [ ] Lists the video's folder and the three subfolders without failing when one is missing
- [ ] Unit tests for matching and ordering
