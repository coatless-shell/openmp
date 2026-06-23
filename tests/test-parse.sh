#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/tests/helpers.sh"
OPENMP_SYNC_LIB=1 . "$DIR/sync-openmp.sh"

got=$(parse_page "$DIR/tests/fixtures/page.html")
want=$(cat "$DIR/tests/fixtures/golden-records.tsv")
assert_eq "$got" "$want" "parse_page output matches golden records"
echo "PASS: test-parse"
