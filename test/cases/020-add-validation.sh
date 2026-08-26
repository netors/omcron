assert_fails "add without --at"           omcron add j1 --auto --run echo hi
assert_fails "add without a command"      omcron add j1 --at daily --auto
# --shell must come before --run, since --run consumes the rest of the line.
assert_fails "add with both run and shell" omcron add j1 --at daily --shell 'echo hi' --run echo hi
assert_fails "add with a bad schedule"    omcron add j1 --at 'not-a-schedule' --auto --run echo hi
assert_fails "add with an invalid name"   omcron add 'bad name' --at daily --auto --run echo hi
assert_fails "add with ../ in the name"   omcron add '../escape' --at daily --auto --run echo hi

# A whole command passed as one quoted string would run a program of that literal
# name; the guard tells you to use --shell instead.
assert_fails "add rejects one quoted command string" omcron add j1 --at daily --auto --run 'echo hi there'

assert_ok "valid add succeeds" omcron add j1 --at daily --auto --desc 'One' --run echo hi
assert_fails "duplicate name is refused" omcron add j1 --at daily --auto --run echo hi

# Nothing above should have left a stray job behind.
count=$(omcron list --json | jq '.count')
assert_eq "exactly one job exists" "$count" "1"
