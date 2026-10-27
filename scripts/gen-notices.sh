#!/bin/zsh
# Generates THIRD-PARTY-NOTICES.md for the libraries in "<app>/Contents/Frameworks" and
# copies each package's licence files to "<app>/Contents/Resources/Licenses/<formula>/".
# Usage: scripts/gen-notices.sh [path/to/Wharf.app]   (default: build/Wharf.app)
# Run after scripts/bundle-libs.sh. Each dylib is mapped to the installed Homebrew formula
# whose Cellar lib/ directory holds a file of that name. Metadata comes from
# `brew info --json=v2 --installed` (offline). Unmapped or ambiguous libraries fail the script.
# Missing metadata is written as "unknown" and listed on stderr.
# Licences are copied over any previous copy (build-app.sh recreates the bundle each run).
set -euo pipefail
setopt extended_glob
cd "${0:A:h}/.."

APP="${1:-build/Wharf.app}"
FW="$APP/Contents/Frameworks"
LIC="$APP/Contents/Resources/Licenses"
OUT="THIRD-PARTY-NOTICES.md"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_INSTALL_FROM_API=1
[[ -d $FW ]] || { echo "missing $FW (run scripts/bundle-libs.sh)" >&2; exit 1 }

CELLAR="$(brew --cellar)"
JSON="$(brew info --json=v2 --installed 2>/dev/null)"

# name<TAB>version<TAB>license<TAB>homepage<TAB>source url, one line per installed formula version
rows=("${(@f)$(print -r -- "$JSON" | jq -r '.formulae[] | . as $f | $f.installed[] |
  [$f.name, .version,
   ($f.license | if . == null then "unknown" elif type == "string" then . else tojson end),
   ($f.homepage // "unknown"), ($f.urls.stable.url // "unknown")] | @tsv')}")

typeset -A owner info    # dylib basename -> formula; formula -> "version<TAB>license<TAB>homepage<TAB>url"
typeset -a ambiguous unmapped unknown
for row in "${rows[@]}"; do
  f=("${(@ps:\t:)row}")
  name="$f[1]"; ver="$f[2]"
  [[ -d $CELLAR/$name/$ver ]] || continue
  info[$name]="$ver"$'\t'"$f[3]"$'\t'"$f[4]"$'\t'"$f[5]"
  for lib in "$CELLAR/$name/$ver"/lib/*.dylib(N:t); do
    [[ -e $FW/$lib ]] || continue   # only libraries actually bundled
    if [[ -n ${owner[$lib]-} && ${owner[$lib]} != $name ]]; then ambiguous+=("$lib: ${owner[$lib]} and $name")
    else owner[$lib]="$name"; fi
  done
done

typeset -a used
for lib in "$FW"/*.dylib(N:t); do
  if [[ -z ${owner[$lib]-} ]]; then unmapped+=("$lib"); else used+=("${owner[$lib]}"); fi
done
if (( ${#unmapped} || ${#ambiguous} )); then
  (( ${#unmapped} )) && { echo "UNMAPPED libraries (no installed formula ships them):" >&2; printf '  %s\n' "${unmapped[@]}" >&2 }
  (( ${#ambiguous} )) && { echo "AMBIGUOUS libraries:" >&2; printf '  %s\n' "${ambiguous[@]}" >&2 }
  exit 1
fi
used=("${(@ou)used}")   # unique, sorted
ndylibs=${#${(@)$(print -l "$FW"/*.dylib(N))}}

FFMPEG_CONF="$(ffmpeg -version 2>/dev/null | sed -n 's/^configuration: //p')"
[[ -n $FFMPEG_CONF ]] || { echo "ffmpeg -version gave no configuration line" >&2; exit 1 }

mkdir -p "$LIC"
{
  print "# Third-party notices"
  print
  print "Wharf bundles the unmodified Homebrew builds listed below in \`Contents/Frameworks\`."
  print "Wharf itself is licensed under GPL-3.0 (see \`LICENSE\`). Source: see \`SOURCE-OFFER.md\`."
  print "Licence files shipped by each package are in \`Contents/Resources/Licenses/<formula>/\`."
  print
  print "Mapped $ndylibs dylibs to ${#used} Homebrew formulae."
  print
  print "| Formula | Version | Licence (SPDX, from Homebrew) | Homepage | Source archive | Dylibs |"
  print "|---|---|---|---|---|---|"
  for name in "${used[@]}"; do
    i=("${(@ps:\t:)info[$name]}")
    libs=(); for l in "${(@ok)owner}"; do [[ ${owner[$l]} == $name && -e $FW/$l ]] && libs+=("$l"); done
    [[ $i[2] == unknown || $i[3] == unknown || $i[4] == unknown ]] && unknown+=("$name (metadata)")
    print "| $name | $i[1] | $i[2] | $i[3] | $i[4] | ${(j:, :)libs} |"
    n=0
    for lf in "$CELLAR/$name/$i[1]"/(#i)(COPYING|LICEN[SC]E|COPYRIGHT)*(N.); do
      mkdir -p "$LIC/$name"; cp -f "$lf" "$LIC/$name/"; n=$((n+1))
    done
    (( n )) || unknown+=("$name (no licence file in Cellar)")
  done
  print
  print "## mpv"
  print
  print -r -- "- Version: ${${(@ps:\t:)info[mpv]}[1]} (Homebrew formula \`mpv\`)"
  print -r -- "- Licence: ${${(@ps:\t:)info[mpv]}[2]}"
  print -r -- "- Upstream source: ${${(@ps:\t:)info[mpv]}[4]}"
  print
  print "## FFmpeg"
  print
  print -r -- "- Version: ${${(@ps:\t:)info[ffmpeg]}[1]} (Homebrew formula \`ffmpeg\`)"
  print -r -- "- Licence: ${${(@ps:\t:)info[ffmpeg]}[2]}; this build enables GPL and version 3 parts, so the combination is GPL-3.0-or-later."
  print -r -- "- Upstream source: ${${(@ps:\t:)info[ffmpeg]}[4]}"
  print -r -- "- Configure line (from \`ffmpeg -version\`):"
  print
  print '```'
  print -r -- "$FFMPEG_CONF"
  print '```'
} > "$OUT"

echo "Mapped $ndylibs dylibs to ${#used} formulae -> $OUT, $LIC"
if (( ${#unknown} )); then
  echo "UNKNOWN metadata for:" >&2; printf '  %s\n' "${unknown[@]}" >&2
fi
