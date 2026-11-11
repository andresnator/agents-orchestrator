#!/usr/bin/env bash
# Add or remove the Context7 and Engram MCP servers in the global OpenCode config.
# Usage: mcp.sh <install|remove> <context7|engram|all>
# Env: OPENCODE_DIR, FORCE, CONTEXT7_API_KEY.
#
# Entries go to mcp.servers.<name> (OpenCode 2.x) when mcp.servers is an object,
# else to mcp.<name> (1.x shape, which 2.x also reads). We never replace an entry
# that we did not write unless FORCE=1, and we remove only entries that we write.
# Context7: remote https://mcp.context7.com/mcp. With CONTEXT7_API_KEY set, the
# entry sends "Bearer {env:CONTEXT7_API_KEY}"; OpenCode reads the key at start.
# Engram: the official `engram setup opencode` writes plugins/engram.ts, the MCP
# entry (`<engram> mcp --tools=agent`) and the subagent statusline TUI plugin.
set -euo pipefail

usage="usage: mcp.sh <install|remove> <context7|engram|all>"
action="${1:?$usage}"
server="${2:?$usage}"
dir="${OPENCODE_DIR:-$HOME/.config/opencode}"
editor="$(dirname "$0")/../scripts/jsonc-array.py"
context7_url="https://mcp.context7.com/mcp"

# Pick opencode.jsonc, else opencode.json, else a new opencode.jsonc.
f="$dir/opencode.jsonc"
[ -e "$f" ] || [ ! -e "$dir/opencode.json" ] || f="$dir/opencode.json"

die() { echo "error: $*" >&2; exit 1; }

# Write through cat so symlinks and file modes stay intact.
write_config() {
  local tmp rc=0
  tmp="$(mktemp)"
  python3 "$editor" "$@" > "$tmp" || rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 3 ]; then rm -f "$tmp"; exit 1; fi
  [ -e "$f" ] || { mkdir -p "$dir"; touch "$f"; chmod 600 "$f"; }
  cat "$tmp" > "$f"
  rm -f "$tmp"
}

# Print the entry at <path> <name> as canonical JSON; empty when it is missing.
# A file that does not parse stops the script.
entry() {
  local out rc=0
  out="$(python3 "$editor" get-member "$f" "$1" "$2")" || rc=$?
  case "$rc" in
    0) printf '%s' "$out" ;;
    1) ;;
    *) die "cannot read $f; fix the file and run again" ;;
  esac
}

# mcp.servers when it is an object (OpenCode 2.x), else mcp. A server entry that
# is named "servers" (it has type, command, or url) is not the 2.x container.
base_path() {
  local cur
  cur="$(entry mcp servers)"
  if [ -n "$cur" ] && python3 -c '
import json, sys
v = json.loads(sys.argv[1])
sys.exit(0 if isinstance(v, dict) and not {"type", "command", "url"} & set(v) else 1)
' "$cur"; then
    echo mcp.servers
  else
    echo mcp
  fi
}
other_path() { [ "$1" = mcp ] && echo mcp.servers || echo mcp; }

# Exit 0 when the JSON entry ($2) is one that we write for server $1.
ours() {
  python3 - "$1" "$2" "$context7_url" <<'PY'
import json, os, sys
server, raw, url = sys.argv[1:4]
entry = json.loads(raw) if raw else None
if not isinstance(entry, dict) or entry.pop("enabled", True) is not True or "disabled" in entry:
    sys.exit(1)
if server == "context7":
    plain = {"type": "remote", "url": url}
    keyed = dict(plain, headers={"Authorization": "Bearer {env:CONTEXT7_API_KEY}"})
    sys.exit(0 if entry in (plain, keyed) else 1)
command = entry.get("command")
ok = (
    set(entry) == {"type", "command"} and entry["type"] == "local"
    and isinstance(command, list) and len(command) == 3
    and isinstance(command[0], str) and os.path.basename(command[0]) == "engram"
    and command[1:] == ["mcp", "--tools=agent"]
)
sys.exit(0 if ok else 1)
PY
}

# Replace a foreign entry only with FORCE=1.
check_foreign() {
  local name="$1" path="$2" cur
  cur="$(entry "$path" "$name")"
  [ -n "$cur" ] || return 0
  ours "$name" "$cur" && return 0
  [ -n "${FORCE:-}" ] || die "$path.$name in $f is not an entry that we write; run with FORCE=1 to replace it"
  write_config remove-member "$f" "$path" "$name"
  echo "removed $path.$name (FORCE=1)"
}

install_context7() {
  local path want
  path="$(base_path)"
  want="{\"type\":\"remote\",\"url\":\"$context7_url\""
  [ -z "${CONTEXT7_API_KEY:-}" ] || want="$want,\"headers\":{\"Authorization\":\"Bearer {env:CONTEXT7_API_KEY}\"}"
  [ "$path" = mcp.servers ] || want="$want,\"enabled\":true"
  want="$want}"
  check_foreign context7 "$path"
  # Keep one entry: drop ours from the other shape, refuse a foreign one there.
  check_foreign context7 "$(other_path "$path")"
  if [ -n "$(entry "$(other_path "$path")" context7)" ]; then
    write_config remove-member "$f" "$(other_path "$path")" context7
  fi
  write_config set-member "$f" "$path" context7 "$want"
  echo "$path.context7 set in $f"
}

install_engram() {
  local path cur
  command -v engram >/dev/null ||
    die "engram not found on PATH; install it first: https://github.com/Gentleman-Programming/engram/blob/main/docs/INSTALLATION.md"
  case "$dir" in */opencode) ;; *) die "OPENCODE_DIR must end in /opencode for engram setup" ;; esac
  [ -s "$f" ] || { [ -e "$f" ] || { mkdir -p "$dir"; touch "$f"; chmod 600 "$f"; }; echo '{}' > "$f"; }
  path="$(base_path)"
  check_foreign engram mcp
  check_foreign engram mcp.servers
  XDG_CONFIG_HOME="$(dirname "$dir")" engram setup opencode
  # engram setup writes "enabled": true, which the 2.x mcp.servers schema does not have.
  if [ "$path" = mcp.servers ] && [ -n "$(entry mcp.servers.engram enabled)" ]; then
    write_config remove-member "$f" mcp.servers.engram enabled
  fi
  # Keep one entry: drop ours from the other shape.
  cur="$(entry "$(other_path "$path")" engram)"
  if [ -n "$cur" ] && ours engram "$cur"; then
    write_config remove-member "$f" "$(other_path "$path")" engram
  fi
  cur="$(entry "$path" engram)"
  ours engram "$cur" || die "engram setup did not register $path.engram in $f; see its output above"
  echo "$path.engram set in $f"
}

remove_server() {
  local name="$1" path cur found=
  for path in mcp mcp.servers; do
    cur="$(entry "$path" "$name")"
    [ -n "$cur" ] || continue
    if ours "$name" "$cur"; then
      write_config remove-member "$f" "$path" "$name"
      echo "$path.$name removed from $f"
      found=1
    else
      echo "$path.$name is not ours; kept"
    fi
  done
  [ -n "$found" ] || echo "no $name entry of ours in $f"
}

# Delete plugins/engram.ts only when it is the file that engram setup writes now.
remove_engram_plugin() {
  local plugin="$dir/plugins/engram.ts" ref
  [ -f "$plugin" ] || return 0
  if ! command -v engram >/dev/null; then
    echo "warning: engram not found; kept $plugin" >&2
    return 0
  fi
  ref="$(mktemp -d)"
  mkdir -p "$ref/opencode"
  echo '{}' > "$ref/opencode/opencode.json"
  XDG_CONFIG_HOME="$ref" engram setup opencode >/dev/null 2>&1 || true
  if cmp -s "$plugin" "$ref/opencode/plugins/engram.ts"; then
    rm -f "$plugin"
    echo "removed $plugin"
  else
    echo "warning: $plugin differs from what engram setup writes; kept it" >&2
  fi
  rm -rf "$ref"
}

# Stop early on a file that does not parse or a non-object "mcp".
python3 "$editor" get-member "$f" mcp _ >/dev/null 2>&1 || [ $? -eq 1 ] ||
  die "cannot read $f or its \"mcp\" object; fix the file and run again"

case "$server" in
  all) servers="context7 engram" ;;
  context7 | engram) servers="$server" ;;
  *) die "$usage" ;;
esac
for s in $servers; do
  case "$action" in
    install) "install_$s" ;;
    remove)
      remove_server "$s"
      if [ "$s" = engram ]; then
        remove_engram_plugin
        echo "kept opencode-subagent-statusline in tui.json(c); remove it there if you do not want it"
      fi
      ;;
    *) die "$usage" ;;
  esac
done
