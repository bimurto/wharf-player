# P1-27: Library table columns

**Status:** Built, needs manual check  
**Requirements:** P1-L9  
**Depends on:** P1-02, P1-10  

## What

The Library shows a table with Name, Size and Updated columns. Clicking a header sorts by that column, and a second click reverses it. The headers replace the sort menu. A single click still opens a folder or plays a video.

## Acceptance criteria

- [ ] (manual) Name, Size and Updated columns show; folders show `—` for size
- [ ] (manual) Each header sorts, a second click reverses, and folders stay on top
- [ ] (manual) The last chosen sort is restored after relaunch
- [ ] (manual) A single click opens a folder or plays a video; non-video files are dimmed and do nothing
- [x] Size sort and the column/direction mapping are pure functions with unit tests
