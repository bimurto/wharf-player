#!/bin/zsh
# Checks that every non-system dependency of the executable and of every dylib in
# Contents/Frameworks is itself present in Contents/Frameworks (matched by basename,
# so it works before and after install-name rewriting). Reusable by P2-03.
# Usage: scripts/check-bundle-libs.sh [path/to/Wharf.app]
# Prints "OK" and exits 0, or lists missing libraries and exits 1.
set -euo pipefail
cd "${0:A:h}/.."
APP="${1:-build/Wharf.app}"
FW="$APP/Contents/Frameworks"
files=("$APP/Contents/MacOS/SFTPPlayer" "$FW"/*.dylib(N))
missing=()
for f in "${files[@]}"; do
  for dep in "${(@f)$(otool -L "$f" | tail -n +2 | awk '{print $1}')}"; do
    case "$dep" in /System/*|/usr/lib/*|"") continue ;; esac
    [[ ${dep:t} == ${f:t} ]] && continue   # a dylib's own install name
    [[ -e $FW/${dep:t} ]] || missing+=("${f:t} -> $dep")
  done
done
if (( ${#missing} )); then
  echo "MISSING from Frameworks:"; printf '  %s\n' "${(u)missing[@]}"; exit 1
fi
echo "OK: ${#files} binaries checked, all non-system dependencies present in Frameworks"
