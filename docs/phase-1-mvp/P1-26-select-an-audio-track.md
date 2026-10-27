# P1-26: Select an audio track

**Status:** Built, needs manual check  
**Requirements:** P1-T1  
**Depends on:** P1-03, P1-06  

## What

When a file has more than one audio track, a control-bar menu picks which one plays. The choice is remembered per file in Recents.

## Acceptance criteria

- [ ] (manual) The audio button appears only when the file has 2 or more audio tracks
- [ ] (manual) Choosing a track changes the sound and moves the checkmark
- [ ] (manual) Reopening the file from Recents plays the track last chosen
- [x] Parsing of `track-list` audio entries is a pure function with unit tests
- [x] Recents entries saved before this change still load
