# P2-03: Rewrite install names and verify

**Status:** Built, needs manual check  
**Requirements:** P2-3  
**Depends on:** P2-02  

## What

Make the bundle relocatable.

## Acceptance criteria

- [x] `install_name_tool` or `dylibbundler` rewrites every reference to `@rpath` or `@executable_path`
- [x] `otool -L` on the executable and every `.dylib` shows no `/opt/homebrew` or `/usr/local` paths
- [ ] App still runs after being moved to another folder (built, needs manual check: headless dlopen test of the moved copy passed, the GUI was not launched)

## Implementation notes

- `scripts/relocate-libs.sh [app]` (called by `build-app.sh` after `bundle-libs.sh`): for each dylib sets the id to `@rpath/<basename>`, rewrites every non-system dependency (built from `otool -L`) to `@rpath/<basename>`, removes all existing `LC_RPATH` entries (they pointed at `/opt/homebrew/Cellar/...`, Xcode and `../lib`) and adds `@loader_path`. The executable gets the same dependency rewrite, loses any `/opt/homebrew`, `/usr/local`, `/Users` rpath, and gains `@executable_path/../Frameworks`. Then it ad-hoc signs every dylib, the executable, and the `.app` last (no `--deep`). Idempotent; fails on any missing dependency.
- `scripts/verify-bundle.sh [app]` (also run by `build-app.sh`): no `/opt/homebrew`, `/usr/local` or `/Users` in `otool -L` or rpaths, every `@rpath` reference exists in Frameworks, `codesign --verify --strict` per binary and `--deep --strict` on the app. Exits 1 on violation.
- Results: 56 binaries clean; all signatures valid; `swift test` passes. Copy of the app in a new directory: a small C program `dlopen`ed the copy's `libmpv.2.dylib`, `mpv_create`/`mpv_destroy` worked, `mpv_client_api_version` = 0x20005, and `DYLD_PRINT_LIBRARIES` showed 0 libraries loaded from `/opt/homebrew` (55 from the copy's Frameworks).
- Hard-coded `/opt/homebrew` strings remain inside the dylib data (not load commands): the FFmpeg build configuration text (harmless), `/opt/homebrew/etc/fonts` and cache dir in libfontconfig (fonts config missing on a clean Mac, so libass may find no fonts config), OpenSSL config, cert and `ossl-modules` dirs, mpv `sysconfdir` `/opt/homebrew/etc/mpv`, libvulkan search dirs (MoltenVK ICD not bundled), luajit and glib search paths, libX11 locale data. Without Homebrew these resolve to nothing; they do not break loading. Follow-up: fontconfig config, MoltenVK ICD and OpenSSL CA path for a Homebrew-free Mac (P2-09).
