#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/tests/helpers.sh"

work=$(mktemp -d)
cp "$DIR/install-openmp.sh" "$DIR/README.md" "$work/"
cp "$DIR/sync-openmp.sh" "$work/"
cp -r "$DIR/tests" "$work/tests"

# Force a known OLD pre-state in the temp copy so the test is deterministic
# regardless of what the repo's install-openmp.sh currently pins for clang 1700.
# We rewrite only the 1700 case block in the temp copy (never the repo file).
awk '
  /^    1700\)/ { in1700=1 }
  in1700 && /OPENMP_VERSION=/ && !ver_done {
    sub(/OPENMP_VERSION="[^"]*"/, "OPENMP_VERSION=\"19.1.0\""); ver_done=1
  }
  in1700 && /EXPECTED_SHA1=/ && !sha_done {
    sub(/EXPECTED_SHA1="[^"]*"/, "EXPECTED_SHA1=\"42a22fa5852bafc23ab31241d064f9be9aab8a0d\""); sha_done=1
  }
  in1700 && /^    ;;/ { in1700=0 }
  { print }
' "$work/install-openmp.sh" > "$work/install-openmp.sh.tmp" \
  && mv "$work/install-openmp.sh.tmp" "$work/install-openmp.sh"

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
