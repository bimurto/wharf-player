#!/bin/zsh
# Makes the bundled libraries relocatable and re-signs the bundle (ad hoc).
# Usage: scripts/relocate-libs.sh [path/to/Wharf.app]   (default: build/Wharf.app)
# Run after scripts/bundle-libs.sh. Idempotent. For every dylib in Contents/Frameworks:
#   - install id -> @rpath/<basename>
#   - every non-system dependency -> @rpath/<basename> (built from `otool -L`)
#   - all LC_RPATH entries removed, then @loader_path added (siblings only)
# The executable gets the same dependency rewrite, its machine-specific rpaths
# (/opt/homebrew, /usr/local, /Users) removed, and @executable_path/../Frameworks added.
# Then dylibs are signed first, the executable next and the .app last.
set -euo pipefail
cd "${0:A:h}/.."

APP="${1:-build/Wharf.app}"
EXE="SFTPPlayer"
MAIN="$APP/Contents/MacOS/$EXE"
FW="$APP/Contents/Frameworks"
[[ -f $MAIN && -d $FW ]] || { echo "missing $MAIN or $FW (run scripts/build-app.sh)" >&2; exit 1 }

rpaths() { otool -l "$1" | awk '/cmd LC_RPATH/{f=1} f&&/ path /{print $2; f=0}'; }

# Rewrites each non-system dependency of $1 to @rpath/<basename>.
rewrite_deps() {
  local f="$1" dep
  for dep in "${(@f)$(otool -L "$f" | tail -n +2 | awk '{print $1}')}"; do
    case "$dep" in /System/*|/usr/lib/*|"") continue ;; esac
    [[ $dep == "@rpath/${dep:t}" ]] && { [[ -e $FW/${dep:t} ]] || { echo "ERROR: ${f:t} needs $dep, not in Frameworks" >&2; exit 1 }; continue }
    [[ -e $FW/${dep:t} ]] || { echo "ERROR: ${f:t} needs $dep, not in Frameworks" >&2; exit 1 }
    install_name_tool -change "$dep" "@rpath/${dep:t}" "$f"
  done
}

dylibs=("$FW"/*.dylib(N))
(( ${#dylibs} )) || { echo "no dylibs in $FW" >&2; exit 1 }

for f in "${dylibs[@]}"; do
  chmod u+w "$f"
  install_name_tool -id "@rpath/${f:t}" "$f"
  rewrite_deps "$f"
  for rp in "${(@f)$(rpaths "$f")}"; do
    [[ -n $rp ]] && install_name_tool -delete_rpath "$rp" "$f"
  done
  install_name_tool -add_rpath @loader_path "$f"
done

rewrite_deps "$MAIN"
for rp in "${(@f)$(rpaths "$MAIN")}"; do
  case "$rp" in /opt/homebrew*|/usr/local*|/Users/*|@executable_path/../Frameworks) 
    install_name_tool -delete_rpath "$rp" "$MAIN" ;; esac
done
install_name_tool -add_rpath @executable_path/../Frameworks "$MAIN"

for f in "${dylibs[@]}"; do codesign --force --sign - "$f"; done
codesign --force --sign - "$MAIN"
codesign --force --sign - "$APP"

echo "Relocated and ad-hoc signed ${#dylibs} libraries, $MAIN and $APP"
