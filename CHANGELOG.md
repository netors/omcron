# Changelog

## 1.0.0

First release.

- Repeating jobs on systemd user timers, in two modes: `--auto` runs unattended
  and reports the outcome, `--ask` posts a clickable notification and runs
  nothing until you approve it.
- Approval picker: Run now / Skip / Snooze 15m / Snooze 1h / Open the log.
- One-shot tokens guard the approval, so a stale notification cannot run a job.
- `--persistent` catches up a run missed while the machine was off.
- Bar widget showing scheduled jobs, their next run, and anything waiting on you.
- `omcron doctor [--fix]` checks the install and repairs stale unit paths.
- 110 automated tests, including regressions for all three approval-gate bugs
  found during development.
