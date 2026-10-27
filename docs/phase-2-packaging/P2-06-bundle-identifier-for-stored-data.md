# P2-06: Bundle identifier for stored data

**Status:** Built, needs manual check  
**Requirements:** P2-6  
**Depends on:** P2-01, P2-05  

## What

Make `UserDefaults` and the Keychain stable across rebuilds.

## Acceptance criteria

- [x] Profiles and recents live under the bundle identifier's defaults domain (automatic: `Bundle.main` is `io.bimurto.wharf`)
- [x] Existing saved servers from `swift run` (domain `SFTPPlayer`) migrate once (unit-tested; real data check pending)
- [ ] Keychain access does not prompt on every rebuild (not achievable for ad-hoc builds, see below)

## Notes

Today the unbundled binary uses a process-name domain and may re-prompt for Keychain access.

## Implementation

- `Sources/Core/LegacyMigration.swift`: `migrate(legacy:into:destinationDomain:...)` is pure; `runAtStartup()` reads `persistentDomain(forName: "SFTPPlayer")` (read only) and migrates into `.standard`.
- Runs from `SFTPPlayerApp.init()` in `App.swift`. That runs before any scene is built, so before `AppModel.shared` creates `ProfileStore`, `RecentsStore` and `SidebarWidthStore`, and before the player creates `SubtitleAppearanceStore`.
- No-op when the app's own domain is `SFTPPlayer` (`swift run`), when there is no legacy domain, or when the flag `migrated_from_SFTPPlayer_v1` is set. The flag is set only after the copy, so deleting servers later does not bring them back.
- `sftp_profiles`, `sidebar_width`, `subtitle_scale`, `subtitle_position`: copied only if the destination has no value.
- `sftp_history`: union with the destination's recents by normalised URL (`RecentsStore.combined`, so `:22` entries dedupe), newest `lastPlayed` wins, newest first, capped at 20.
- Legacy data is never modified or deleted. Nothing is logged. Defaults hold no secrets.
- The Keychain service name and the known-hosts folder are unchanged on purpose.
- Tests: `Tests/CoreTests/LegacyMigrationTests.swift` (isolated suites, removed in `tearDown`; real domains and Keychain untouched).

## Keychain

- Passwords stay under service `com.bimurto.sftp-media-player`, so they are still found.
- The items were created by the unsigned `swift run` binary. On the first launch of the signed bundle macOS asks once to let Wharf use them. This cannot be avoided without rewriting the items. Click **Always Allow**.
- Ad-hoc signatures (`codesign -s -`) have no stable identity: the designated requirement is the code hash, which changes on every rebuild. Expect a new prompt after each rebuilt ad-hoc build. Stable prompts across rebuilds need a real certificate (Developer ID or a self-signed identity reused for every build), which is outside P2-05's ad-hoc decision.
- `kSecAttrAccessible` controls when data is readable (locked/unlocked, device-only), not which apps are trusted, and has no effect on the per-app trust list of the login keychain. Access groups need the data-protection keychain plus a signed entitlement with a team ID, which ad-hoc builds cannot have. No Keychain code was changed.

## Manual check (owner)

1. Launch `build/Wharf.app` once. Servers, recents, sidebar width and subtitle settings from `swift run` should appear.
2. Click **Always Allow** on the Keychain prompt; connect to a saved server without retyping the password.
3. Delete a server, quit and relaunch: it must not come back.
4. `swift run` still shows its own data unchanged.
