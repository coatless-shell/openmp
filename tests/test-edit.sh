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
# replace_block must refuse (non-zero, file unchanged) when END marker is absent
tmp2=$(mktemp); content2=$(mktemp)
printf 'head\n# >>> BEGIN GENERATED X (managed by sync-openmp.sh; do not edit) >>>\nOLD\ntail\n' > "$tmp2"
printf 'NEW\n' > "$content2"
orig2=$(cat "$tmp2")
if OPENMP_SYNC_LIB=1 replace_block "$tmp2" "BEGIN GENERATED X" "END GENERATED X" "$content2" 2>/dev/null; then
  fail "replace_block should return non-zero when END marker is missing"
fi
got2=$(cat "$tmp2")
rm -f "$tmp2" "$content2"
assert_eq "$got2" "$orig2" "replace_block leaves file unchanged when END marker is missing"

# replace_block preserves the file's executable bit (must use portable stat:
# GNU `stat -c %a` on Linux, BSD `stat -f %Lp` on macOS)
tmp3=$(mktemp); content3=$(mktemp)
printf 'head\n# >>> BEGIN GENERATED X (managed by sync-openmp.sh; do not edit) >>>\nOLD\n# <<< END GENERATED X <<<\ntail\n' > "$tmp3"
printf 'NEW\n' > "$content3"
chmod +x "$tmp3"
replace_block "$tmp3" "BEGIN GENERATED X" "END GENERATED X" "$content3"
if [ -x "$tmp3" ]; then exec_ok=yes; else exec_ok=no; fi
rm -f "$tmp3" "$content3"
assert_eq "$exec_ok" "yes" "replace_block preserves the executable bit"

echo "PASS: test-edit"
