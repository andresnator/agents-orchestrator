#!/usr/bin/env bash
# Set or remove default_agent in the global OpenCode config.
# Usage: default-agent.sh <set|remove>
# Env: OPENCODE_DIR, DEFAULT_AGENT, FORCE.
set -euo pipefail

action="${1:?usage: default-agent.sh <set|remove>}"
dir="${OPENCODE_DIR:-$HOME/.config/opencode}"
agent="${DEFAULT_AGENT:-orchestraitor}"
editor="$(dirname "$0")/../scripts/jsonc-array.py"

# Pick opencode.jsonc, else opencode.json, else a new opencode.jsonc.
f="$dir/opencode.jsonc"
[ -e "$f" ] || [ ! -e "$dir/opencode.json" ] || f="$dir/opencode.json"

# Write through cat so symlinks and file modes stay intact.
write_config() {
  local tmp
  tmp="$(mktemp)"
  python3 "$editor" "$@" > "$tmp" || { rm -f "$tmp"; exit 1; }
  [ -e "$f" ] || { touch "$f"; chmod 600 "$f"; }
  cat "$tmp" > "$f"
  rm -f "$tmp"
}

cur="$(python3 "$editor" get "$f" default_agent 2>/dev/null || true)"
case "$action" in
  set)
    mkdir -p "$dir"
    if [ "$cur" = "\"$agent\"" ]; then echo "default_agent already $agent"; exit 0; fi
    # Never touch a default_agent the user picked, unless FORCE=1.
    if [ -n "$cur" ] && [ -z "${FORCE:-}" ]; then
      echo "default_agent is $cur in $f; run with FORCE=1 to replace it" >&2
      exit 1
    fi
    [ -e "$dir/agents/$agent.md" ] || echo "warning: agent $agent is not installed; run make install" >&2
    write_config set "$f" default_agent "\"$agent\""
    echo "default_agent = $agent in $f"
    ;;
  remove)
    if [ "$cur" != "\"$agent\"" ]; then echo "default_agent is not $agent; nothing to remove"; exit 0; fi
    write_config remove-property "$f" default_agent
    echo "default_agent removed from $f"
    ;;
  *) echo "usage: default-agent.sh <set|remove>" >&2; exit 2 ;;
esac
