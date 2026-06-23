#!/usr/bin/env bash

# OpenMP Setup - Automatic OpenMP installer for macOS
# Copyright (C) 2025: James J Balamuta
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -euo pipefail

BASE_URL="https://mac.r-project.org/openmp"

# parse_page <html_file>
# Emits one record per *primary* tier: clang<TAB>version<TAB>darwin<TAB>sha1<TAB>xcode
parse_page() {
  local html_file="$1"
  # Strip HTML comments (defensive: drops the commented git build), then put one <tr> per line.
  perl -0pe 's/<!--.*?-->//gs' "$html_file" \
    | tr '\n' ' ' | sed 's/<tr/\n<tr/Ig' \
    | while IFS= read -r row || [ -n "$row" ]; do
        case "$row" in
          "<tr"*"Apple clang"*) : ;;
          *) continue ;;
        esac
        local clang llvm rel ver darwin sha xcode
        clang=$(printf '%s' "$row" | grep -oiE 'Apple clang [0-9]+' | head -1 | grep -oE '[0-9]+')
        llvm=$(printf '%s' "$row"  | grep -oE 'LLVM [0-9]+\.[0-9]+\.[0-9]+' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        rel=$(printf '%s' "$row"   | grep -oE 'openmp-[0-9]+\.[0-9]+\.[0-9]+-darwin[0-9]+-Release\.tar\.gz' | head -1)
        if [ -z "$rel" ]; then echo "WARN: clang ${clang:-?} has no Release tarball; skipping" >&2; continue; fi
        ver=$(printf '%s' "$rel"    | sed -E 's/^openmp-([0-9.]+)-darwin.*/\1/')
        darwin=$(printf '%s' "$rel" | grep -oE 'darwin[0-9]+')
        sha=$(printf '%s' "$row"    | grep -oiE '[0-9a-f]{40}' | head -1)
        if [ -z "$sha" ]; then echo "WARN: clang ${clang:-?} has no SHA1; skipping" >&2; continue; fi
        xcode=$(printf '%s' "$row"  | grep -oE 'Xcode [^(<]+' | head -1 | sed 's/[[:space:]]*$//')
        if [ "$ver" != "$llvm" ]; then echo "WARN: clang $clang Release version ($ver) != LLVM heading ($llvm)" >&2; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$clang" "$ver" "$darwin" "$sha" "$xcode"
      done | sort -t"$(printf '\t')" -k1,1nr
}

# All renderers read records (clang ver darwin sha xcode) from stdin.
render_case() {
  while IFS=$'\t' read -r clang ver darwin sha xcode; do
    printf '    %s)\n        OPENMP_VERSION="%s"\n        DARWIN_TARGET="%s"\n        EXPECTED_SHA1="%s"\n        ;;\n' \
      "$clang" "$ver" "$darwin" "$sha"
  done
}

render_help() {
  while IFS=$'\t' read -r clang ver darwin sha xcode; do
    printf '    echo "    %s  → OpenMP %s"\n' "$xcode" "$ver"
  done
}

render_readme() {
  printf '| Xcode Version | Apple Clang | OpenMP Version | Download |\n'
  printf '|---------------|-------------|----------------|----------|\n'
  while IFS=$'\t' read -r clang ver darwin sha xcode; do
    local short="${xcode#Xcode }"
    local file="openmp-${ver}-${darwin}-Release.tar.gz"
    printf '| %s | %s.x | %s | [%s](%s/%s) |\n' "$short" "$clang" "$ver" "$file" "$BASE_URL" "$file"
  done
}

# current_pin <clang> <install_file> -> "version<TAB>sha1" or empty
current_pin() {
  local clang="$1" file="$2"
  awk -v key="    ${clang})" '
    $0==key {inblock=1; next}
    inblock && /OPENMP_VERSION=/ {v=$0; sub(/.*OPENMP_VERSION="/,"",v); sub(/".*/,"",v)}
    inblock && /EXPECTED_SHA1=/  {s=$0; sub(/.*EXPECTED_SHA1="/,"",s);  sub(/".*/,"",s)}
    inblock && /;;/ {print v"\t"s; exit}
  ' "$file"
}

sha1_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 1 "$1" | cut -d' ' -f1
  else sha1sum "$1" | cut -d' ' -f1; fi
}

# resolve_sha <ver> <darwin> <page_sha>
resolve_sha() {
  local ver="$1" darwin="$2" page_sha="$3"
  if [ "${OPENMP_SYNC_TRUST_PAGE:-0}" = "1" ]; then printf '%s' "$page_sha"; return 0; fi
  local url="$BASE_URL/openmp-${ver}-${darwin}-Release.tar.gz" tmp got
  tmp=$(mktemp)
  if ! curl -fsS -o "$tmp" "$url"; then echo "ERROR: download failed: $url" >&2; rm -f "$tmp"; return 1; fi
  got=$(sha1_of "$tmp"); rm -f "$tmp"
  if [ -n "$page_sha" ] && [ "$got" != "$page_sha" ]; then
    echo "WARN: computed SHA1 ($got) != page SHA1 ($page_sha) for $ver" >&2
  fi
  printf '%s' "$got"
}

# replace_block <file> <begin_substr> <end_substr> <content_file>
replace_block() {
  local file="$1" begin="$2" end="$3" content="$4" tmp
  local nb ne
  nb=$(grep -cF -- "$begin" "$file") || true
  ne=$(grep -cF -- "$end"   "$file") || true
  if [ "$nb" != 1 ] || [ "$ne" != 1 ]; then
    echo "ERROR: replace_block: markers not found exactly once in $file (begin=$nb end=$ne)" >&2
    return 1
  fi
  local mode
  mode=$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file")
  tmp=$(mktemp)
  awk -v b="$begin" -v e="$end" -v cf="$content" '
    index($0,b){print; while((getline line < cf)>0) print line; close(cf); skip=1; next}
    index($0,e){skip=0; print; next}
    !skip{print}
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  chmod "$mode" "$tmp" && mv "$tmp" "$file"
}

# Build resolved records (compute-on-change) and the per-tier summary.
# Writes resolved records to stdout; appends summary lines to the file named by $1.
resolve_records() {
  local summary_file="$1" install="$2" page_records="$3"
  while IFS=$'\t' read -r clang ver darwin sha_page xcode; do
    local pin cur_ver cur_sha sha
    pin=$(current_pin "$clang" "$install")
    cur_ver=$(printf '%s' "$pin" | cut -f1); cur_sha=$(printf '%s' "$pin" | cut -f2)
    if [ "$cur_ver" = "$ver" ] && [ -n "$cur_sha" ]; then
      sha="$cur_sha"
    else
      sha=$(resolve_sha "$ver" "$darwin" "$sha_page") || return 1
      if [ -z "$cur_ver" ]; then echo "NEW $clang: $ver" >> "$summary_file"
      else echo "UPDATED $clang: $cur_ver -> $ver" >> "$summary_file"; fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$clang" "$ver" "$darwin" "$sha" "$xcode"
  done <<< "$page_records"
}

main() {
  local check=0
  [ "${1:-}" = "--check" ] && check=1

  local script_dir install readme page records summary
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  install="$script_dir/install-openmp.sh"
  readme="$script_dir/README.md"

  page=$(mktemp)
  if [ -n "${OPENMP_SYNC_PAGE:-}" ]; then cp "$OPENMP_SYNC_PAGE" "$page"
  else curl -fsS "$BASE_URL/" -o "$page" || { echo "ERROR: cannot fetch $BASE_URL/" >&2; exit 1; }; fi

  records=$(parse_page "$page")
  rm -f "$page"
  [ -n "$records" ] || { echo "ERROR: parsed zero records (page structure changed?)" >&2; exit 1; }

  summary=$(mktemp)
  local resolved
  resolved=$(resolve_records "$summary" "$install" "$records") || { echo "ERROR: SHA resolution failed" >&2; exit 1; }

  # Render blocks into temp files.
  local f_case f_help f_readme
  f_case=$(mktemp); f_help=$(mktemp); f_readme=$(mktemp)
  printf '%s\n' "$resolved" | render_case   > "$f_case"
  printf '%s\n' "$resolved" | render_help   > "$f_help"
  printf '%s\n' "$resolved" | render_readme > "$f_readme"

  if [ "$check" = 1 ]; then
    # Apply to copies and diff; write nothing to the real files.
    local ci cr; ci=$(mktemp); cr=$(mktemp); cp "$install" "$ci"; cp "$readme" "$cr"
    replace_block "$ci" "BEGIN GENERATED VERSION CASES" "END GENERATED VERSION CASES" "$f_case"
    replace_block "$ci" "BEGIN GENERATED HELP VERSIONS" "END GENERATED HELP VERSIONS" "$f_help"
    replace_block "$cr" "BEGIN GENERATED README TABLE"  "END GENERATED README TABLE"  "$f_readme"
    local rc=0
    diff -q "$ci" "$install" >/dev/null || rc=1
    diff -q "$cr" "$readme"  >/dev/null || rc=1
    rm -f "$f_case" "$f_help" "$f_readme" "$summary" "$ci" "$cr"
    [ "$rc" = 0 ] && echo "up to date" || echo "DRIFT: run sync-openmp.sh"
    exit "$rc"
  fi

  replace_block "$install" "BEGIN GENERATED VERSION CASES" "END GENERATED VERSION CASES" "$f_case"
  replace_block "$install" "BEGIN GENERATED HELP VERSIONS" "END GENERATED HELP VERSIONS" "$f_help"
  replace_block "$readme"  "BEGIN GENERATED README TABLE"  "END GENERATED README TABLE"  "$f_readme"
  rm -f "$f_case" "$f_help" "$f_readme"

  echo "Sync complete."
  if [ -s "$summary" ]; then cat "$summary"; else echo "No version changes."; fi
  rm -f "$summary"
}

if [ "${OPENMP_SYNC_LIB:-}" != "1" ]; then
  main "$@"
fi
