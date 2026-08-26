omcron add l1 --at daily --auto --desc 'Life' --run echo hi >/dev/null
assert_eq "starts enabled" "$(omcron list --json | jq -r '.jobs[0].enabled')" "true"

omcron disable l1 >/dev/null
assert_eq "disable takes effect" "$(omcron list --json | jq -r '.jobs[0].enabled')" "false"
omcron enable l1 >/dev/null
assert_eq "enable takes effect" "$(omcron list --json | jq -r '.jobs[0].enabled')" "true"

omcron edit l1 --at hourly --ask --desc 'Renamed' >/dev/null
assert_file_contains "edit rewrites the timer" "$(timer_file l1)" "OnCalendar=hourly"
assert_eq "edit changes the mode" "$(omcron list --json | jq -r '.jobs[0].mode')" "ask"
assert_contains "edit changes the description" "$(omcron list --json | jq -r .tooltip)" "Renamed"
assert_fails "edit refuses to change the command" omcron edit l1 --run echo other

omcron edit l1 --persistent >/dev/null
assert_file_contains "edit can add persistence" "$(timer_file l1)" "Persistent=true"

# Every mutation should poke the bar so it never shows stale state.
assert_contains "mutations refresh the bar" "$(shell_log)" "netors.omcron refresh"

omcron run l1 >/dev/null
omcron rm l1 >/dev/null
assert_file_missing "rm removes the service" "$(unit_file l1)"
assert_file_missing "rm removes the timer" "$(timer_file l1)"
assert_file_exists  "rm keeps the log"      "$(job_log l1)"
assert_eq "rm removes the job" "$(omcron list --json | jq -r .count)" "0"
assert_fails "operating on a removed job fails" omcron show l1
