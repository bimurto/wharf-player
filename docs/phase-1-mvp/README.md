# Phase 1: MVP feature parity

## Goal

Replace the Electron app's behaviour with a native macOS app that wraps libmpv. Playback, decoding,
seeking and subtitle rendering belong to mpv; the app provides connections, browsing, history and controls.
macOS only for this phase.

## Scope

In scope: everything below. Out of scope: Windows and Linux, picture-in-picture (deferred), the Electron
`/remux` and ffprobe paths (not needed with mpv), packaging (see [Phase 2](../phase-2-packaging/README.md)).

## Requirements and status

### Servers

| ID | Requirement | Status |
|---|---|---|
| P1-S1 | Save, edit and delete server profiles: label, host, port, user name, password or key file, optional key passphrase, default directory | Done |
| P1-S2 | Passwords and passphrases live in the Keychain, never in profile JSON, URLs, recents or logs | Done |
| P1-S3 | Test Connection authenticates and lists the default (or home) directory and reports the real failure reason | Done |
| P1-S4 | Use makes a server the current connection and opens the Library at its default directory | Done |
| P1-S5 | Delete asks for confirmation and removes the Keychain item | Done |
| P1-S6 | Trust on first use for host keys: the first connection shows the SHA256 fingerprint and asks; a changed key is refused with no override; Forget Host Key resets it deliberately. Uses an app-owned known-hosts file, never `~/.ssh/known_hosts` | Done (not in the original plan) |
| P1-S7 | Password authentication works against a live server | Success path verified live by the owner; wrong-password behaviour not checked |

### Library

| ID | Requirement | Status |
|---|---|---|
| P1-L1 | Browse remote folders with breadcrumbs (slash-separated, clickable), sizes and dates; symlinked folders show as folders | Done |
| P1-L2 | Sort by name (A–Z, Z–A, natural number order) or last updated (newest, oldest); folders first; entries without a date last within their group | Done |
| P1-L3 | Search filters the loaded folder; Refresh reloads it | Done |
| P1-L4 | Sort and search persist across navigation and refresh in a session | Done |
| P1-L5 | Reopening the Library keeps the last folder per server, including after playback starts | Done |
| P1-L6 | A slow, older listing response never overwrites a newer one | Done (unit tested) |
| P1-L7 | Full filename on hover for truncated names; non-video files dimmed and not clickable | Done |
| P1-L8 | Clicking a video plays it | Done |

### Player

| ID | Requirement | Status |
|---|---|---|
| P1-P1 | Play/pause, seek slider, volume (to 130%), speed, fullscreen | Done |
| P1-P2 | Keyboard: Space pause, ←/→ seek 10 s (Shift 60 s), ↑/↓ volume, F or double-click fullscreen | Done |
| P1-P3 | Controls fade after 2.8 s of no mouse movement while playing; stay visible while paused or before media loads; reappear on mouse movement, including after the sidebar closes | Done |
| P1-P4 | Open by URL (`sftp://user@host/path`), using a matching saved server's credentials or a key file | Done |
| P1-P5 | Playback errors are shown, not silent | Done |
| P1-P6 | Closing the last window quits the app and stops audio | Done |

### Recents

| ID | Requirement | Status |
|---|---|---|
| P1-R1 | Keep up to 20 items (title, last played, position, duration), newest first, one per URL | Done |
| P1-R2 | Resume from the saved position, except under 5 s in, within the last 10 s, or with unknown duration | Done |
| P1-R3 | Passwords are stripped from URLs before storing and when looking up | Done |
| P1-R4 | Panel shows progress and relative time; Clear asks for confirmation | Done |
| P1-R5 | Merge stale duplicates (an old entry stored with an explicit `:22`) | Done |

### Subtitles

mpv already renders embedded text and image subtitles (ASS styling, PGS) by default.

| ID | Requirement | Status |
|---|---|---|
| P1-T1 | Subtitle menu lists embedded tracks (from mpv's `track-list`) and Off; selecting one sets `sid` | Built, needs manual check |
| P1-T2 | Discover external subtitles beside the video and in `Subs`, `Subtitles` and `Sub` folders, filename-prefix matches first; add with `sub-add` | Built, needs manual check (discovery and loading through the proxy; live check pending) |
| P1-T3 | Choose a local subtitle file with an open panel | Built, needs manual check |
| P1-T4 | Sync offset of ±5 s in 0.5 s steps (`sub-delay`) | Built, needs manual check |
| P1-T5 | Text size 75–200% (`sub-scale`) and vertical position (`sub-pos`), saved between launches, with a Reset action | Built, needs manual check (no slider yet; buttons only) |
| P1-T6 | A late discovery result never overrides a track the user chose | Done |

### Sidebar

| ID | Requirement | Status |
|---|---|---|
| P1-B1 | One resizable sidebar with Library, Servers and Recents panels | Done |
| P1-B2 | Width limited to 320 pt minimum, saved between launches, adjustable from the keyboard | Built, needs manual check (resizable, limited, saved, keyboard control) |

## Non-functional requirements

- **Credentials**: no secret in logs, screenshots, test fixtures, URLs or commits; examples use synthetic hosts.
- **Concurrency**: at most 3 simultaneous SSH sessions per server; failed logins are not retried.
- **Local proxy**: bound to `127.0.0.1`, URL carries a random per-run token, other paths return 404.
- **Tests**: `swift test` covers profiles, secrets, library sorting/search/folder memory, recents, host-key
  file handling, connection validation and proxy token checks (46 tests). UI behaviour is checked by hand.

## Acceptance

Against a real SFTP server: add a server, trust its key, browse, play a video from the Library, quit
mid-video, reopen and resume from Recents, and use subtitles (tracks, delay, size, position, external file)
without errors.
