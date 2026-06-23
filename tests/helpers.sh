#!/usr/bin/env bash
fail() { echo "FAIL: $1" >&2; exit 1; }
assert_eq() {
  # assert_eq actual expected message
  if [ "$1" != "$2" ]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$3" "$2" "$1" >&2
    exit 1
  fi
}
