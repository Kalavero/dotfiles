#!/usr/bin/env bash

set -u

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_directory() {
  [ -d "$1" ] || fail "expected directory: $1"
}

assert_symlink() {
  [ -L "$1" ] || fail "expected symlink: $1"
}

assert_contains() {
  local expected="$1"
  local file="$2"

  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local unexpected="$1"
  local file="$2"

  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}
