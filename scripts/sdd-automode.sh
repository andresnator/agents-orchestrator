#!/usr/bin/env bash
# Toggle SDD "auto mode" on OpenCode: write complete agent.<name>.permission
# blocks into the user's opencode.json so SDD runs without tool-permission
# prompts. Frontmatter denies are preserved verbatim, workflow question gates
# are unaffected, and repo files are never modified. See docs/sdd-automode.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDD_AGENTS_DIR="$REPO_ROOT/domains/sdd/agents"

# OpenCode permission keys. This list is the one drift point of the script:
# update it when OpenCode adds keys (https://opencode.ai/docs/permissions/).
PERMISSION_KEYS=(
  read edit write glob grep list bash task external_directory
  todowrite webfetch websearch lsp skill question doom_loop
)

ACTION=""
DRY_RUN=0
PROJECT_TARGET=0
TARGET_ARG=""
INCLUDE_GENERAL=1

CONFIG_FILE=""
CONFIG_EXISTS=0
ALL_ALLOW_JSON=""
SET_JSON=""

OUT_TMP=""
AGENTS_TMP=""

usage() {
  cat <<'EOF'
usage: scripts/sdd-automode.sh on|off|show [options]

Toggle "auto mode" for the sdd domain on OpenCode: writes complete
agent.<name>.permission blocks into the user's opencode.json so SDD runs
without tool-permission prompts. Frontmatter denies are preserved verbatim
and workflow question gates are unaffected. Repo files are never modified.

actions:
  on      write auto-mode permission blocks for all sdd agents (+ general)
  off     remove those permission blocks (general included, always)
  show    report per-agent state: on / custom / off

options:
  --dry-run      print the resulting config to stdout; write nothing
  --project      target ./.opencode instead of ~/.config/opencode
  --target DIR   explicit target directory (overrides --project)
  --no-general   'on' skips the built-in general agent
  -h, --help     show this help

See docs/sdd-automode.md for details.
EOF
}

warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

target_root() {
  if [ -n "$TARGET_ARG" ]; then
    absolute_path "$TARGET_ARG"
  elif [ "$PROJECT_TARGET" -eq 1 ]; then
    printf '%s/.opencode\n' "$PWD"
  else
    printf '%s/.config/opencode\n' "$HOME"
  fi
}

cleanup() { rm -f "$OUT_TMP" "$AGENTS_TMP"; }
make_tmp() { mktemp "${TMPDIR:-/tmp}/agents-orchestrator-automode.XXXXXX"; }

resolve_config() {
  local root="$1"
  if [ -f "$root/opencode.jsonc" ]; then
    CONFIG_FILE="$root/opencode.jsonc"
    CONFIG_EXISTS=1
  elif [ -f "$root/opencode.json" ]; then
    CONFIG_FILE="$root/opencode.json"
    CONFIG_EXISTS=1
  else
    CONFIG_FILE="$root/opencode.json"
    CONFIG_EXISTS=0
  fi
  if [ "$CONFIG_EXISTS" -eq 1 ]; then
    jq empty "$CONFIG_FILE" 2>/dev/null ||
      die "$CONFIG_FILE is not valid JSON (JSONC comments are not supported by this script; remove them or edit manually)"
  fi
}

config_json() {
  if [ "$CONFIG_EXISTS" -eq 1 ]; then cat "$CONFIG_FILE"; else printf '{}'; fi
}

discover_agents() {
  AGENTS_TMP="$(make_tmp)"
  local file
  for file in "$SDD_AGENTS_DIR"/*.md; do
    [ -f "$file" ] || continue
    basename "$file" .md
  done | sort > "$AGENTS_TMP"
  [ -s "$AGENTS_TMP" ] || die "no sdd agents found under $SDD_AGENTS_DIR"
}

# Emit the frontmatter permission block of an agent file as TSV lines:
# "key<TAB>value" for flat keys, "parent<TAB>pattern<TAB>value" for nested
# pattern maps (e.g. orchestraitor's task allowlist). Quotes are stripped.
permission_entries() {
  awk '
    NR == 1 { if ($0 ~ /^---[[:space:]]*$/) infm = 1; next }
    infm != 1 { exit }
    /^---[[:space:]]*$/ { exit }
    inperm != 1 { if ($0 ~ /^permission:[[:space:]]*$/) inperm = 1; next }
    /^[^[:space:]]/ { exit }
    /^  [^ ]/ {
      line = substr($0, 3)
      key = line; sub(/:.*$/, "", key)
      val = line; sub(/^[^:]*:/, "", val)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      gsub(/"/, "", val)
      if (val == "") { parent = key } else { parent = ""; print key "\t" val }
      next
    }
    /^    [^ ]/ {
      if (parent == "") next
      line = substr($0, 5)
      pat = line; sub(/:.*$/, "", pat)
      gsub(/"/, "", pat)
      val = line; sub(/^[^:]*:/, "", val)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      gsub(/"/, "", val)
      print parent "\t" pat "\t" val
      next
    }
  ' "$1"
}

validate_entries() {
  local file="$1" f1 f2 f3 val
  while IFS=$'\t' read -r f1 f2 f3; do
    [ -n "$f1" ] || continue
    val="$f3"
    [ -n "$val" ] || val="$f2"
    case "$val" in
      allow|ask|deny) ;;
      *) die "unrecognized permission value '$val' for '$f1' in $file (expected allow|ask|deny)" ;;
    esac
  done
}

# Full auto-mode permission object for one agent: every key set to allow,
# then every frontmatter entry applied verbatim on top.
automode_block() {
  local file="$1" entries
  entries="$(permission_entries "$file")"
  validate_entries "$file" <<<"$entries"
  printf '%s\n' "$entries" | jq -Rn --argjson base "$ALL_ALLOW_JSON" '
    reduce (inputs | select(length > 0) | split("\t")) as $e ($base;
      if ($e | length) == 2 then .[$e[0]] = $e[1]
      else .[$e[0]] = (((.[$e[0]] // {}) | if type == "object" then . else {} end)
                       + {($e[1]): $e[2]})
      end)'
}

build_set_json() {
  SET_JSON='{}'
  local name block
  while IFS= read -r name; do
    block="$(automode_block "$SDD_AGENTS_DIR/$name.md")"
    SET_JSON="$(jq -n --argjson acc "$SET_JSON" --arg name "$name" --argjson perm "$block" \
      '$acc + {($name): {permission: $perm}}')"
  done < "$AGENTS_TMP"
  if [ "$INCLUDE_GENERAL" -eq 1 ]; then
    SET_JSON="$(jq -n --argjson acc "$SET_JSON" --argjson perm "$ALL_ALLOW_JSON" \
      '$acc + {general: {permission: $perm}}')"
  fi
}

# OFF and SHOW always cover general, regardless of --no-general.
target_names() {
  { cat "$AGENTS_TMP"; printf 'general\n'; } | sort -u
}

write_config() {
  local root="$1" done_msg="$2"
  jq empty "$OUT_TMP" || die "internal error: merged config is not valid JSON"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\ndry-run: would write %s\n' "$CONFIG_FILE" >&2
    if [ "$CONFIG_EXISTS" -eq 1 ]; then
      diff <(jq . "$CONFIG_FILE") <(jq . "$OUT_TMP") >&2 || true
    fi
    cat "$OUT_TMP"
    return 0
  fi
  mkdir -p "$root"
  if [ "$CONFIG_EXISTS" -eq 1 ]; then
    local backup
    backup="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_FILE" "$backup"
    printf 'backup: %s\n' "$backup"
  fi
  cat "$OUT_TMP" > "$CONFIG_FILE"
  printf '%s\n' "$done_msg"
}

run_on() {
  local root
  root="$(target_root)"
  resolve_config "$root"
  discover_agents
  build_set_json
  local differing
  differing="$(config_json | jq -r --argjson set "$SET_JSON" '
    [ (.agent // {}) | to_entries[] | .key as $k
      | select($set | has($k))
      | select(.value.permission != null and .value.permission != $set[$k].permission)
      | $k ] | join(" ")')"
  if [ -n "$differing" ]; then
    warn "overwriting existing permission block(s) for: $differing (previous values stay in the backup)"
  fi
  config_json | jq --argjson set "$SET_JSON" '
    .agent = ((.agent // {})
      | reduce ($set | to_entries[]) as $e (.;
          .[$e.key] = ((.[$e.key] // {}) + {permission: $e.value.permission})))
  ' > "$OUT_TMP"
  if [ "$CONFIG_EXISTS" -eq 1 ] &&
     [ "$(jq -S . "$CONFIG_FILE")" = "$(jq -S . "$OUT_TMP")" ]; then
    printf 'auto mode is already on in %s — nothing to write.\n' "$CONFIG_FILE"
    return 0
  fi
  write_config "$root" \
    "wrote $CONFIG_FILE — sdd auto mode ON. Restart OpenCode sessions to pick up permission changes."
}

run_off() {
  local root
  root="$(target_root)"
  resolve_config "$root"
  if [ "$CONFIG_EXISTS" -eq 0 ]; then
    printf 'no OpenCode config at %s — auto mode is not on.\n' "$root"
    return 0
  fi
  discover_agents
  local names
  names="$(target_names | jq -Rn '[inputs]')"
  config_json | jq --argjson names "$names" '
    .agent = ((.agent // {})
      | reduce $names[] as $n (.;
          if has($n) then
            (.[$n] |= del(.permission))
            | (if (.[$n] | length) == 0 then del(.[$n]) else . end)
          else . end))
    | (if (.agent | length) == 0 then del(.agent) else . end)
  ' > "$OUT_TMP"
  if [ "$(jq -S . "$CONFIG_FILE")" = "$(jq -S . "$OUT_TMP")" ]; then
    printf 'auto mode is not on in %s — nothing to remove.\n' "$CONFIG_FILE"
    return 0
  fi
  write_config "$root" \
    "wrote $CONFIG_FILE — sdd auto mode OFF. Restart OpenCode sessions to pick up permission changes."
}

run_show() {
  local root
  root="$(target_root)"
  resolve_config "$root"
  if [ "$CONFIG_EXISTS" -eq 0 ]; then
    printf 'no OpenCode config at %s — auto mode is off.\n' "$root"
    return 0
  fi
  discover_agents
  local name block state total=0 on_count=0 custom_count=0
  while IFS= read -r name; do
    if [ "$name" = general ]; then
      block="$ALL_ALLOW_JSON"
    else
      block="$(automode_block "$SDD_AGENTS_DIR/$name.md")"
    fi
    state="$(config_json | jq -r --arg n "$name" --argjson b "$block" '
      ((.agent // {})[$n].permission // null) as $p
      | if $p == null then "off" elif $p == $b then "on" else "custom" end')"
    printf '%-16s %s\n' "$name" "$state"
    total=$((total + 1))
    case "$state" in
      on) on_count=$((on_count + 1)) ;;
      custom) custom_count=$((custom_count + 1)) ;;
    esac
  done < <(target_names)
  if [ "$on_count" -eq "$total" ]; then
    printf 'auto mode: on\n'
  elif [ "$on_count" -eq 0 ] && [ "$custom_count" -eq 0 ]; then
    printf 'auto mode: off\n'
  else
    printf 'auto mode: partial\n'
  fi
}

main() {
  if [ "$#" -lt 1 ]; then
    usage >&2
    exit 1
  fi
  case "$1" in
    on|off|show) ACTION="$1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown action: $1 (expected on|off|show)" ;;
  esac
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --project) PROJECT_TARGET=1 ;;
      --target)
        [ "$#" -ge 2 ] || die "--target requires a directory"
        TARGET_ARG="$2"
        shift
        ;;
      --no-general) INCLUDE_GENERAL=0 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done
  command -v jq >/dev/null 2>&1 || die "jq is required"
  trap cleanup EXIT INT TERM
  OUT_TMP="$(make_tmp)"
  ALL_ALLOW_JSON="$(printf '%s\n' "${PERMISSION_KEYS[@]}" |
    jq -Rn '[inputs] | map({key: ., value: "allow"}) | from_entries')"
  case "$ACTION" in
    on) run_on ;;
    off) run_off ;;
    show) run_show ;;
  esac
}

main "$@"
