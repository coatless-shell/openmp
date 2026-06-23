#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }

[ -f "$DIR/test-openmp.sh" ] || fail "test-openmp.sh missing"
bash -n "$DIR/test-openmp.sh" || fail "test-openmp.sh has a syntax error"
grep -q 'omp_get_num_threads' "$DIR/test-openmp.sh" || fail "test-openmp.sh missing the OpenMP probe"
echo "PASS: test-openmp-syntax"
