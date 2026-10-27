# P0-04: Key authentication and secret hygiene

**Status:** Done  
**Requirements:** P0-4  
**Commits:** aa20ae3  
**Depends on:** P0-03  

## What

Authenticate with a key file or ssh-agent and keep secrets out of argv and logs.

## Acceptance criteria

- [x] Key auth works against a real server
- [x] mpv is given a loopback `http://` URL with no credentials
- [x] Proxy logs show only byte ranges and failure reasons

## Notes

Password auth was built later (P1-08) and is not yet verified live (P1-13).
