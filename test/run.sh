#!/usr/bin/env bash
# Runs every case in cases/. Each gets a fresh sandbox; nothing touches the real
# machine. See MANUAL.md for what this cannot cover.
set -uo pipefail

TEST_ROOT=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$TEST_ROOT/lib.sh"

total_pass=0
total_fail=0
only=${1:-}

for case_file in "$TEST_ROOT"/cases/*.sh; do
  name=$(basename "$case_file" .sh)
  [[ -n $only && $name != *"$only"* ]] && continue
  printf '\n%s\n' "$name"

  PASS=0
  FAIL=0
  sandbox_new
  # shellcheck disable=SC1090
  source "$case_file"
  sandbox_clean

  total_pass=$((total_pass + PASS))
  total_fail=$((total_fail + FAIL))
done

printf '\n----------------------------------------\n'
printf '%d passed, %d failed\n' "$total_pass" "$total_fail"
((total_fail == 0)) || exit 1
