# P1-25: Phase 1 acceptance run

**Status:** Todo  
**Requirements:** All  
**Depends on:** P1-13 to P1-24  

## What

End-to-end check against a real server before moving on.

## Acceptance criteria

- [ ] Add a server, trust its key, browse, play from the Library
- [ ] Quit mid-video, reopen, resume from Recents
- [ ] Use subtitles: track, delay, size, position, an external file
- [ ] No errors, no secrets in logs; `swift test` passes

## Notes

Keep fixture checks separate from live remote playback when reporting results.
