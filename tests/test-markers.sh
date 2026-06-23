#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }

# Every BEGIN marker has a matching END marker in each file.
for f in install-openmp.sh README.md; do
  b=$(grep -c 'BEGIN GENERATED' "$DIR/$f" || true)
  e=$(grep -c 'END GENERATED' "$DIR/$f" || true)
  [ "$b" -ge 1 ] || fail "$f: no BEGIN markers"
  [ "$b" = "$e" ] || fail "$f: $b BEGIN vs $e END markers"
done

# install-openmp.sh must still be valid bash.
bash -n "$DIR/install-openmp.sh" || fail "install-openmp.sh has a syntax error"

# Required generated-block names are present.
grep -q 'BEGIN GENERATED VERSION CASES' "$DIR/install-openmp.sh" || fail "missing VERSION CASES block"
grep -q 'BEGIN GENERATED HELP VERSIONS' "$DIR/install-openmp.sh" || fail "missing HELP VERSIONS block"
grep -q 'BEGIN GENERATED README TABLE' "$DIR/README.md" || fail "missing README TABLE block"
echo "PASS: test-markers"
