# P2-04: Decide the licence

**Status:** Built, owner must fill placeholders  
**Requirements:** P2-4  

## What

Homebrew's mpv is a GPL build, so bundling it makes the app GPL.

## Acceptance criteria

- [x] Choose: relicense to GPL-3.0, or build mpv with `-Dgpl=false` and FFmpeg without GPL parts (owner chose GPL-3.0)
- [x] Record the decision in `docs`
- [ ] Ship licence texts and a corresponding-source offer with the app (built and bundled; open: fill `<REPOSITORY URL>` and `<CONTACT ADDRESS>` in `SOURCE-OFFER.md`, and confirm the copyright holder name)

## Notes

Blocks any public release. Not blocking the first local build.

## Decision

GPL-3.0. Homebrew's mpv is GPL and its FFmpeg is built with `--enable-gpl --enable-version3` (plus x264/x265), so the bundled combination is GPL-3.0-or-later. Relicensing the app is far cheaper than maintaining a non-GPL mpv/FFmpeg build.

## Implementation notes

- `LICENSE`: GPL-3.0 text copied unmodified from Homebrew's `ffmpeg/9.0.2_1/COPYING.GPLv3`. It differs from xz's `COPYING.GPLv3` only in `http` versus `https` fsf.org links. Copyright holder used in `Info.plist`: git `user.name`, year 2026 (owner to confirm).
- `scripts/gen-notices.sh [app]`: maps each bundled dylib to its installed Homebrew formula (Cellar `lib/` contents plus `brew info --json=v2 --installed`, offline), writes `THIRD-PARTY-NOTICES.md` (formula, version, SPDX licence, homepage, source archive, dylibs, FFmpeg configure line) and copies each package's `COPYING*`/`LICENSE*`/`COPYRIGHT*` files to `Contents/Resources/Licenses/<formula>/`. Fails listing unmapped or ambiguous libraries. Currently 55 dylibs map to 47 formulae. Unknown: `glib` ships no licence file at the top of its Cellar directory (Homebrew metadata gives its SPDX licence).
- `SOURCE-OFFER.md`: section 6 offer, three years or as long as the version is distributed.
- `build-app.sh` runs gen-notices and copies `LICENSE`, `THIRD-PARTY-NOTICES.md`, `SOURCE-OFFER.md` into `Contents/Resources/` before `relocate-libs.sh`, which signs, so the signature covers them. `Info.plist` gets `NSHumanReadableCopyright`.
