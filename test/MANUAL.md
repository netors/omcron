# Manual test checklist

`test/run.sh` covers 110 assertions with stubs, but a CI runner has no systemd user
session, no Wayland, no notification daemon and no Omarchy binaries. This file is
what CI genuinely cannot prove. Walk it on a real Omarchy box before tagging a
release, and after any Omarchy upgrade.

Being explicit about the gap is the point — a green CI badge on this repo does not
mean the approval flow works.

## The biggest gap, stated plainly

The stubbed picker asserts **the labels omcron sends**, not that
`omarchy-menu-select` returns them unchanged. If that tool ever changes its return
format, all five branches of `cmd_respond` break and **CI stays green**. Item 4
below is the only thing that catches it.

## Checklist

### 1. Scheduling
- [ ] `omcron add t --at "*:0/2" --auto --run touch /tmp/omcron-fired` — fires within
      two minutes and writes the file.
- [ ] `journalctl --user -u omcron-t.service` shows a clean run.
- [ ] A job calling a tool from a mise shim or `~/.local/bin` resolves it. This is
      what the captured `PATH` exists for; a bare systemd user service would fail.
- [ ] `--persistent` job scheduled while the machine is suspended runs on resume.

### 2. Notifications
- [ ] `--auto` success posts a toast that clears itself.
- [ ] `--auto` failure posts a **critical** toast that does *not* clear itself, and
      names the exit status.
- [ ] Clicking either opens the log in a terminal.

### 3. Approval requests
- [ ] `omcron test <ask-job>` posts a request that **stays on screen indefinitely**.
      If it disappears after a few seconds, the urgency regression is back.
- [ ] Ignore the request, restart the shell (`omarchy restart shell`), open
      notification history: the request is still there and still clickable.
- [ ] Fire twice, then click the **older** toast: it must be refused as superseded,
      with no picker.

### 4. The picker (the untestable part)
- [ ] Click a request. All five options appear: Run now, Skip this one,
      Snooze 15 minutes, Snooze 1 hour, Open the log.
- [ ] **Run now** runs the job and logs it.
- [ ] **Skip this one** runs nothing; the next scheduled run is unchanged.
- [ ] **Snooze 15 minutes** re-posts after ~15 min; `systemctl --user list-timers`
      shows a transient `omcron-snooze-*` unit that disappears afterwards.
- [ ] **Open the log** opens a terminal and **leaves the request pending**.
- [ ] **Esc** re-posts the same request rather than discarding it.

### 5. Bar widget
- [ ] Appears after `omarchy plugin add … --enable` plus `install.sh`.
- [ ] Hovering shows the count and one line per job with its next run.
- [ ] Glyph changes to the alert form **and takes the urgent colour** when a job is
      waiting.
- [ ] Clicking with something waiting opens the picker; clicking with nothing
      waiting posts a summary toast.
- [ ] With `omcron` not on PATH, the widget dims and its tooltip says to run
      `install.sh`.
- [ ] The three settings appear in the bar's settings UI and take effect:
      `showWhenEmpty`, `attentionOnly`, `refreshIntervalSec`.
- [ ] On a multi-monitor setup, a CLI change refreshes the widget on every bar.

### 6. Plugin lifecycle
- [ ] `omarchy plugin validate .` passes.
- [ ] `omarchy plugin add <url> --enable --yes` installs and enables it.
- [ ] `omarchy bar put netors.omcron --section center --after omarchy.indicators`
      places it.
- [ ] Push a commit, then `omarchy plugin update netors.omcron` fast-forwards,
      shows a sensible diff and re-validates.
- [ ] `omarchy plugin remove netors.omcron` removes the widget. `~/.local/bin/omcron`
      is then a dangling symlink — `omcron doctor` should say so, and
      `install.sh --uninstall` cleans it up.

### 7. Upgrade path
- [ ] From a cloned-indicator install: `omarchy plugin remove <user>.indicators`
      restores the stock Indicators widget, and existing jobs keep running.
- [ ] After moving the CLI, `omcron doctor` reports stale unit paths and `--fix`
      repairs them.

## Not covered anywhere

- **QML is never linted.** `qmllint` cannot resolve `qs.Ui` / `qs.Commons` without
  the Omarchy shell tree, so `test/check-manifest.sh` greps for id consistency and
  the rest is caught only by item 5.
- **Omarchy's own interfaces are not versioned.** `omarchy-notification-send --exec`
  argv semantics, `omarchy-menu-select`'s return format, `omarchy-shell -q`, and the
  urgency-to-toast-lifetime mapping can all change without notice. Re-run sections 3
  and 4 after every Omarchy upgrade.
