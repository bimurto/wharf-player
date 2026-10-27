# Corresponding source offer

Wharf is free software under the GNU General Public License, version 3 (see `LICENSE`).
This file is the written offer required by section 6 of that licence.

## Wharf

The complete source of Wharf, including the scripts that build `Wharf.app`, is in this repository:

**<https://github.com/bimurto/wharf-player>**

## Bundled libraries

`Wharf.app/Contents/Frameworks` contains unmodified Homebrew builds of mpv (libmpv), FFmpeg and the libraries they depend on.
Wharf does not patch them. `THIRD-PARTY-NOTICES.md` (also in `Contents/Resources/`) lists, for each library:

- the exact Homebrew formula version,
- its licence,
- its homepage,
- the upstream source archive Homebrew built it from.

The two main ones, as listed there at build time:

- mpv: https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz (formula version 0.41.0_11)
- FFmpeg: https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz (formula version 9.0.2_1)

The FFmpeg configure flags are in `THIRD-PARTY-NOTICES.md`. The Homebrew formulae (build recipes and patches) are in
https://github.com/Homebrew/homebrew-core, under `Formula/<first letter>/<formula>.rb` at the version listed.
If a newer build of Wharf lists different versions, `THIRD-PARTY-NOTICES.md` in that build is authoritative.

## How to get the source

For three years from the date you received a copy of Wharf, or for as long as that version is distributed, whichever is longer,
you may request the complete corresponding source for the bundled libraries on a physical medium for no more than the cost of
physically performing the distribution, by writing to:

**bimurto@bimurto.io**

Please state the Wharf version (`CFBundleShortVersionString` in `Info.plist`).
