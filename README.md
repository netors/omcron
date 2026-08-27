# omcron

**Scheduled jobs for [Omarchy](https://omarchy.org/) that either run on their own, or ask permission first.**

Each job is `--auto` (runs on schedule, then tells you how it went) or `--ask` (posts a
notification and runs nothing until you click it).

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

The first installs the bar widget. The second puts the `omcron` command on your `PATH`.
Both are needed — `omarchy plugin add` never runs code from a plugin.

> The plugin directory is named from the **plugin id**, so the repo `netors/omcron`
> installs to `~/.config/omarchy/plugins/netors.omcron/`.

Place the bar widget:

```bash
omarchy bar put netors.omcron --section center --after omarchy.indicators
```

**CLI only**, without the widget:

```bash
git clone https://github.com/netors/omcron.git && cd omcron && ./install.sh
```

**Updating:**

```bash
omarchy plugin update netors.omcron
```

**Requirements:** `bash` 4+, `jq`, a systemd user instance, and a Nerd Font for the bar
glyphs. Notifications and the approval picker use `omarchy-notification-send` and
`omarchy-menu-select`; set `OMCRON_NOTIFY` / `OMCRON_PICKER` to use `notify-send`,
`fuzzel` or `rofi` instead.

## Commands

| Command | Does |
|---|---|
| `add <name>` | Create a job. `--at`, `--auto`/`--ask`, `--persistent`, `--desc`, then `--run` or `--shell` |
| `list [--json]` | Every job, schedule, next run and command |
| `show <name>` | One job in full, including its log path |
| `run <name>` | Run it now, without asking |
| `test <name>` | Pretend it came due — an ask job really does ask |
| `log <name> [n]` | Output of past runs |
| `pending` | Requests waiting on you |
| `answer` | Open the menu for the oldest waiting request |
| `status` | Post a summary of the schedule as a notification |
| `edit <name>` | Change schedule, mode, description or persistence |
| `enable` / `disable` | Resume or pause a job without deleting it |
| `rm <name>` | Delete the job. Its log is kept |
| `doctor [--fix]` | Check the install and repair what it can |
| `version` | Print the version |

`--run` takes the command as **separate words** and consumes the rest of the line, so it
must come last. Use `--shell '<line>'` when you need pipes, globs or redirection. To
change a job's command, remove it and add it again.

## Schedules

Systemd `OnCalendar` expressions, not five-field cron. Each one is validated when you add
the job, so a typo is rejected immediately rather than silently never firing.

| Expression | Runs |
|---|---|
| `daily` / `hourly` / `weekly` | midnight / on the hour / Mondays |
| `Mon..Fri 09:30` | weekdays at 09:30 |
| `*:0/15` | every 15 minutes |
| `Sun *-*-* 04:00` | Sundays at 04:00 |
| `2026-12-25 09:00` | once, at that moment |

Cron's `*/15 * * * *` is not accepted — write `*:0/15`. Check any expression with
`systemd-analyze calendar '<expr>'`.

`--persistent` runs a job at the next boot if the machine was off at its scheduled time,
instead of skipping it.

## Approving a job

An `--ask` job posts a notification that stays until you act on it, and remains clickable
in notification history if you miss it. Clicking opens a menu:

| Choice | Does |
|---|---|
| Run now | Runs the command and reports the result |
| Skip this one | Declines this run. The schedule is unchanged |
| Snooze 15m / 1h | Asks again later. The schedule is unchanged |
| Open the log | Shows past output. The request stays waiting |
| Esc | Closes the menu. The request comes back |

Ignoring a request means the job does not run; the next scheduled time replaces it. There
is no automatic fallback to running it.

`omcron pending` lists what is waiting, `omcron answer` opens the menu from the terminal.

## The bar widget

Shows a timer glyph when jobs are scheduled, and an alert glyph in the urgent colour when
one is waiting on you. Hovering lists every job and when it next runs. Clicking answers
the oldest waiting request, or posts a summary if there is none.

| Setting | Default | Does |
|---|---|---|
| `showWhenEmpty` | `true` | Stay on the bar, dimmed, when there are no jobs |
| `attentionOnly` | `false` | Hide unless something is waiting. Overrides the above |
| `refreshIntervalSec` | `60` | How often it re-reads state. CLI changes refresh it immediately regardless |

## Files

| Path | Holds |
|---|---|
| `~/.config/omcron/jobs/<name>.json` | Job definition: schedule, argv, mode, captured PATH |
| `~/.config/systemd/user/omcron-<name>.{service,timer}` | Generated units — never hand-edit |
| `~/.local/state/omcron/<name>.log` | Run output with timestamps and exit status |
| `$XDG_RUNTIME_DIR/omcron/pending/<name>.json` | The live approval token, mode 700 |

Jobs run under systemd, so `systemctl --user list-timers 'omcron-*'` and
`journalctl --user -u omcron-<name>.service` work as usual.

## Troubleshooting

Start with `omcron doctor`. It checks that everything needed is present, that each job's
units exist and point at the right place, and that nothing was left behind. `--fix`
repairs what it can.

If a job did not run: check it is enabled (`omcron list`), that the machine was awake at
the time (or add `--persistent`), and that it is not an ask job still waiting
(`omcron pending`).

Jobs run with the `PATH` captured when they were created, so a tool installed somewhere
new afterwards will not be found — remove and re-add the job from a shell where the
command works.

## Uninstall

```bash
omcron rm <name>                         # remove a job and its units
~/.config/omarchy/plugins/netors.omcron/install.sh --uninstall
omarchy plugin remove netors.omcron
```

Logs under `~/.local/state/omcron/` are left behind.

## Contributing

```bash
./test/run.sh            # 110 assertions, no systemd or Wayland needed
./test/check-manifest.sh # the plugin id must agree in four places
./test/plugin-validate.sh .
```

The suite stubs the notifier, picker and systemd, so the approval path is exercised
without a human clicking. `test/MANUAL.md` lists what CI cannot cover — walk it before
tagging a release.

**`main` is never force-pushed or rebased.** `omarchy plugin update` is
`git merge --ff-only`, so a rewritten history breaks the update for everyone who has it
installed. PRs are squash-merged.

## Documentation

Full user guide: **<https://netors.github.io/omcron/>**

## Licence

MIT. See [SECURITY.md](SECURITY.md) for the threat model.
