#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
for t in "$DIR"/test-*.sh; do
  echo "== $(basename "$t") =="
  bash "$t" || rc=1
done
exit $rc
