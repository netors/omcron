# Security

## What this software can do

`omcron` runs commands you have configured, on a schedule, as your user. The bar
widget runs inside the long-lived `omarchy-shell` process and is not sandboxed.

Because a plugin is a git repo that `omarchy plugin update` fast-forwards, you are
shown `git diff HEAD FETCH_HEAD` before every update. Read it. That diff is the
security boundary.

## Design notes relevant to security

- **Commands are stored and executed as argv vectors**, never as strings, so an
  argument containing spaces or shell metacharacters stays one argument and cannot
  become a command. `--shell` is the explicit opt-in to shell interpretation.
- **Approval tokens live in `$XDG_RUNTIME_DIR`**, falling back to a per-uid
  directory created mode 700. A predictable path under a world-writable parent
  would let another local user plant a token, which on a consent gate is a forged
  approval.
- **The token guard fails closed.** A click authorises a run only while its token
  is still the pending token. No pending file, or a different one, is refused.
  This matters because Omarchy persists a notification's click action as data, so
  a toast stays clickable long after the request that created it.
- **Job names are validated** before being interpolated into unit file paths.

## Reporting

Open a GitHub issue for anything non-sensitive. For something you would rather not
post publicly, use GitHub's private vulnerability reporting on this repository.

## Vendored code

`test/plugin-validate.sh` is a verbatim copy of Omarchy's `omarchy-plugin-validate`,
used so CI enforces exactly the rules the real installer enforces. Its header records
the Omarchy version it came from; re-diff it after an Omarchy upgrade.
