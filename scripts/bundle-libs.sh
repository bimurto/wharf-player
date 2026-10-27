#!/bin/zsh
# Copies the transitive closure of non-system dylibs into "<app>/Contents/Frameworks".
# Usage: scripts/bundle-libs.sh [path/to/Wharf.app]   (default: build/Wharf.app)
# Walks `otool -L` from the main executable. Libraries under /opt/homebrew are
# copied once (symlinks resolved) under the basename of the name that references them.
# /System, /usr/lib are skipped. @rpath/@loader_path/@executable_path references are
# resolved through LC_RPATH. Anything unresolvable is reported and fails the script.
# Binaries are not modified; install names are rewritten later (P2-03).
set -euo pipefail
cd "${0:A:h}/.."

APP="${1:-build/Wharf.app}"
EXE="SFTPPlayer"
MAIN="$APP/Contents/MacOS/$EXE"
FW="$APP/Contents/Frameworks"
[[ -f $MAIN ]] || { echo "missing $MAIN (run scripts/build-app.sh)" >&2; exit 1 }

rm -rf "$FW"   # Frameworks inside the app bundle only; makes re-runs identical
mkdir -p "$FW"

typeset -A seen       # dest basename -> source real path
typeset -a queue unresolved
queue=("${MAIN:A}")
typeset -A origin     # source path -> where it is (for @loader_path)

# Prints candidate absolute paths for a @-relative reference from file $1.
resolve_at() {
  local from="$1" ref="$2" rp tail dir
  local fromdir="${from:h}"
  case "$ref" in
    @loader_path/*) print -r -- "$fromdir/${ref#@loader_path/}" ;;
    @executable_path/*) print -r -- "${MAIN:A:h}/${ref#@executable_path/}" ;;
    @rpath/*)
      tail="${ref#@rpath/}"
      otool -l "$from" | awk '/cmd LC_RPATH/{f=1} f&&/path /{print $2; f=0}' | while read -r rp; do
        rp="${rp/#@loader_path/$fromdir}"
        rp="${rp/#@executable_path/${MAIN:A:h}}"
        print -r -- "$rp/$tail"
      done ;;
  esac
}

while (( ${#queue} )); do
  cur="${queue[1]}"; queue=("${queue[@]:1}")
  deps=("${(@f)$(otool -L "$cur" | tail -n +2 | awk '{print $1}')}")
  # for a dylib the first entry is its own install name; skip it
  [[ $cur == $MAIN:A ]] || deps=("${deps[@]:1}")
  for dep in "${deps[@]}"; do
    [[ -z $dep ]] && continue
    case "$dep" in /System/*|/usr/lib/*) continue ;; esac
    base="${dep:t}"
    real=""
    if [[ $dep == @* ]]; then
      for cand in $(resolve_at "$cur" "$dep"); do
        [[ -e $cand ]] && { real="${cand:A}"; break }
      done
      # already bundled under that name (e.g. same-dir sibling)? fine
      if [[ -z $real && -n ${seen[$base]-} ]]; then continue; fi
    elif [[ -e $dep ]]; then
      real="${dep:A}"
    fi
    if [[ -z $real ]]; then
      unresolved+=("$dep  (needed by ${cur})"); continue
    fi
    case "$real" in /System/*|/usr/lib/*) continue ;; esac
    case "$real" in
      /opt/homebrew/*) ;;
      *) unresolved+=("$dep -> $real  (outside /opt/homebrew; needed by ${cur})"); continue ;;
    esac
    [[ -n ${seen[$base]-} ]] && continue
    seen[$base]="$real"
    cp -f "$real" "$FW/$base"
    chmod u+w "$FW/$base"
    queue+=("$real")
  done
done

echo "Bundled ${#seen} libraries into $FW ($(du -sh "$FW" | awk '{print $1}'))"
if (( ${#unresolved} )); then
  echo "UNRESOLVED dependencies:" >&2
  printf '  %s\n' "${unresolved[@]}" >&2
  exit 1
fi
