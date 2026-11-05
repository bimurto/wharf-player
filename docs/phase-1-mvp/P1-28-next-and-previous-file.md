# P1-28: Next and previous file

**Status:** Built, needs manual check  
**Requirements:** P1-P7  
**Depends on:** P1-03, P1-10  

## What

Previous and Next buttons sit on either side of play/pause, and the P and N keys do the same. They play the neighbouring video in the playing file's folder, in natural name order, so a series named `1, 2, 10` or `S01E09, S01E10` plays in order. The Library's sort, search and current folder don't affect them.

## Acceptance criteria

- [ ] (manual) From `S01E09.mkv`, Next plays `S01E10.mkv` and Previous goes back
- [ ] (manual) The buttons are disabled at the first and last video, and their tooltips name the target file
- [ ] (manual) Next still follows the playing video's folder after the Library browses elsewhere
- [x] Neighbour lookup is a pure function with unit tests (natural order, ends, non-videos skipped)
- [x] A slow listing for an older video never sets the buttons for a newer one
