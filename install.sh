#!/usr/bin/env bash
#
# Puts the omcron CLI on your PATH.
#
# This deliberately does NOT install the bar widget: `omarchy plugin add` is the
# only path that produces a git checkout, and only a git checkout can be updated
# by `omarchy plugin update` later. A widget copied into place by hand is a
# widget that can never be updated.

set -euo pipefail

REPO=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE="link"
PREFIX=""
ASSUME_YES=0
DO_UNINSTALL=0

usage() {
  cat <<'USAGE'
Usage: install.sh [--copy] [--prefix DIR] [--yes] [--uninstall]

  --copy        copy the CLI instead of symlinking it. Symlinking is the default
                so `omarchy plugin update` updates the CLI along with the widget.
  --prefix DIR  install into DIR (default: $XDG_BIN_HOME, else ~/.local/bin)
  --yes         do not prompt before replacing an existing file
  --uninstall   remove the CLI this script installed. Jobs, logs and units are
                left alone; `omcron rm <name>` removes those.
USAGE
}

while (($# > 0)); do
  case $1 in
  --copy) MODE="copy" ;;
  --prefix)
    shift
    (($# > 0)) || {
      echo "install.sh: --prefix needs a directory" >&2
      exit 1
    }
    PREFIX=$1
    ;;
  --yes | -y) ASSUME_YES=1 ;;
  --uninstall) DO_UNINSTALL=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "install.sh: unknown option $1" >&2
    usage >&2
    exit 1
    ;;
  esac
  shift
done

BINDIR=${PREFIX:-${XDG_BIN_HOME:-$HOME/.local/bin}}
TARGET="$BINDIR/omcron"
SOURCE="$REPO/bin/omcron"

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

# ---------------------------------------------------------------- uninstall

if ((DO_UNINSTALL)); then
  if [[ ! -e $TARGET && ! -L $TARGET ]]; then
    say "Nothing installed at $TARGET"
  elif [[ -L $TARGET ]]; then
    link=$(readlink -f "$TARGET" 2>/dev/null || true)
    if [[ $link == "$SOURCE" ]]; then
      rm -f "$TARGET"
      say "Removed $TARGET"
    else
      die "$TARGET is a symlink to $link, which is not this repo. Leaving it alone."
    fi
  elif cmp -s "$TARGET" "$SOURCE"; then
    rm -f "$TARGET"
    say "Removed $TARGET"
  else
    die "$TARGET differs from this repo's copy. Leaving it alone."
  fi

  say ""
  say "Your jobs, units and logs were NOT touched. To remove those:"
  say "  omcron list          # see what exists"
  say "  omcron rm <name>     # remove one, including its systemd units"
  say ""
  say "To remove the bar widget:"
  say "  omarchy plugin remove netors.omcron"
  exit 0
fi

# ---------------------------------------------------------------- checks

[[ -f $SOURCE ]] || die "cannot find $SOURCE — run this from inside the repo"

missing=()
for c in jq systemctl systemd-analyze systemd-run; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
((${#missing[@]} == 0)) || die "missing required commands: ${missing[*]}"

if ((BASH_VERSINFO[0] < 4)); then
  die "bash 4 or newer is required (found $BASH_VERSION)"
fi

soft=()
for c in omarchy-notification-send omarchy-menu-select omarchy-shell; do
  command -v "$c" >/dev/null 2>&1 || soft+=("$c")
done
if ((${#soft[@]} > 0)); then
  warn "not found: ${soft[*]}"
  warn "the CLI will work, but notifications and the approval picker will not."
  warn "set OMCRON_NOTIFY / OMCRON_PICKER to alternatives if you are not on Omarchy."
fi

# ---------------------------------------------------------------- install

mkdir -p "$BINDIR"

if [[ -e $TARGET || -L $TARGET ]]; then
  keep=0
  if [[ -L $TARGET ]] && [[ $(readlink -f "$TARGET" 2>/dev/null || true) == "$SOURCE" ]]; then
    keep=1
  elif cmp -s "$TARGET" "$SOURCE" 2>/dev/null; then
    keep=1
  fi
  if ((keep == 0 && ASSUME_YES == 0)); then
    printf 'Replace existing %s? [y/N] ' "$TARGET"
    read -r reply </dev/tty || reply=""
    [[ $reply == [yY]* ]] || die "aborted"
  fi
fi

chmod +x "$SOURCE"
if [[ $MODE == "copy" ]]; then
  install -Dm755 "$SOURCE" "$TARGET"
  say "Copied  $TARGET"
  warn "with --copy, 'omarchy plugin update' will update the widget but not this copy."
  warn "re-run install.sh after each update, or use the default symlink install."
else
  ln -sfn "$SOURCE" "$TARGET"
  say "Linked  $TARGET -> $SOURCE"
fi

case ":$PATH:" in
*":$BINDIR:"*) ;;
*)
  warn "$BINDIR is not on your PATH."
  warn "add it to your shell profile, or re-run with --prefix pointing somewhere that is."
  ;;
esac

# ---------------------------------------------------------------- follow-ups

JOB_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omcron/jobs"
if compgen -G "$JOB_DIR/*.json" >/dev/null 2>&1; then
  say ""
  say "Existing jobs found — checking their unit files still point here:"
  "$TARGET" doctor --fix || true
fi

say ""
if [[ $REPO == *"/.config/omarchy/plugins/"* ]]; then
  say "Installed. The bar widget came with the plugin; place it with:"
  say "  omarchy bar put netors.omcron --section center --after omarchy.indicators"
else
  say "Installed. To also get the bar widget, install this as an Omarchy plugin:"
  say "  omarchy plugin add https://github.com/netors/omcron.git --enable --yes"
  say "  ~/.config/omarchy/plugins/netors.omcron/install.sh"
fi
say ""
say "Then try:"
say "  omcron add hello --at daily --auto --desc 'Smoke test' --run echo hi"
say "  omcron run hello && omcron log hello && omcron rm hello"
