#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/tests/helpers.sh"
OPENMP_SYNC_LIB=1 . "$DIR/sync-openmp.sh"

# current_pin reads the live install-openmp.sh
pin=$(current_pin 1600 "$DIR/install-openmp.sh")
assert_eq "$pin" $'17.0.6\ta89cab4e763025f03a5d12a93a609ff771ad209c' "current_pin 1600"
assert_eq "$(current_pin 9999 "$DIR/install-openmp.sh")" "" "current_pin unknown -> empty"

# resolve_sha trust-page path is offline + deterministic
assert_eq "$(OPENMP_SYNC_TRUST_PAGE=1 resolve_sha 19.1.5 darwin20 deadbeef)" "deadbeef" "resolve_sha trust-page"

# replace_block swaps content between markers, atomically
tmp=$(mktemp); content=$(mktemp)
printf 'head\n# >>> BEGIN GENERATED X (managed by sync-openmp.sh; do not edit) >>>\nOLD\n# <<< END GENERATED X <<<\ntail\n' > "$tmp"
printf 'NEW1\nNEW2\n' > "$content"
replace_block "$tmp" "BEGIN GENERATED X" "END GENERATED X" "$content"
got=$(cat "$tmp"); rm -f "$tmp" "$content"
want=$'head\n# >>> BEGIN GENERATED X (managed by sync-openmp.sh; do not edit) >>>\nNEW1\nNEW2\n# <<< END GENERATED X <<<\ntail'
assert_eq "$got" "$want" "replace_block swaps between markers"
echo "PASS: test-edit"
