# P2-03: Rewrite install names and verify

**Status:** Todo  
**Requirements:** P2-3  
**Depends on:** P2-02  

## What

Make the bundle relocatable.

## Acceptance criteria

- [ ] `install_name_tool` or `dylibbundler` rewrites every reference to `@rpath` or `@executable_path`
- [ ] `otool -L` on the executable and every `.dylib` shows no `/opt/homebrew` or `/usr/local` paths
- [ ] App still runs after being moved to another folder
