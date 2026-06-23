#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/tests/helpers.sh"

work=$(mktemp -d)
cp "$DIR/install-openmp.sh" "$DIR/README.md" "$work/"
cp "$DIR/sync-openmp.sh" "$work/"
cp -r "$DIR/tests" "$work/tests"

# Run sync against the fixture, trusting page SHA (offline), writing into the temp copies.
( cd "$work" && OPENMP_SYNC_PAGE="tests/fixtures/page.html" OPENMP_SYNC_TRUST_PAGE=1 \
    bash sync-openmp.sh > summary.txt )

grep -q '19.1.5' "$work/install-openmp.sh" || fail "install case not updated to 19.1.5"
grep -q '5b44175bcbaa334b0c57391482e068ea185c95a2' "$work/install-openmp.sh" || fail "install SHA not updated"
grep -q '| 16.3-26.3 | 1700.x | 19.1.5 |' "$work/README.md" || fail "README row not updated"
grep -q 'UPDATED 1700' "$work/summary.txt" || fail "summary missing UPDATED 1700"

# Running --check on the freshly-synced tree reports no drift (exit 0).
( cd "$work" && OPENMP_SYNC_PAGE="tests/fixtures/page.html" OPENMP_SYNC_TRUST_PAGE=1 \
    bash sync-openmp.sh --check ) || fail "--check reported drift after sync"
rm -rf "$work"
echo "PASS: test-e2e"
