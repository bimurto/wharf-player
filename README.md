# Wharf

A native macOS video player for media on SFTP servers. Browse a remote folder, click a video, and it plays. Nothing is downloaded first.

Playback, decoding and subtitle rendering are done by [mpv](https://mpv.io) (libmpv). Wharf adds the connections, browsing and history around it.

Version 1.0.0 · macOS · [GPL-3.0-or-later](LICENSE)

## Features

- **Server profiles.** Save a label, host, port, user, password or key file, optional key passphrase and default directory. Passwords and passphrases live in the macOS Keychain, never in profile files, URLs, recents or logs.
- **Test Connection.** Authenticates, lists the default directory and reports the real failure reason.
- **Trust on first use for host keys.** The first connection shows the SHA256 fingerprint and asks. A changed key is refused. Wharf uses its own known-hosts file and never touches `~/.ssh/known_hosts`.
- **Library browser.** Breadcrumbs, sizes and dates, sort by name or date, search, refresh. The last folder is remembered per server.
- **Streaming over SFTP.** A local pipelined proxy serves byte ranges to mpv, so seeking works without downloading the file.
- **Recents with resume.** Picks up where you left off.
- **Subtitles.** Embedded tracks, external files found next to the video, or a local file you choose. Adjust sync offset, size and position.
- **Open by URL.** `Cmd+O`.

### Player controls

| Key | Action |
|---|---|
| `Space` | Play / pause |
| `←` / `→` | Seek 10 s (60 s with `Shift`) |
| `↑` / `↓` | Volume (up to 130%) |
| `F` or double-click | Fullscreen |
| `Cmd+O` | Open URL |

The speed menu and subtitle menu are in the control bar. Controls hide after 2.8 s without mouse movement while playing.

## Requirements

- macOS 14 or later to build (`Package.swift`). The built app bundle declares macOS 26 as its minimum (`LSMinimumSystemVersion` in `scripts/build-app.sh`).
- Swift 5.9 toolchain (Xcode or Command Line Tools)
- [Homebrew](https://brew.sh) with `mpv` and `libssh`:

```sh
brew install mpv libssh
```

## Build and run

```sh
swift build
swift run SFTPPlayer
```

Run the tests:

```sh
swift test
```

## Package the app

```sh
scripts/build-app.sh   # build/Wharf.app
scripts/build-dmg.sh   # build/Wharf-<version>-<arch>.dmg and .sha256
```

`build-app.sh` builds a release binary, assembles the bundle, copies in libmpv and its dylibs (`bundle-libs.sh`), generates the third-party notices (`gen-notices.sh`), rewrites install names and ad-hoc signs (`relocate-libs.sh`), then checks the bundle is self-contained (`verify-bundle.sh`). The version comes from `VERSION`.

The icon is read from `ICON_SRC`, which defaults to a path on the author's machine. Set it to your own `.icns` file:

```sh
ICON_SRC=/path/to/icon.icns scripts/build-app.sh
```

The app is ad-hoc signed and the DMG is not notarised, so other Macs show a Gatekeeper warning. Right-click the app and choose Open, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Wharf.app
```

## Project layout

```
Sources/
  Core/         Profiles, Keychain, SFTP browsing and proxy, host keys, recents, subtitles. No UI.
  SFTPPlayer/   SwiftUI app and the mpv wrapper and video view
  CMPV/         System-library shim for libmpv
  CLibSSH/      System-library shim for libssh
  Spike/        Phase 0 experiments (throughput, proxy)
Tests/CoreTests/  Unit tests for Core
scripts/        App bundle, DMG and library bundling
docs/           Phase requirements and one file per ticket
```

## Documentation

Planning and status are in [`docs/`](docs/README.md), one folder per phase:

- [Phase 0: Risk spike](docs/phase-0-risk-spike/README.md) (done)
- [Phase 1: MVP feature parity](docs/phase-1-mvp/README.md) (in progress)
- [Phase 2: Packaging and release](docs/phase-2-packaging/README.md) (in progress)

## Licence

Wharf is free software under the GNU General Public License v3.0 or later. See [`LICENSE`](LICENSE).

The app bundles unmodified Homebrew builds of mpv, FFmpeg and their dependencies under their own licences. See [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) and the written source offer in [`SOURCE-OFFER.md`](SOURCE-OFFER.md).
