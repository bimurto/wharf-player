# P1-17: Subtitle menu shell and track list

**Status:** Todo  
**Requirements:** P1-T1  
**Depends on:** P1-03  

## What

Add a subtitle button to the controls and list tracks from mpv's `track-list`.

## Acceptance criteria

- [ ] Menu shows embedded subtitle tracks with language and title, plus Off
- [ ] Track count shown; empty state when there are none
- [ ] List updates when a new file loads
- [ ] Parsing of `track-list` is a pure function with unit tests

## Notes

mpv already draws the default subtitle track, so this adds control only.
