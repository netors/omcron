# The approval gate. Every bug this tool has had lived here, and none of them was
# reachable without a human clicking — which is the entire reason for the stubs.

marker="$SANDBOX/ran"
omcron add gate --at daily --ask --desc 'Gate test' --shell "echo ran >>'$marker'" >/dev/null

# --- fire posts a request and runs nothing -----------------------------------
omcron fire gate
assert_file_exists "fire creates a pending token" "$(pending_file gate)"
assert_file_missing "fire does NOT run the command" "$marker"

n=$(notify_log)
# BUG 1: requests went out at normal urgency and vanished after 8 seconds.
# Only critical returns duration 0 in the shell's durationFor().
assert_contains "request is critical (bug 1)" "$n" "critical"
assert_contains "request names the job" "$n" "Gate test"
assert_contains "click action calls respond" "$n" "respond"

token=$(jq -r .token "$(pending_file gate)")
assert_contains "notification carries the token" "$n" "$token"

# --- Run now spends the token -------------------------------------------------
queue_choice "Run now"
omcron respond gate "$token"
assert_file_exists "Run now executes the command" "$marker"
assert_file_missing "Run now spends the token" "$(pending_file gate)"

# --- BUG 2: the guard failed open ---------------------------------------------
# It was `if [[ -n $token && -f $pending ]]`, so once any click removed the
# pending file every stale toast fell through to the picker. Click actions are
# persisted as data and outlive the request, so old toasts stayed armed forever.
before=$(wc -l <"$marker")
queue_choice "Run now"
omcron respond gate "$token"
after=$(wc -l <"$marker")
assert_eq "replaying a spent token runs nothing (bug 2)" "$after" "$before"
assert_contains "replay is refused out loud" "$(notify_log)" "already answered"

# --- superseded token ---------------------------------------------------------
omcron fire gate
tok2=$(jq -r .token "$(pending_file gate)")
before=$(wc -l <"$marker")
queue_choice "Run now"
omcron respond gate "$token"    # the OLD token, while a newer request is pending
after=$(wc -l <"$marker")
assert_eq "stale token runs nothing" "$after" "$before"
assert_contains "stale token says superseded" "$(notify_log)" "superseded"
assert_file_exists "stale click leaves the live request intact" "$(pending_file gate)"

# --- BUG 3: Esc used to discard the occurrence --------------------------------
# Dismissing the picker consumed the token, making an accidental keypress LESS
# recoverable than ignoring the toast. It now re-posts the same token.
: >"$OMCRON_TEST_STATE/choices"        # empty queue == the stub exits 1 == Esc
omcron respond gate "$tok2"
assert_file_exists "Esc keeps the request pending (bug 3)" "$(pending_file gate)"
tok3=$(jq -r .token "$(pending_file gate)")
assert_eq "Esc keeps the SAME token" "$tok3" "$tok2"
assert_contains "Esc re-posts the request" "$(notify_log)" "Click to approve"

# --- Open the log is not a decision -------------------------------------------
queue_choice "Open the log"
omcron respond gate "$tok2"
assert_file_exists "reading the log keeps the request" "$(pending_file gate)"

# --- Skip spends without running ----------------------------------------------
before=$(wc -l <"$marker")
queue_choice "Skip this one"
omcron respond gate "$tok2"
after=$(wc -l <"$marker")
assert_eq "Skip runs nothing" "$after" "$before"
assert_file_missing "Skip spends the token" "$(pending_file gate)"

# --- Snooze arms a transient timer and leaves the schedule alone --------------
omcron fire gate
tok4=$(jq -r .token "$(pending_file gate)")
queue_choice "Snooze 15 minutes"
omcron respond gate "$tok4"
r=$(runner_log)
assert_contains "snooze arms a 15m timer" "$r" "on-active=15m"
assert_contains "snooze re-fires this job" "$r" "fire gate"
assert_file_missing "snooze spends the current token" "$(pending_file gate)"
assert_file_contains "recurrence is untouched" "$(timer_file gate)" "OnCalendar=daily"

# --- answer picks the oldest outstanding request ------------------------------
omcron add gate2 --at daily --ask --desc 'Second' --run echo hi >/dev/null
omcron fire gate; sleep 1; omcron fire gate2
queue_choice "Skip this one"
omcron answer
assert_file_missing "answer resolved the oldest request" "$(pending_file gate)"
assert_file_exists "answer left the newer one alone" "$(pending_file gate2)"
