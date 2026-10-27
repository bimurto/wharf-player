# P1-05: Open media by URL

**Status:** Done  
**Requirements:** P1-P4, P1-P5  
**Commits:** f6def21, 99d6e0f  
**Depends on:** P1-03  

## What

A sheet that opens `sftp://user@host/path` with a key file or a matching saved server's credentials.

## Acceptance criteria

- [x] Bad input shows a clear message; passwords in URLs are rejected
- [x] A saved server with the same host, port and user supplies its credentials
- [x] Playback failures are shown, not silent
- [x] Opening connects once first so host-key and login problems appear before playback
