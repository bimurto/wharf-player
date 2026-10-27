#!/bin/zsh
# Verifies that the app bundle is self-contained and relocatable.
# Usage: scripts/verify-bundle.sh [path/to/Wharf.app]   (default: build/Wharf.app)
# Checks, for the executable and every dylib in Contents/Frameworks:
#   1. otool -L and LC_RPATH contain no /opt/homebrew, /usr/local or /Users path
#   2. every @rpath/<name> dependency resolves to a file in Frameworks
#   3. codesign --verify --strict passes (then --deep --strict on the .app)
# Exits 1 on any violation.
set -uo pipefail
cd "${0:A:h}/.."
APP="${1:-build/Wharf.app}"
FW="$APP/Contents/Frameworks"
MAIN="$APP/Contents/MacOS/SFTPPlayer"
[[ -f $MAIN ]] || { echo "missing $MAIN" >&2; exit 1 }
files=("$MAIN" "$FW"/*.dylib(N))
bad=()
for f in "${files[@]}"; do
  out="$(otool -L "$f" | tail -n +2; otool -l "$f" | awk '/cmd LC_RPATH/{f=1} f&&/ path /{print "rpath " $2; f=0}')"
  hits="$(print -r -- "$out" | grep -E '/opt/homebrew|/usr/local|/Users' || true)"
  [[ -n $hits ]] && bad+=("forbidden path in ${f:t}: ${hits//$'\n'/; }")
  for dep in "${(@f)$(otool -L "$f" | tail -n +2 | awk '{print $1}')}"; do
    case "$dep" in
      @rpath/*) [[ -e $FW/${dep#@rpath/} ]] || bad+=("${f:t}: $dep not in Frameworks") ;;
      @*) bad+=("${f:t}: unexpected $dep") ;;
    esac
  done
  codesign --verify --strict "$f" 2>/dev/null || bad+=("codesign --strict failed: ${f:t}")
done
codesign --verify --deep --strict "$APP" 2>/dev/null || bad+=("codesign --deep --strict failed: $APP")
if (( ${#bad} )); then
  echo "FAIL:"; printf '  %s\n' "${bad[@]}"; exit 1
fi
echo "OK: ${#files} binaries: no forbidden paths, all @rpath refs resolve, signatures valid"
