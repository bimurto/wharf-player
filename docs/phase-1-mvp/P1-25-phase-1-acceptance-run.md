# P1-25: Phase 1 acceptance run

**Status:** Partly run (live, key auth)  
**Requirements:** All  
**Depends on:** P1-13 to P1-24  

## What

End-to-end check against a real server before moving on.

## Acceptance criteria

- [ ] Add a server, trust its key, browse, play from the Library — browse and play verified by URL; saved-server and password paths not run
- [x] Quit mid-video, reopen, resume from Recents (saved 3:55, resumed 4:01)
- [ ] Use subtitles: track, delay, size, position, an external file — track on/off and size menu verified; delay, position, external file, caption rendering under changes not run
- [x] No errors, no secrets in logs; `swift test` passes (89 tests; app stdout/stderr logs were empty of credentials)

## Notes

Keep fixture checks separate from live remote playback when reporting results.
