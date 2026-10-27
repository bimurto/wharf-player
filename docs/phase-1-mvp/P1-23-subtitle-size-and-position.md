# P1-23: Subtitle size and position

**Status:** Built, needs manual check  
**Requirements:** P1-T5  
**Depends on:** P1-17  

## What

Control caption size and vertical position, saved between launches.

## Acceptance criteria

- [ ] Text size 75% to 200% (`sub-scale`); vertical position down/up (`sub-pos`)
- [ ] Slider plus smaller/bigger and down/up buttons
- [ ] Values persist in `UserDefaults` and apply to every track, including external files
- [ ] Reset restores 100% and the default position without changing track or sync

## Notes

Electron allowed captions down to a 16 px bottom margin for fullscreen.
