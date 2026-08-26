# This envelope is the contract BarWidget.qml consumes, so these are the widget's
# contract tests as much as the CLI's.
j=$(omcron list --json)
assert_eq "empty: count 0"    "$(jq -r .count <<<"$j")"   "0"
assert_eq "empty: not active" "$(jq -r .active <<<"$j")"  "false"
assert_eq "empty: tooltip"    "$(jq -r .tooltip <<<"$j")" "No scheduled jobs"

omcron add a1 --at daily --auto --desc 'Alpha' --run echo hi >/dev/null
j=$(omcron list --json)
assert_eq "one job: count"    "$(jq -r .count <<<"$j")"   "1"
assert_eq "one job: waiting"  "$(jq -r .waiting <<<"$j")" "0"
assert_contains "singular wording" "$(jq -r .tooltip <<<"$j")" "1 job scheduled"
assert_contains "tooltip names the job" "$(jq -r .tooltip <<<"$j")" "Alpha"
assert_contains "tooltip marks the mode" "$(jq -r .tooltip <<<"$j")" "(auto)"

omcron add a2 --at daily --ask --desc 'Beta' --run echo hi >/dev/null
assert_contains "plural wording" "$(omcron list --json | jq -r .tooltip)" "2 jobs scheduled"

# Per-job fields the widget and the CLI table both rely on.
j=$(omcron list --json)
assert_eq "job carries its command" "$(jq -r '.jobs[]|select(.name=="a1")|.command' <<<"$j")" "echo hi"
assert_eq "job carries enabled"     "$(jq -r '.jobs[]|select(.name=="a1")|.enabled' <<<"$j")" "true"
next=$(jq -r '.jobs[]|select(.name=="a1")|.next' <<<"$j")
assert_not_contains "enabled job reports a real next run" "$next" "not scheduled"
[[ -n $next ]] && _ok "next run is populated" || _no "next run is populated" "empty"

# A pending approval must surface as waiting, and change the headline.
omcron fire a2
j=$(omcron list --json)
assert_eq "waiting counted"       "$(jq -r .waiting <<<"$j")" "1"
assert_eq "the right job waits"   "$(jq -r '.jobs[]|select(.name=="a2")|.waiting' <<<"$j")" "true"
assert_contains "headline changes when waiting" "$(jq -r .tooltip <<<"$j")" "1 job waiting for you"
