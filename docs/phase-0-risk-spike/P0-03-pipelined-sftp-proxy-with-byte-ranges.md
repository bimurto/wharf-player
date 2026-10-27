# P0-03: Pipelined SFTP proxy with byte ranges

**Status:** Done  
**Requirements:** P0-2, P0-3  
**Commits:** aa20ae3, c895af5  
**Depends on:** P0-02  

## What

Serve one remote file over loopback HTTP, keeping up to 32 reads of 64 KiB in flight.

## Acceptance criteria

- [x] Cache fills well ahead of playback (reached 512 MiB in about 25 s)
- [x] `Range` requests (start, tail, mid-file, open-ended) return correct 206 responses
- [x] Six concurrent 1 MiB ranges are byte-identical to the server's data (MD5)
- [x] A client that disconnects mid-stream stops the read and leaves the session reusable
