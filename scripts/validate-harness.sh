#!/usr/bin/env bash
# Validates repo harness artifacts against the contracts in AGENTS.md:
# agent/command frontmatter shape and key order, skill frontmatter with
# strict SemVer and lifecycle status, domain skill ownership integrity, and
# global name uniqueness across flat OpenCode targets.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAILS=0
AGENTS=0
COMMANDS=0
SKILLS=0
DOMAIN_SKILLS=0
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

allowed_agent_skills() {
  frontmatter "$1" | awk '
    /^  skill:/ { skills = 1; next }
    skills && /^  [^ ]/ { skills = 0 }
    skills && /^    [A-Za-z0-9_-]+: allow$/ {
      skill = $0
      sub(/^    /, "", skill)
      sub(/: allow$/, "", skill)
      print skill
    }
  '
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
  domain="$(basename "$(dirname "$(dirname "$f")")")"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    entry="domains/$domain/skills/$skill"
    { [ -e "$entry" ] || [ -L "$entry" ]; } ||
      fail "$f" "allowlisted skill '$skill' is not declared by domain '$domain'"
  done < <(allowed_agent_skills "$f")
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

# --- External OpenCode plugins ---
if command -v jq >/dev/null 2>&1; then
  for f in domains/*/external-plugins/*.json; do
    [ -e "$f" ] || continue
    EXTERNAL_PLUGINS=$((EXTERNAL_PLUGINS + 1))
    base="$(basename "$f")"
    case "$base" in
      *.npm-tui.json)
        expected_name="${base%.npm-tui.json}"
        expected_kind="tui"
        expected_source="npm"
        TUI_PLUGINS=$((TUI_PLUGINS + 1))
        ;;
      *.server.json)
        expected_name="${base%.server.json}"
        expected_kind="server"
        expected_source="github"
        ;;
      *.tui.json)
        expected_name="${base%.tui.json}"
        expected_kind="tui"
        expected_source="github"
        TUI_PLUGINS=$((TUI_PLUGINS + 1))
        ;;
      *)
        fail "$f" "external plugin filename must end in .server.json, .tui.json, or .npm-tui.json"
        continue
        ;;
    esac
    if [ "$expected_source" = "npm" ]; then
      jq -e --arg name "$expected_name" '
        .schemaVersion == 1 and
        .name == $name and
        .kind == "tui" and
        .source == "npm" and
        (.package | type == "string" and test("^(@[A-Za-z0-9_.-]+/)?[A-Za-z0-9_.-]+$")) and
        (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        (.profileSource | type == "string" and length > 0 and
          (startswith("/") | not) and (split("/") | all(. != ".."))) and
        ([keys[]] - ["kind", "name", "package", "profileSource", "schemaVersion", "source", "version"] | length == 0)
      ' "$f" >/dev/null 2>&1 || fail "$f" "invalid npm TUI plugin descriptor"
    else
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
    fi
    profile_source="$(jq -r '.profileSource // empty' "$f" 2>/dev/null)"
    [ -z "$profile_source" ] || [ -d "$ROOT/$profile_source" ] ||
      fail "$f" "profileSource '$profile_source' does not exist"
  done
fi

# --- Skills ---
check_skill_body() {
  local s="$1" name="$2" f fm meta refs ref found cand
  SKILLS=$((SKILLS + 1))
  f="$s/SKILL.md"
  if [ ! -f "$f" ]; then
    fail "$s" "missing SKILL.md"
    return
  fi
  if ! fm="$(frontmatter "$f")"; then
    fail "$f" "missing or unterminated --- frontmatter"
    return
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
    for cand in skills/*/"$ref" domains/*/skills/*/"$ref"; do
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
}

for s in skills/*; do
  [ -d "$s" ] && [ ! -L "$s" ] || continue
  name="$(basename "$s")"
  check_skill_body "$s" "$name"
  link_count="$(find domains -mindepth 3 -maxdepth 3 -type l -path "*/skills/$name" -print | wc -l | tr -d ' ')"
  [ "$link_count" -ge 2 ] ||
    fail "$s" "top-level skill must be shared by at least two domain symlinks; found $link_count"
done

# --- Domain skill ownership ---
for entry in domains/*/skills/*; do
  { [ -e "$entry" ] || [ -L "$entry" ]; } || continue
  DOMAIN_SKILLS=$((DOMAIN_SKILLS + 1))
  name="$(basename "$entry")"
  if [ -L "$entry" ]; then
    target="$(readlink "$entry")"
    case "$target" in
      /*)
        fail "$entry" "shared-skill symlink must be relative, found absolute target '$target'"
        continue
        ;;
    esac
    expected="$(cd "skills/$name" 2>/dev/null && pwd -P)" || expected=""
    if [ -z "$expected" ]; then
      fail "$entry" "top-level shared skill skills/$name does not exist"
      continue
    fi
    resolved="$(cd "$(dirname "$entry")" 2>/dev/null && cd "$target" 2>/dev/null && pwd -P)" || resolved=""
    [ "$resolved" = "$expected" ] ||
      fail "$entry" "symlink resolves to '${resolved:-broken}', expected skills/$name"
    continue
  fi

  if [ ! -d "$entry" ]; then
    fail "$entry" "domain skill entry must be a directory or shared-skill symlink"
    continue
  fi
  [ ! -e "skills/$name" ] && [ ! -L "skills/$name" ] ||
    fail "$entry" "exclusive domain skill duplicates top-level skills/$name"
  owner_count="$(find domains -mindepth 3 -maxdepth 3 -path "*/skills/$name" -print | wc -l | tr -d ' ')"
  [ "$owner_count" -eq 1 ] ||
    fail "$entry" "direct skill body must have exactly one domain owner; found $owner_count"
  check_skill_body "$entry" "$name"
done

# --- Domain README catalogs ---
domain_component_names() {
  local domain="$1" entry base

  for entry in "$domain"/agents/*.md "$domain"/commands/*.md; do
    [ -e "$entry" ] || continue
    base="$(basename "$entry")"
    printf '%s\n' "${base%.md}"
  done

  for entry in "$domain"/skills/*; do
    { [ -e "$entry" ] || [ -L "$entry" ]; } || continue
    basename "$entry"
  done

  for entry in "$domain"/plugins/* "$domain"/tui-plugins/*; do
    { [ -f "$entry" ] || [ -L "$entry" ]; } || continue
    base="$(basename "$entry")"
    printf '%s\n' "${base%.*}"
  done

  for entry in "$domain"/external-plugins/*.json; do
    [ -e "$entry" ] || continue
    base="$(basename "$entry")"
    base="${base%.server.json}"
    base="${base%.tui.json}"
    base="${base%.npm-tui.json}"
    printf '%s\n' "$base"
  done
}

readme_component_names() {
  awk -F '|' '
    /^## Components$/ { components = 1; next }
    components && /^## / { components = 0 }
    components && /^\|/ {
      name = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "Name" || name ~ /^-+$/) next
      gsub(/`/, "", name)
      sub(/^\//, "", name)
      if (name ~ /^\[/) {
        sub(/^\[/, "", name)
        sub(/\]\(.*/, "", name)
      }
      print name
    }
  ' "$1"
}

for readme in domains/*/README.md; do
  domain_dir="$(dirname "$readme")"
  headings="$(awk '/^## / { print }' "$readme")"
  expected_headings="$(printf '%s\n' '## Quick path' '## Entry points' '## Components')"
  [ "$headings" = "$expected_headings" ] ||
    fail "$readme" "H2 sequence must be Quick path, Entry points, Components"

  if grep -Eiq '^```[[:space:]]*mermaid' "$readme"; then
    fail "$readme" "domain README must not contain Mermaid"
  fi

  while IFS=$'\t' read -r table_line table_width expected_width; do
    [ -n "$table_line" ] || continue
    fail "$readme:$table_line" "table row has $table_width separators; expected $expected_width"
  done < <(awk '
    function separator_count(line, count, cursor, char, previous) {
      count = 0
      for (cursor = 1; cursor <= length(line); cursor++) {
        char = substr(line, cursor, 1)
        previous = cursor > 1 ? substr(line, cursor - 1, 1) : ""
        if (char == "|" && previous != "\\") count++
      }
      return count
    }
    !/^\|/ { expected = 0; next }
    /^\|/ {
      width = separator_count($0)
      if (expected == 0) expected = width
      if (width != expected) print NR "\t" width "\t" expected
    }
  ' "$readme")

  intro_sentences="$(awk '
    NR == 1 { next }
    /^## Quick path$/ { exit }
    NF {
      line = $0
      count += gsub(/[.!?]([[:space:]]|$)/, "&", line)
    }
    END { print count + 0 }
  ' "$readme")"
  [ "$intro_sentences" -le 2 ] ||
    fail "$readme" "introduction must contain at most two sentences"

  quick_steps="$(awk '
    /^## Quick path$/ { quick = 1; next }
    quick && /^## / { quick = 0 }
    quick && /^[0-9]+\. / { count++ }
    END { print count + 0 }
  ' "$readme")"
  if [ "$quick_steps" -lt 2 ] || [ "$quick_steps" -gt 3 ]; then
    fail "$readme" "Quick path must contain two or three numbered steps"
  fi

  while IFS=$'\t' read -r component purpose_words; do
    [ -n "$component" ] || continue
    if [ "$purpose_words" -lt 3 ] || [ "$purpose_words" -gt 8 ]; then
      fail "$readme" "component '$component' purpose must contain 3-8 words; found $purpose_words"
    fi
  done < <(awk -F '|' '
    /^## Components$/ { components = 1; next }
    components && /^## / { components = 0 }
    components && /^\|/ {
      name = $3
      purpose = $4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", purpose)
      if (name == "Name" || name ~ /^-+$/) next
      count = split(purpose, words, /[[:space:]]+/)
      print name "\t" count
    }
  ' "$readme")

  actual_components="$(domain_component_names "$domain_dir" | LC_ALL=C sort)"
  documented_components="$(readme_component_names "$readme" | LC_ALL=C sort)"
  if [ "$actual_components" != "$documented_components" ]; then
    actual_inline="$(printf '%s\n' "$actual_components" | paste -sd ',' -)"
    documented_inline="$(printf '%s\n' "$documented_components" | paste -sd ',' -)"
    fail "$readme" "component names differ: filesystem=[$actual_inline] README=[$documented_inline]"
  fi
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

if [ -f scripts/test-opencode-brew-tools.sh ]; then
  bash scripts/test-opencode-brew-tools.sh >/dev/null ||
    fail scripts/test-opencode-brew-tools.sh "Brew tool installer contracts failed"
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

# --- Direct primary/coordinator contracts ---
if [ -f scripts/test-primary-agent-contracts.sh ]; then
  bash scripts/test-primary-agent-contracts.sh >/dev/null ||
    fail scripts/test-primary-agent-contracts.sh "direct-primary contracts failed"
fi

if [ -f scripts/test-multi-primary-profile.sh ]; then
  bash scripts/test-multi-primary-profile.sh >/dev/null ||
    fail scripts/test-multi-primary-profile.sh "multi-primary profile contracts failed"
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
  printf 'FAIL: %d violation(s) across %d agents, %d commands, %d external plugins, %d TUI plugins, %d skills, %d domain skill entries, %d profiles.\n' \
    "$FAILS" "$AGENTS" "$COMMANDS" "$EXTERNAL_PLUGINS" "$TUI_PLUGINS" "$SKILLS" "$DOMAIN_SKILLS" "$PROFILES"
  exit 1
fi
printf 'PASS: %d agents, %d commands, %d external plugins, %d TUI plugins, %d skills, %d domain skill entries, %d profiles, script syntax and deterministic contracts OK.\n' \
  "$AGENTS" "$COMMANDS" "$EXTERNAL_PLUGINS" "$TUI_PLUGINS" "$SKILLS" "$DOMAIN_SKILLS" "$PROFILES"
