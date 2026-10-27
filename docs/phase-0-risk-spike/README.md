# Phase 0: Risk spike

## Goal

Prove that a native macOS app can play SFTP media through libmpv before building any product UI. The
spike (`Sources/Spike`) is throwaway; its useful parts moved into `Core` and `SFTPPlayer`.

## Requirements

| ID | Requirement | Pass criteria |
|---|---|---|
| P0-1 | Embedding: mpv renders into an app window | Video draws, resizes cleanly, fullscreen works, and a SwiftUI controls overlay is visible above the video |
| P0-2 | Throughput: remote playback keeps up with the bitrate | A 1080p remote MKV plays in real time with a growing cache; compared against direct `sftp://` through FFmpeg's libssh reader |
| P0-3 | Seeking: arbitrary seeks work on MKV and MP4 | mpv's range requests (start, tail index, mid-file) are served correctly and the bytes match the server's |
| P0-4 | Authentication: key auth works and secrets stay out of logs | Key auth succeeds; credentials never appear in argv, mpv logs, or the proxy log |
| P0-5 | Go/no-go | If P0-1 or P0-2 fails, stop and revisit before Phase 1 |

## Outcome

**Go.** Direct `sftp://` playback failed P0-2, so the plan's fallback was taken: a local pipelined proxy.

| Check | Result |
|---|---|
| P0-1 Embedding | Passed. Needs `mpv_render_context_update()` before every render (ADVANCED_CONTROL), and a layer-backed `NSOpenGLView` so SwiftUI controls composite above the video |
| P0-2 Throughput | Direct `sftp://`: cache stayed under about 5 s (under 3 MB); 38 s of video played in 60 s. Through the proxy: cache reached 512 MiB in about 25 s; about 56 s played in 60 s. Cache tuning alone did not help, because FFmpeg's libssh reader issues one read at a time |
| P0-3 Seeking | Range requests (`0..`, a tail read, `6507992..`) were served; six concurrent 1 MiB ranges matched the server's bytes (MD5), including one at the very end of the file. Interactive seeking was not separately confirmed |
| P0-4 Auth | Key auth verified live. The proxy logs only byte ranges and failure reasons; mpv receives a loopback `http://` URL with no credentials. Password auth is built (Phase 1) but not yet verified live |

## Design decisions that came out of the spike

- **Loopback HTTP proxy** (`SFTPProxy`) reads with up to 32 requests of 64 KiB in flight and serves HTTP
  byte ranges. mpv opens `http://127.0.0.1:<port>/<token>/<encoded path>` instead of `sftp://`.
- **Session pool** (`SFTPSessionPool`): at most 3 sessions per server (seedboxes limit logins); sessions
  are reused, drained after aborted streams, and discarded if broken; connects retry with backoff, but
  host-key and authentication failures never retry.
- **Shutdown order**: free the render context before `mpv_terminate_destroy`; quit the app when the last
  window closes, or audio keeps playing.
