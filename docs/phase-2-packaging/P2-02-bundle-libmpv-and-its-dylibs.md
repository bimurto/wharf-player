# P2-02: Bundle libmpv and its dylibs

**Status:** Built, needs manual check  
**Requirements:** P2-2  
**Depends on:** P2-01  

## What

Copy libmpv and its whole dylib closure into `Contents/Frameworks`.

## Acceptance criteria

- [x] Script lists the closure with `otool -L` recursively
- [x] All libraries (FFmpeg, libssh, libass, libplacebo and others) are copied
- [x] Re-runnable from a clean checkout

## Implementation notes

- `scripts/bundle-libs.sh [app]` walks `otool -L` from the executable and copies every `/opt/homebrew` dylib (symlinks resolved, stored under the referenced basename) into `Contents/Frameworks`. It fails and lists any dependency it cannot resolve. `scripts/build-app.sh` calls it.
- `scripts/check-bundle-libs.sh [app]` confirms every non-system dependency of the executable and each bundled dylib is present in Frameworks (by basename, so P2-03 can reuse it after rewriting).
- Result: 55 dylibs, 64 MB, no unresolved dependencies. Binaries are untouched; they still point at `/opt/homebrew` until P2-03.
- Runtime resources not bundled yet (follow-ups): MoltenVK is not in the closure (libvulkan loads it through the ICD json), fontconfig's `/opt/homebrew/etc/fonts`, OpenSSL config and modules dir under `/opt/homebrew/etc/openssl@4` and `Cellar/openssl@4`, and `/opt/homebrew/etc/mpv`.
