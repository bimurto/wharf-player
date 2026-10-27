# P0-05: Session pool, retries and clean shutdown

**Status:** Done  
**Requirements:** P0-2, P0-4  
**Commits:** c895af5  
**Depends on:** P0-03  

## What

Make the proxy robust enough for real use.

## Acceptance criteria

- [x] At most 3 sessions per server; sessions are reused and drained after aborted streams
- [x] Connect failures retry with backoff; host-key and authentication failures never retry
- [x] Errors name the failing step
- [x] Closing the last window quits the app and frees the render context before mpv

## Notes

Found by testing: audio kept playing after the window closed, and a `break` inside a `switch` did not leave the retry loop.
