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
TUI_PLUGINS=0
EXTERNAL_PLUGINS=0

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

# --- OpenCode TUI plugins ---
for f in domains/*/tui-plugins/*.tsx; do
  [ -e "$f" ] || continue
  TUI_PLUGINS=$((TUI_PLUGINS + 1))
  companion="${f%.tsx}"
  [ -d "$companion" ] || fail "$f" "missing same-named companion directory"
done
check_unique tui-plugins domains/*/tui-plugins/*.tsx

# --- Commit-pinned external OpenCode plugins ---
if command -v jq >/dev/null 2>&1; then
  for f in domains/*/external-plugins/*.json; do
    [ -e "$f" ] || continue
    EXTERNAL_PLUGINS=$((EXTERNAL_PLUGINS + 1))
    base="$(basename "$f")"
    case "$base" in
      *.server.json)
        expected_name="${base%.server.json}"
        expected_kind="server"
        ;;
      *.tui.json)
        expected_name="${base%.tui.json}"
        expected_kind="tui"
        TUI_PLUGINS=$((TUI_PLUGINS + 1))
        ;;
      *)
        fail "$f" "external plugin filename must end in .server.json or .tui.json"
        continue
        ;;
    esac
    jq -e --arg name "$expected_name" --arg kind "$expected_kind" '
      .schemaVersion == 1 and
      .name == $name and
      .kind == $kind and
      (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
      (.repository | type == "string" and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) and
      (.commit | type == "string" and test("^[0-9a-f]{40}$")) and
      (.artifact | type == "string" and length > 0 and (startswith("/") | not) and (split("/") | all(. != ".."))) and
      (.sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
      ((.profileSource // null) as $profile |
        $profile == null or
        ($kind == "tui" and ($profile | type == "string" and length > 0 and (startswith("/") | not) and (split("/") | all(. != "..")))))
    ' "$f" >/dev/null 2>&1 || fail "$f" "invalid external plugin descriptor"
    profile_source="$(jq -r '.profileSource // empty' "$f" 2>/dev/null)"
    [ -z "$profile_source" ] || [ -d "$ROOT/$profile_source" ] ||
      fail "$f" "profileSource '$profile_source' does not exist"
  done
fi

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
  # Dead-reference check: relative references/ and assets/ paths cited in a
  # SKILL.md body must resolve to a real file or dir under some skill. Skills
  # legitimately cite each other's references/ and assets/, so a path is valid
  # if it exists under any skill, not only the current one; a path that exists
  # nowhere is the drift this guards against.
  refs="$(grep -oE '(references|assets)/[A-Za-z0-9_./-]+' "$f" | sort -u)"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in
      *'*'* | *'?'*) continue ;; # skip globs/patterns, not concrete paths
    esac
    ref="${ref%[.,:;)]}" # strip one trailing sentence-punctuation char
    found=0
    for cand in skills/*/"$ref"; do
      [ -e "$cand" ] && {
        found=1
        break
      }
    done
    [ "$found" -eq 1 ] ||
      fail "$f" "references missing path '$ref'"
  done <<EOF
$refs
EOF
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
for f in installers/*.sh installers/lib/*.sh scripts/*.sh; do
  [ -e "$f" ] || continue
  bash -n "$f" 2>/dev/null ||
    fail "$f" "bash -n syntax check failed"
done
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x installers/*.sh installers/lib/*.sh scripts/*.sh ||
    fail scripts "shellcheck reported issues"
fi

# --- Deterministic external plugin installer contracts ---
if [ -x scripts/test-external-plugin-install.sh ] && command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  scripts/test-external-plugin-install.sh contracts >/dev/null ||
    fail scripts/test-external-plugin-install.sh "external plugin installer contracts failed"
fi

# --- Deterministic sdd-automode contracts (jq-gated) ---
if [ -x scripts/test-sdd-automode.sh ] && command -v jq >/dev/null 2>&1; then
  scripts/test-sdd-automode.sh >/dev/null ||
    fail scripts/test-sdd-automode.sh "sdd-automode contracts failed"
fi

# --- Plan -> SDD handoff and state-machine contracts ---
if [ -f scripts/test-plan-sdd-contracts.sh ]; then
  bash scripts/test-plan-sdd-contracts.sh >/dev/null ||
    fail scripts/test-plan-sdd-contracts.sh "plan/SDD contracts failed"
fi

# --- Installer idempotency (python3/jq/opencode-gated) ---
# Managed config values (currently the tui.json plugin entry) are edited in place,
# so every remove-then-add round trip must land on the exact same bytes. Repeating a
# plain `install` is not enough to prove that: a still-selected value is never removed, so the
# editor is not exercised. Reaching it takes a cycle that drops the value and re-adds it — an
# `uninstall`, or an `install` under a narrower `--domain` filter — which is why real drift
# accumulated 22 blank entries in a live tui.json while double installs looked clean. The
# check therefore snapshots the fresh install as the baseline and compares two full
# uninstall/install cycles plus one plain repeat against it, so drift introduced by the very
# first cycle is caught too. `*.bak` files are excluded: they are point-in-time backups of the
# pre-edit state, so they legitimately appear only once a cycle has run.
target_snapshot() {
  (
    cd "$1" || exit 1
    find . -mindepth 1 ! -name '*.bak' | LC_ALL=C sort | while IFS= read -r entry; do
      if [ -L "$entry" ]; then
        printf 'link\t%s\t%s\n' "$entry" "$(readlink "$entry")"
      elif [ -d "$entry" ]; then
        printf 'dir\t%s\n' "$entry"
      else
        printf 'file\t%s\t%s\n' "$entry" "$(cksum <"$entry")"
      fi
    done
  )
}

if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
  { [ -n "${OPENCODE_BIN:-}" ] || command -v opencode >/dev/null 2>&1; }; then
  idem_dir="$(mktemp -d "${TMPDIR:-/tmp}/harness-idempotency.XXXXXX")"
  idem_target="$idem_dir/target"
  idem_log="$idem_dir/install.log"
  idem_artifacts="$idem_dir/external-artifacts"
  idem_step=""
  mkdir -p "$idem_artifacts"
  printf '%s\n' 'export default { id: "fixture.model", tui: async () => {} }' > "$idem_artifacts/model-configurator.js"
  printf '%s\n' 'export default { id: "fixture.registry", server: async () => ({}) }' > "$idem_artifacts/skill-registry.js"
  printf '%s\n' 'export default { id: "fixture.graphify", server: async () => ({}) }' > "$idem_artifacts/graphify-init.js"

  run_installer() {
    if ! AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$idem_artifacts" \
      installers/opencode.sh "$1" --target "$idem_target" >"$idem_log" 2>&1; then
      sed -n '1,40p' "$idem_log" >&2
      fail installers/opencode.sh "$1 into a scratch target failed ($2)"
      return 1
    fi
  }

  if run_installer install fresh &&
    { target_snapshot "$idem_target" >"$idem_dir/fresh.txt"; } &&
    run_installer uninstall "cycle 1" && run_installer install "cycle 1" &&
    { target_snapshot "$idem_target" >"$idem_dir/cycle1.txt"; } &&
    run_installer uninstall "cycle 2" && run_installer install "cycle 2" &&
    { target_snapshot "$idem_target" >"$idem_dir/cycle2.txt"; } &&
    run_installer install repeat &&
    { target_snapshot "$idem_target" >"$idem_dir/repeat.txt"; }; then
    for idem_step in cycle1 cycle2 repeat; do
      diff -u "$idem_dir/fresh.txt" "$idem_dir/$idem_step.txt" >"$idem_dir/$idem_step.diff" 2>&1 && continue
      sed -n '1,40p' "$idem_dir/$idem_step.diff" >&2
      fail installers/opencode.sh "install is not idempotent: $idem_step changed the target"
    done
  fi
  rm -rf "$idem_dir"
fi

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d violation(s) across %d agents, %d commands, %d external plugins, %d TUI plugins, %d skills, %d domain skill links, %d profiles.\n' \
    "$FAILS" "$AGENTS" "$COMMANDS" "$EXTERNAL_PLUGINS" "$TUI_PLUGINS" "$SKILLS" "$LINKS" "$PROFILES"
  exit 1
fi
printf 'PASS: %d agents, %d commands, %d external plugins, %d TUI plugins, %d skills, %d domain skill links, %d profiles, script syntax and deterministic contracts OK.\n' \
  "$AGENTS" "$COMMANDS" "$EXTERNAL_PLUGINS" "$TUI_PLUGINS" "$SKILLS" "$LINKS" "$PROFILES"
