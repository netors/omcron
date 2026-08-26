marker="$SANDBOX/ok"
omcron add good --at daily --auto --desc 'Good job' --shell "echo hello >>'$marker'" >/dev/null
omcron run good
assert_file_exists "run executes the command" "$marker"
assert_file_contains "log records the run" "$(job_log good)" "exit=0"
n=$(notify_log)
assert_contains "success is announced" "$n" "Good job"
assert_contains "success toast opens the log" "$n" "log"

omcron add bad --at daily --auto --desc 'Bad job' --shell 'exit 3' >/dev/null
omcron run bad
assert_file_contains "log records the failure" "$(job_log bad)" "exit=3"
n=$(notify_log)
assert_contains "failure is critical" "$n" "critical"
assert_contains "failure names the status" "$n" "Exit status 3"

# argv form must survive an argument containing spaces without being re-split.
omcron add spaced --at daily --auto --run printf '%s\n' 'one two three' >/dev/null
argv=$(omcron list --json | jq -r '.jobs[]|select(.name=="spaced")|.argv|join("|")')
assert_contains "spaces stay inside one argument" "$argv" "one two three"
