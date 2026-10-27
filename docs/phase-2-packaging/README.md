# Phase 2: Packaging and release

In progress: P2-1 to P2-4 built, needs manual check. Today the app only runs through `swift run`, using Homebrew's libmpv and libssh.

## Goal

Ship a self-contained `Wharf.app` (and DMG) for macOS that runs on a Mac with no Homebrew.

## Requirements

| ID | Requirement | Pass criteria |
|---|---|---|
| P2-1 | Real app bundle with `Info.plist`, bundle identifier, version and icon (reuse the Electron app's `icon.icns`) | Launches from Finder with a Dock icon and menu bar, with no `setActivationPolicy` workaround |
| P2-2 | Bundle `libmpv` and its full dylib closure (FFmpeg, libssh, libass, libplacebo and others) in `Contents/Frameworks` | `otool -L` on the executable and every bundled library shows no `/opt/homebrew` or `/usr/local` paths |
| P2-3 | Rewrite install names (`install_name_tool` or `dylibbundler`) and keep the bundle relocatable | The app runs after being moved to another folder or another Mac |
| P2-4 | Licence decision before the first public release. Homebrew's mpv is a GPL build, so bundling it makes the app GPL | Either relicense to GPL-3.0, or build mpv with `-Dgpl=false` and FFmpeg without GPL parts; record the decision and ship the licence texts and corresponding source offer |
| P2-5 | Ad-hoc code signing (same as the Electron build's `identity: "-"`) | `codesign --verify` passes; first launch works after the Gatekeeper right-click Open |
| P2-6 | Keychain and `UserDefaults` use the bundle identifier | Saved servers and secrets persist across rebuilds without repeated Keychain prompts |
| P2-7 | DMG output named `SFTP-Media-Player-<version>-<arch>.dmg` | Mounting and dragging to Applications works |
| P2-8 | Release automation (optional): tag-driven build that attaches the DMG and a SHA-256 checksum | Matches how the Electron repo publishes releases |

## Verification

1. Build on a clean checkout and bundle.
2. Run `otool -L` over the executable and every `.dylib`, and confirm no absolute paths outside the bundle and system.
3. Copy the app to a Mac (or a fresh user account) without Homebrew, then repeat the Phase 1 acceptance run.

## Open questions

- Apple Silicon only, or also Intel (universal libraries)?

## Decisions

- **Name:** Wharf (no "SFTP" in the name, so it can grow into a general mpv wrapper). Not checked for trademark or store clashes.
- **Bundle identifier:** `io.bimurto.wharf`.
- **Minimum macOS:** 26.0, because the Homebrew libmpv/FFmpeg/libssh/libass closure is built for 26.0. Revisit only if older macOS is needed.
- **Still to migrate (P2-06):** the Keychain service `com.bimurto.sftp-media-player` and the `Application Support/SFTP Media Player/` folder (known hosts) keep their old names until a migration exists, so saved passwords and trusted host keys are not orphaned.
- **Licence (P2-04):** GPL-3.0. Homebrew's mpv is GPL and its FFmpeg is `--enable-gpl --enable-version3`, so the bundle is GPL-3.0-or-later; relicensing is cheaper than a non-GPL build. The app ships `LICENSE`, `THIRD-PARTY-NOTICES.md`, `SOURCE-OFFER.md` and per-package licence files (`Resources/Licenses/`). Owner must fill the repository URL and contact placeholders in `SOURCE-OFFER.md` before any public release.
