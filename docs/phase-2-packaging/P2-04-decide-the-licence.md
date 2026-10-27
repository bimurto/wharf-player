# P2-04: Decide the licence

**Status:** Todo  
**Requirements:** P2-4  

## What

Homebrew's mpv is a GPL build, so bundling it makes the app GPL.

## Acceptance criteria

- [ ] Choose: relicense to GPL-3.0, or build mpv with `-Dgpl=false` and FFmpeg without GPL parts
- [ ] Record the decision in `docs`
- [ ] Ship licence texts and a corresponding-source offer with the app

## Notes

Blocks any public release. Not blocking the first local build.
