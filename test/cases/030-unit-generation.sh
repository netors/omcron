omcron add u1 --at 'Mon..Fri 09:30' --ask --desc 'Unit test' --run mise upgrade claude >/dev/null
svc=$(unit_file u1); tmr=$(timer_file u1)

assert_file_exists "service written" "$svc"
assert_file_exists "timer written" "$tmr"
# The portability bug: ExecStart must use the resolved SELF, quoted.
assert_file_contains "ExecStart uses resolved SELF" "$svc" "ExecStart=\"$OMCRON_SELF\" fire \"u1\""
assert_file_contains "PATH is captured" "$svc" "Environment=\"PATH="
assert_file_contains "OnCalendar verbatim" "$tmr" "OnCalendar=Mon..Fri 09:30"
assert_file_contains "timer targets the service" "$tmr" "Unit=omcron-u1.service"
assert_file_contains "installed into timers.target" "$tmr" "WantedBy=timers.target"
assert_not_contains "no Persistent without the flag" "$(cat "$tmr")" "Persistent=true"

omcron add u2 --at daily --auto --persistent --run echo hi >/dev/null
assert_file_contains "--persistent emits Persistent" "$(timer_file u2)" "Persistent=true"

# systemd expands % in unit files, so a % in PATH must be escaped or the unit is
# silently corrupt.
PATH="/opt/we%ird:$PATH" omcron add u3 --at daily --auto --run echo hi >/dev/null
assert_file_contains "percent in PATH is escaped" "$(unit_file u3)" "/opt/we%%ird"

# A newline in the description would end Description= and inject a directive.
omcron add u4 --at daily --auto --desc "$(printf 'line one\nInjected=yes')" --run echo hi >/dev/null
# The danger is a NEW LINE starting with a directive, not the text appearing at all.
if grep -qE '^Injected=' "$(unit_file u4)"; then
  _no "newline in desc cannot inject a directive" "Injected= became its own line"
else
  _ok "newline in desc cannot inject a directive"
fi

# A space in the install path must survive into ExecStart.
mkdir -p "$SANDBOX/we ird"; cp "$OMCRON_BIN" "$SANDBOX/we ird/omcron"
OMCRON_SELF="$SANDBOX/we ird/omcron" omcron add u5 --at daily --auto --run echo hi >/dev/null
assert_file_contains "space in path is quoted" "$(unit_file u5)" "ExecStart=\"$SANDBOX/we ird/omcron\""
