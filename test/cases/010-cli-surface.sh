out=$(omcron --help 2>&1); assert_contains "help mentions add" "$out" "omcron add"
assert_ok "help exits 0" omcron --help
out=$(omcron version 2>&1); assert_contains "version prints a number" "$out" "omcron 1."
assert_fails "unknown command exits non-zero" omcron definitely-not-a-command
out=$(omcron list 2>&1); assert_contains "empty list is friendly" "$out" "No jobs yet"

# Every command in usage() must be routable. Catches "documented but unreachable".
documented=$(omcron --help | sed -n 's/^  omcron \([a-z|]*\).*/\1/p' | tr '|' '\n' | sort -u)
for cmd in $documented; do
  [[ $cmd == "add" || $cmd == "version" ]] && continue
  if omcron "$cmd" --help >/dev/null 2>&1 || omcron "$cmd" nonexistent-job >/dev/null 2>&1; then :; fi
  err=$(omcron "$cmd" 2>&1 || true)
  assert_not_contains "documented '$cmd' is routed" "$err" "unknown command"
done
