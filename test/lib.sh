#!/usr/bin/env bash
# Test harness. Each case gets a throwaway sandbox: its own XDG dirs, its own
# runtime dir, and the stubs first on PATH. Nothing touches the real machine.

TEST_ROOT=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -P -- "$TEST_ROOT/.." && pwd)
OMCRON_BIN="$REPO_ROOT/bin/omcron"

PASS=0
FAIL=0
CURRENT=""

sandbox_new() {
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/omcron-test.XXXXXX")
  export SANDBOX
  export XDG_CONFIG_HOME="$SANDBOX/config"
  export XDG_STATE_HOME="$SANDBOX/state"
  export XDG_RUNTIME_DIR="$SANDBOX/run"
  export OMCRON_TEST_LOG="$SANDBOX/logs"
  export OMCRON_TEST_STATE="$SANDBOX/teststate"
  # Without this, generated units would name a real ~/.local/bin/omcron that may
  # not exist on a CI runner.
  export OMCRON_SELF="$OMCRON_BIN"
  export PATH="$TEST_ROOT/stubs:$PATH"
  export TZ=UTC
  export LC_ALL=C
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" \
    "$OMCRON_TEST_LOG" "$OMCRON_TEST_STATE"
  : >"$OMCRON_TEST_STATE/choices"
}

sandbox_clean() {
  [[ -n ${SANDBOX:-} && -d $SANDBOX ]] && rm -rf "$SANDBOX"
}

omcron() { "$OMCRON_BIN" "$@"; }

queue_choice() { printf '%s\n' "$1" >>"$OMCRON_TEST_STATE/choices"; }

notify_log() { tr '\0' '\n' <"$OMCRON_TEST_LOG/notify.log" 2>/dev/null || true; }
menu_log() { tr '\0' '\n' <"$OMCRON_TEST_LOG/menu.log" 2>/dev/null || true; }
shell_log() { cat "$OMCRON_TEST_LOG/shell.log" 2>/dev/null || true; }
runner_log() { cat "$OMCRON_TEST_LOG/systemd-run.log" 2>/dev/null || true; }

unit_file() { echo "$XDG_CONFIG_HOME/systemd/user/omcron-$1.service"; }
timer_file() { echo "$XDG_CONFIG_HOME/systemd/user/omcron-$1.timer"; }
pending_file() { echo "$XDG_RUNTIME_DIR/omcron/pending/$1.json"; }
job_log() { echo "$XDG_STATE_HOME/omcron/$1.log"; }

# ---------------------------------------------------------------- assertions

_ok() {
  PASS=$((PASS + 1))
  printf '  ok   %s\n' "$1"
}
_no() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n' "$1"
  [[ -n ${2:-} ]] && printf '       %s\n' "$2"
}

assert_ok() {
  local desc=$1
  shift
  if "$@" >"$SANDBOX/out" 2>"$SANDBOX/err"; then
    _ok "$desc"
  else
    _no "$desc" "exited $? — $(tail -2 "$SANDBOX/err" | tr '\n' ' ')"
  fi
}

assert_fails() {
  local desc=$1
  shift
  if "$@" >"$SANDBOX/out" 2>"$SANDBOX/err"; then
    _no "$desc" "expected non-zero exit, got 0"
  else
    _ok "$desc"
  fi
}

assert_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack == *"$needle"* ]]; then
    _ok "$desc"
  else
    _no "$desc" "missing: $needle"
  fi
}

assert_not_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack != *"$needle"* ]]; then
    _ok "$desc"
  else
    _no "$desc" "should not contain: $needle"
  fi
}

assert_file_contains() {
  local desc=$1 file=$2 needle=$3
  if [[ -f $file ]] && grep -qF -- "$needle" "$file"; then
    _ok "$desc"
  else
    _no "$desc" "$file lacks: $needle"
  fi
}

assert_file_exists() {
  if [[ -e $2 ]]; then _ok "$1"; else _no "$1" "missing: $2"; fi
}

assert_file_missing() {
  if [[ ! -e $2 ]]; then _ok "$1"; else _no "$1" "should not exist: $2"; fi
}

assert_eq() {
  local desc=$1 got=$2 want=$3
  if [[ $got == "$want" ]]; then
    _ok "$desc"
  else
    _no "$desc" "got '$got', want '$want'"
  fi
}
