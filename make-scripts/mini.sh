#!/usr/bin/env bash
# Configure Mini without a change to server settings or permissions.
set -euo pipefail

action="${1:-}"
case "$action" in
  set|remove) ;;
  *) echo "usage: mini.sh <set|remove>" >&2; exit 2 ;;
esac

dir="${OPENCODE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
file="$dir/cli.json"
editor="$(dirname "$0")/../scripts/jsonc-array.py"
fields=(thinking tools shell_output)

# Reasoning and raw shell output stay hidden; tool calls stay visible.
value_for() {
  case "$1" in
    tools) printf '"show"' ;;
    *) printf '"hide"' ;;
  esac
}

die() { echo "error: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 is required to configure Mini"
if [ "$action" = remove ] && [ ! -e "$file" ]; then
  echo "no Mini settings to remove"
  exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/agents-orchestrator-mini.XXXXXX")"
trap 'rm -rf "$work"' EXIT
if [ -e "$file" ]; then
  cat "$file" > "$work/config"
else
  printf '{\n  "$schema": "https://opencode.ai/v2/cli.json"\n}\n' > "$work/config"
fi

# Stage every edit before a write to the real configuration.
for field in "${fields[@]}"; do
  value="$(value_for "$field")"
  status=0
  current="$(python3 "$editor" get-member "$work/config" mini "$field")" || status=$?
  case "$status" in
    0|1) ;;
    *) die "cannot read $file or its mini object; fix the file and run again" ;;
  esac

  if [ "$action" = set ]; then
    if [ -n "$current" ] && [ "$current" != "$value" ] && [ "${FORCE:-}" != 1 ]; then
      die "mini.$field is already set in $file; run with FORCE=1 to replace it"
    fi
    operation=set-member
  else
    [ "$current" = "$value" ] || continue
    operation=remove-member
  fi

  status=0
  if [ "$operation" = set-member ]; then
    python3 "$editor" "$operation" "$work/config" mini "$field" "$value" > "$work/next" || status=$?
  else
    python3 "$editor" "$operation" "$work/config" mini "$field" > "$work/next" || status=$?
  fi
  case "$status" in
    0|3) mv "$work/next" "$work/config" ;;
    *) die "cannot update mini.$field; no configuration was written" ;;
  esac
done

if [ -e "$file" ] && cmp -s "$file" "$work/config"; then
  echo "Mini settings unchanged in $file"
  exit 0
fi

if [ -e "$file" ]; then
  cp -p "$file" "$file.bak"
else
  mkdir -p "$dir"
  (umask 077; touch "$file")
fi
# Keep existing symlinks and file modes, as the other setup commands do.
cat "$work/config" > "$file"
echo "Mini settings updated in $file"
if [ "$action" = set ]; then
  echo "Start Mini with: opencode mini"
fi
