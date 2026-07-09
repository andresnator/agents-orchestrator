#!/usr/bin/env bash
# Validates repo harness artifacts against the contracts in AGENTS.md:
# agent/command frontmatter shape and key order, skill frontmatter with
# strict SemVer and lifecycle status, domain skill symlink integrity, and
# global name uniqueness across flat OpenCode targets.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAILS=0
AGENTS=0
COMMANDS=0
SKILLS=0
LINKS=0
PROFILES=0

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2"
  FAILS=$((FAILS + 1))
}

# Print the frontmatter body of a file; non-zero if missing or unterminated.
frontmatter() {
  awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    /^---[[:space:]]*$/ { found = 1; exit }
    { print }
    END { exit found ? 0 : 1 }
  ' "$1"
}

# Extract top-level (column 0) frontmatter keys from stdin, one per line.
root_keys() {
  sed -n 's/^\([A-Za-z_-][A-Za-z_-]*\):.*/\1/p'
}

# Shared frontmatter contract for agents and commands.
check_component() {
  local f="$1" kind="$2" order_re="$3" forbidden="$4"
  local fm keys key
  if ! fm="$(frontmatter "$f")"; then
    fail "$f" "missing or unterminated --- frontmatter"
    return
  fi
  keys="$(printf '%s\n' "$fm" | root_keys | tr '\n' ' ')"
  keys="${keys% }"
  for key in $forbidden; do
    case " $keys " in
      *" $key "*) fail "$f" "forbidden frontmatter key '$key' in $kind file" ;;
    esac
  done
  if ! printf '%s' "$keys" | grep -Eq "$order_re"; then
    fail "$f" "frontmatter keys [$keys] violate the $kind key-order contract"
  fi
}

# --- Agents ---
for f in domains/*/agents/*.md; do
  [ -e "$f" ] || continue
  AGENTS=$((AGENTS + 1))
  check_component "$f" agent \
    '^description mode( temperature)? permission( tools)?( disable)?$' \
    'name prompt license metadata model'
  if frontmatter "$f" >/dev/null 2>&1 &&
    ! frontmatter "$f" | grep -Eq '^mode: (primary|subagent)$'; then
    fail "$f" "mode must be 'primary' or 'subagent'"
  fi
done

# --- Commands ---
for f in domains/*/commands/*.md; do
  [ -e "$f" ] || continue
  COMMANDS=$((COMMANDS + 1))
  check_component "$f" command \
    '^description( agent)?( model)?( subtask)?( argument-hint)?$' \
    'name prompt license metadata'
done

# --- Global name uniqueness (OpenCode targets are flat) ---
check_unique() {
  local kind="$1" dupes name
  shift
  dupes="$(basename -a "$@" 2>/dev/null | sort | uniq -d)"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    fail "domains/*/$kind/$name" "$kind filename is not globally unique"
  done <<EOF
$dupes
EOF
}
check_unique agents domains/*/agents/*.md
check_unique commands domains/*/commands/*.md

# --- Skills ---
for d in skills/*/; do
  s="${d%/}"
  name="${s#skills/}"
  SKILLS=$((SKILLS + 1))
  f="$s/SKILL.md"
  if [ ! -f "$f" ]; then
    fail "$s" "missing SKILL.md"
    continue
  fi
  if ! fm="$(frontmatter "$f")"; then
    fail "$f" "missing or unterminated --- frontmatter"
    continue
  fi
  printf '%s\n' "$fm" | grep -q "^name: $name\$" ||
    fail "$f" "frontmatter name must match directory name '$name'"
  printf '%s\n' "$fm" | grep -q '^description:' ||
    fail "$f" "missing description"
  printf '%s\n' "$fm" | grep -q '^license:' ||
    fail "$f" "missing license"
  meta="$(printf '%s\n' "$fm" | awk '/^metadata:/ { m = 1; next } /^[A-Za-z_-]+:/ { m = 0 } m')"
  printf '%s\n' "$meta" | grep -Eq '^  author: .' ||
    fail "$f" "missing metadata.author"
  printf '%s\n' "$meta" | grep -Eq '^  version: "[0-9]+\.[0-9]+\.[0-9]+"[[:space:]]*$' ||
    fail "$f" "metadata.version must be strict quoted SemVer \"X.Y.Z\""
  printf '%s\n' "$meta" | grep -Eq '^  status: (backlog|in-progress|testing|done)[[:space:]]*$' ||
    fail "$f" "metadata.status must be backlog|in-progress|testing|done"
done

# --- Domain skill symlinks ---
for l in domains/*/skills/*; do
  { [ -e "$l" ] || [ -L "$l" ]; } || continue
  LINKS=$((LINKS + 1))
  name="$(basename "$l")"
  if [ ! -L "$l" ]; then
    fail "$l" "must be a symlink to skills/$name"
    continue
  fi
  target="$(readlink "$l")"
  case "$target" in
    /*)
      fail "$l" "symlink must be relative, found absolute target '$target'"
      continue
      ;;
  esac
  expected="$(cd "skills/$name" 2>/dev/null && pwd -P)" || expected=""
  if [ -z "$expected" ]; then
    fail "$l" "top-level skills/$name does not exist"
    continue
  fi
  resolved="$(cd "$(dirname "$l")" 2>/dev/null && cd "$target" 2>/dev/null && pwd -P)" || resolved=""
  [ "$resolved" = "$expected" ] ||
    fail "$l" "symlink resolves to '${resolved:-broken}', expected skills/$name"
done

# --- Model-tier profiles (jq-gated so the validator runs on jq-less machines) ---
if command -v jq >/dev/null 2>&1; then
  for p in profiles/*.json; do
    [ -e "$p" ] || continue
    PROFILES=$((PROFILES + 1))
    if ! jq empty "$p" 2>/dev/null; then
      fail "$p" "invalid JSON"
      continue
    fi
    jq -e '.tiers | type == "object"' "$p" >/dev/null 2>&1 ||
      fail "$p" "missing .tiers object"
    jq -e '[.tiers[].agents[]] | length == (unique | length)' "$p" >/dev/null 2>&1 ||
      fail "$p" "agent listed in more than one tier"
    for a in $(jq -r '.tiers[].agents[]' "$p" 2>/dev/null); do
      ls domains/*/agents/"$a".md >/dev/null 2>&1 ||
        fail "$p" "unknown agent '$a'"
    done
  done
fi

# --- Script syntax ---
for f in installers/*.sh installers/lib/*.sh scripts/configure-models.sh; do
  [ -e "$f" ] || continue
  bash -n "$f" 2>/dev/null ||
    fail "$f" "bash -n syntax check failed"
done
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x installers/*.sh installers/lib/*.sh ||
    fail installers "shellcheck reported issues"
fi

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d violation(s) across %d agents, %d commands, %d skills, %d domain skill links, %d profiles.\n' \
    "$FAILS" "$AGENTS" "$COMMANDS" "$SKILLS" "$LINKS" "$PROFILES"
  exit 1
fi
printf 'PASS: %d agents, %d commands, %d skills, %d domain skill links, %d profiles, script syntax OK.\n' \
  "$AGENTS" "$COMMANDS" "$SKILLS" "$LINKS" "$PROFILES"
