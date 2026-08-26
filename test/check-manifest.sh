#!/usr/bin/env bash
# Consistency checks the real validator does not do: the plugin id appears in
# four places that must agree, and a setting exposed in the schema but never read
# is a silently dead knob.

set -uo pipefail

REPO=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO" || exit 1

fail=0
ok() { printf '  ok   %s\n' "$1"; }
no() {
  printf '  FAIL %s\n' "$1"
  [[ -n ${2:-} ]] && printf '       %s\n' "$2"
  fail=1
}

id=$(jq -r .id manifest.json)
version=$(jq -r .version manifest.json)

# --- the id must agree everywhere --------------------------------------------
check_grep() { # description, pattern, file, hint
  if grep -q "$2" "$3"; then ok "$1"; else no "$1" "$4"; fi
}

check_grep "BarWidget moduleName matches manifest id" \
  "moduleName: \"$id\"" BarWidget.qml "expected moduleName: \"$id\""
check_grep "IpcHandler target matches manifest id" \
  "target: \"$id\"" BarWidget.qml "expected target: \"$id\""
check_grep "CLI bar target matches manifest id" \
  "BAR_MODULE=\${OMCRON_BAR_MODULE:-$id}" bin/omcron \
  "bin/omcron must default BAR_MODULE to $id"

# --- versions must agree ------------------------------------------------------
cli_version=$(OMCRON_SELF=/dev/null ./bin/omcron version | awk '{print $2}')
if [[ $cli_version == "$version" ]]; then
  ok "CLI version matches manifest ($version)"
else
  no "CLI version matches manifest" "manifest $version, CLI $cli_version"
fi

if [[ -f CHANGELOG.md ]]; then
  top=$(grep -m1 -oE '^## \[?v?[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [[ $top == "$version" ]]; then
    ok "CHANGELOG top entry matches manifest ($version)"
  else
    no "CHANGELOG top entry matches manifest" "manifest $version, changelog ${top:-none}"
  fi
fi

# --- every exposed setting must actually be read ------------------------------
while read -r key; do
  [[ -z $key ]] && continue
  if grep -q "setting(\"$key\"" BarWidget.qml; then
    ok "setting '$key' is read by the widget"
  else
    no "setting '$key' is read by the widget" "declared in schema but never read"
  fi
  if jq -e --arg k "$key" '.barWidget.defaults | has($k)' manifest.json >/dev/null; then
    ok "setting '$key' has a default"
  else
    no "setting '$key' has a default" "missing from barWidget.defaults"
  fi
done < <(jq -r '.barWidget.schema[].key' manifest.json)

# --- no symlinks anywhere: the validator rejects the whole plugin -------------
if [[ -n $(find . -path ./.git -prune -o -type l -print -quit) ]]; then
  no "no symlinks in the repo" "$(find . -path ./.git -prune -o -type l -print | head -3)"
else
  ok "no symlinks in the repo"
fi

exit "$fail"
