#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/tests/helpers.sh"
OPENMP_SYNC_LIB=1 . "$DIR/sync-openmp.sh"

rec=$'1700\t19.1.5\tdarwin20\t5b44175bcbaa334b0c57391482e068ea185c95a2\tXcode 16.3-26.3'

case_out=$(printf '%s\n' "$rec" | render_case)
want_case=$'    1700)\n        OPENMP_VERSION="19.1.5"\n        DARWIN_TARGET="darwin20"\n        EXPECTED_SHA1="5b44175bcbaa334b0c57391482e068ea185c95a2"\n        ;;'
assert_eq "$case_out" "$want_case" "render_case single tier"

help_out=$(printf '%s\n' "$rec" | render_help)
assert_eq "$help_out" '    echo "    Xcode 16.3-26.3  → OpenMP 19.1.5"' "render_help single tier"

readme_out=$(printf '%s\n' "$rec" | render_readme)
want_readme='| 16.3-26.3 | 1700.x | 19.1.5 | [openmp-19.1.5-darwin20-Release.tar.gz](https://mac.r-project.org/openmp/openmp-19.1.5-darwin20-Release.tar.gz) |'
assert_eq "$readme_out" "$want_readme" "render_readme single tier"
echo "PASS: test-render"
