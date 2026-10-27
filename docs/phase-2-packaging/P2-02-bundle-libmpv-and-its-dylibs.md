# P2-02: Bundle libmpv and its dylibs

**Status:** Todo  
**Requirements:** P2-2  
**Depends on:** P2-01  

## What

Copy libmpv and its whole dylib closure into `Contents/Frameworks`.

## Acceptance criteria

- [ ] Script lists the closure with `otool -L` recursively
- [ ] All libraries (FFmpeg, libssh, libass, libplacebo and others) are copied
- [ ] Re-runnable from a clean checkout
