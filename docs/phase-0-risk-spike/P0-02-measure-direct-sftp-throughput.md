# P0-02: Measure direct sftp:// throughput

**Status:** Done  
**Requirements:** P0-2  
**Commits:** c895af5  
**Depends on:** P0-01  

## What

Play a large remote MKV straight through FFmpeg's libssh reader and record cache behaviour.

## Acceptance criteria

- [x] Result recorded with and without cache tuning (`cache`, `demuxer-max-bytes`, `demuxer-readahead-secs`)
- [x] Decision made on whether a fallback is needed

## Notes

Result: cache stayed under about 5 s, 38 s played in 60 s. Cache tuning did not help, so the proxy fallback was needed.
