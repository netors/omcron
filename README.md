# omcron

**Scheduled jobs for [Omarchy](https://omarchy.org/) that either run on their own, or ask permission first.**

Omarchy reminders are one-shot and inert — they tell you to do a thing, then forget.
Cron runs the thing but never asks, which is right for a backup and wrong for anything
that changes your tools, touches the network, or interrupts what you are doing.

`omcron` is the middle. A repeating job is either `--auto` (runs, then tells you how it
went) or `--ask` (posts a notification and runs **nothing** until you click it).

```bash
# every weekday at 09:30, ask before upgrading
omcron add claude --at 'Mon..Fri 09:30' --ask --desc 'Upgrade Claude' \
  --run mise upgrade claude

# every Sunday, just do it
omcron add trash --at weekly --auto --persistent \
  --shell 'find ~/.local/share/Trash -mtime +30 -delete'
```

Clicking an `--ask` notification offers **Run now · Skip this one · Snooze 15m ·
Snooze 1h · Open the log**.

## Install

```bash
omarchy plugin add https://github.com/netors/omcron.git --enable --yes
~/.config/omarchy/plugins/netors.omcron/install.sh
```

Two steps, because `omarchy plugin add` deliberately never runs code from a plugin.
The first installs the bar widget; the second puts the `omcron` command on your PATH.

> The plugin directory is named from the **plugin id**, not the repo — so the repo
> `netors/omcron` installs to `~/.config/omarchy/plugins/netors.omcron/`.

Place the bar widget wherever you like:

```bash
omarchy bar put netors.omcron --section center --after omarchy.indicators
```

**CLI only**, without the widget, and without Omarchy:

```bash
git clone https://github.com/netors/omcron.git && cd omcron && ./install.sh
```

**Requirements:** `bash` 4+, `jq`, `systemd` (user instance). For notifications and the
approval picker: `omarchy-notification-send` and `omarchy-menu-select`. Set
`OMCRON_NOTIFY` / `OMCRON_PICKER` to point at `notify-send`, `fuzzel` or `rofi` instead.
A Nerd Font for the bar glyphs.

## Commands

| Command | Does |
|---|---|
| `add <name>` | Create a job. `--at`, `--auto`/`--ask`, `--persistent`, `--desc`, then `--run` or `--shell` |
| `list [--json]` | Every job, schedule, next run, command |
| `show <name>` | One job in full, including its log path |
| `run <name>` | Run it now, no questions |
| `test <name>` | Simulate a scheduled fire — an ask job really does ask |
| `log <name> [n]` | Output of past runs |
| `pending` | Requests waiting on you |
| `edit <name>` | Change schedule, mode, description, persistence |
| `enable` / `disable` | Stop or resume the timer, keeping the job |
| `rm <name>` | Remove the job and its units. The log is kept |
| `doctor [--fix]` | Check the install; repair stale unit paths |

`--run` takes the command as **separate words** and consumes the rest of the line, so it
must come last. An argument containing spaces stays one argument and can never be
re-parsed into a command. Use `--shell '<line>'` when you actually want pipes or globs.

## Schedules

Systemd `OnCalendar` expressions, not five-field cron. Every schedule is validated with
`systemd-analyze calendar` when you add it, so a typo is rejected immediately rather than
silently never firing.

| Expression | Means |
|---|---|
| `daily` / `hourly` / `weekly` | midnight / on the hour / Mondays |
| `Mon..Fri 09:30` | weekdays at 09:30 |
| `*:0/15` | every 15 minutes |
| `Sun *-*-* 04:00` | Sundays at 04:00 |
| `2026-08-26 15:33` | once, at that moment |

`--persistent` sets `Persistent=true`, so a run missed while the machine was off happens
at the next boot instead of being skipped.

## How approval works

1. The timer fires. An `--auto` job stops here and runs.
2. An `--ask` job mints a **one-shot token** and posts a notification whose click action
   is `omcron respond <job> <token>`.
3. The notification is `critical`, so it never times out. And because Omarchy stores a
   toast's click action as data rather than as a libnotify action, an unanswered request
   **stays clickable in notification history**, even across a shell restart.
4. Clicking validates the token and opens the picker. The guard **fails closed**: a click
   authorises a run only while its token is still the pending one.

Only a real decision spends the token. Reading the log doesn't, and neither does
dismissing the picker — Esc re-posts the same request, so an accidental keypress costs
nothing. Ignoring a request entirely means the job does not run; there is no escalation.

## The bar widget

Shows a timer glyph when jobs are scheduled and an alert glyph, in the urgent colour,
when one is waiting on you. Hovering lists every job and when it next runs. Clicking
answers the oldest outstanding request, or posts a summary if there is none.

| Setting | Default | Does |
|---|---|---|
| `showWhenEmpty` | `true` | Stay on the bar, dimmed, when there are no jobs |
| `attentionOnly` | `false` | Hide unless something is waiting. Overrides the above |
| `refreshIntervalSec` | `60` | How often to re-read state. CLI changes refresh it immediately regardless |

## Files

| Path | Holds |
|---|---|
| `~/.config/omcron/jobs/<name>.json` | Job definition: schedule, argv, mode, captured PATH |
| `~/.config/systemd/user/omcron-<name>.{service,timer}` | Generated units — never hand-edit |
| `~/.local/state/omcron/<name>.log` | Run output with timestamps and exit status |
| `$XDG_RUNTIME_DIR/omcron/pending/<name>.json` | The live approval token, mode 700 |

## Upgrading from the cloned-indicator install

Early versions added an indicator to Omarchy's stock cluster, which required cloning that
widget. Ship-and-forget was never viable — the clone forks you off upstream updates. To
move over:

```bash
omarchy plugin remove <user>.indicators    # restores the stock widget
omarchy plugin add https://github.com/netors/omcron.git --enable --yes
~/.config/omarchy/plugins/netors.omcron/install.sh
omcron doctor --fix                        # repoint units at the new CLI location
```

Your jobs are untouched throughout.

## Uninstall

```bash
omcron list                              # see what exists
omcron rm <name>                         # remove a job and its units
~/.config/omarchy/plugins/netors.omcron/install.sh --uninstall
omarchy plugin remove netors.omcron
```

## Contributing

```bash
./test/run.sh            # 110 assertions, no systemd or Wayland needed
./test/check-manifest.sh # the plugin id must agree in four places
./test/plugin-validate.sh .
```

The suite stubs the notifier, picker and systemd, which is what makes the approval path
testable at all — every bug this tool has had lived there. `test/MANUAL.md` is the
honest list of what CI cannot cover; walk it before tagging.

**`main` is never force-pushed or rebased.** `omarchy plugin update` is
`git merge --ff-only`, so a rewritten history breaks the update for everyone who has it
installed. PRs are squash-merged.

## Documentation

Full reference, design rationale, and two non-obvious findings about Omarchy's
notification system: **<https://netors.github.io/omcron/>**

## Licence

MIT. See [SECURITY.md](SECURITY.md) for the threat model.
