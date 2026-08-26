assert_ok "doctor is clean on an empty install" omcron doctor
omcron add d1 --at daily --auto --run echo hi >/dev/null
assert_ok "doctor is clean after a normal add" omcron doctor

# The case doctor exists for: a unit naming an omcron that has since moved.
svc=$(unit_file d1)
sed -i 's|^ExecStart=.*|ExecStart="/somewhere/else/omcron" fire "d1"|' "$svc"
assert_fails "doctor detects a stale unit path" omcron doctor
out=$(omcron doctor 2>&1 || true)
assert_contains "doctor explains the mismatch" "$out" "different omcron"

assert_ok "doctor --fix repairs it" omcron doctor --fix
assert_file_contains "unit now points at us" "$svc" "ExecStart=\"$OMCRON_SELF\""
assert_ok "doctor is clean again" omcron doctor

# Units left behind by a half-finished removal.
rm -f "$XDG_CONFIG_HOME/omcron/jobs/d1.json"
assert_fails "doctor reports orphan units" omcron doctor
assert_contains "orphans are named" "$(omcron doctor 2>&1 || true)" "units with no job"
