# P1-19: Discover external subtitle files

**Status:** Built, needs manual check  
**Requirements:** P1-T2  
**Depends on:** P1-02  

## What

Find subtitle files beside the video and in `Subs`, `Subtitles` and `Sub` folders.

## Acceptance criteria

- [x] Matching is a pure function: filename-prefix matches first, then others
- [x] Supports SRT, VTT, ASS and SSA
- [x] Lists the video's folder and the three subfolders without failing when one is missing
- [x] Unit tests for matching and ordering
