#!/usr/bin/env bash
# Drives the sdd orchestraitor headlessly against the java-orders fixture and
# asserts the scenarios in docs/sdd-test-plan.md.
#
#   OPENCODE_BIN=/opt/homebrew/bin/opencode scripts/test-sdd-flows.sh probe
#   OPENCODE_BIN=... scripts/test-sdd-flows.sh smoke
#   OPENCODE_BIN=... scripts/test-sdd-flows.sh SDD-LIGHT-01
#
# This suite calls a real model and spends real credits, so it is opt-in and is
# NOT wired into scripts/validate-harness.sh. Runs use the caller's real HOME and
# XDG dirs — a hermetic HOME hangs session creation because provider credentials
# never resolve (see scripts/test-graphify-init.sh) — but every artifact is
# written inside a throwaway project directory, never in this repo.
#
# What the probe established about headless behavior: `--agent orchestraitor`
# resolves; a delegation appears as a `tool` part named `task` whose
# .state.input.subagent_type names the subagent; and a question under --auto is
# NOT auto-answered and does not hang — the agent renders it as plain text and
# the turn simply ends. So every scenario prompt must pre-answer the whole
# kickoff round, or the run stops at the gate with partial state on disk.
#
# Env:
#   OPENCODE_BIN        required, path to the opencode binary
#   SDD_FLOW_TIMEOUT    per-run wall clock, seconds (default 1200)
#   SDD_FLOW_KEEP       1 to keep scratch dirs even when a scenario passes
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/scripts/fixtures/sdd-agent-routes/java-orders"
TIMEOUT_SECONDS="${SDD_FLOW_TIMEOUT:-1200}"
POLL_SECONDS=2
KEEP="${SDD_FLOW_KEEP:-0}"
RUN_PID=""
SCRATCHES=()
PASSES=0
FAILURES=0
CURRENT=""

log() { printf '%s\n' "$*"; }

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 2
}

# A scenario failure is recorded and the suite keeps going: each scenario is an
# independent paid run and the rest of the evidence is still worth collecting.
verdict_fail() {
  printf 'FAIL %s — %s\n' "$CURRENT" "$1" >&2
  printf '     scratch kept at %s\n' "${SCRATCH:-<none>}" >&2
  KEEP_CURRENT=1
  FAILURES=$((FAILURES + 1))
  return 1
}

verdict_pass() {
  printf 'PASS %s (%s output tokens)\n' "$CURRENT" "$(output_tokens)"
  PASSES=$((PASSES + 1))
}

terminate_run() {
  local pid="$1" attempt
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  for ((attempt = 0; attempt < 50; attempt++)); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done
  kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
}

cleanup() {
  [ -n "$RUN_PID" ] && terminate_run "$RUN_PID"
  local dir
  for dir in ${SCRATCHES+"${SCRATCHES[@]}"}; do
    [ -n "$dir" ] && [ "$KEEP" != 1 ] && rm -rf "$dir"
  done
}
trap cleanup EXIT INT TERM

# --- Scenario scaffolding ----------------------------------------------------

# Lay down a fresh copy of the fixture project in its own git repo, optionally
# seeded with pre-existing .ai state, and export SCRATCH / PROJECT / EVENTS.
setup_scenario() {
  local seed="${1:-none}"
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/sdd-flow.XXXXXX")"
  SCRATCHES+=("$SCRATCH")
  KEEP_CURRENT=0
  PROJECT="$SCRATCH/project"
  EVENTS="$SCRATCH/events.jsonl"
  STDERR_LOG="$SCRATCH/stderr.log"

  mkdir -p "$PROJECT"
  cp "$FIXTURE/pom.xml" "$FIXTURE/.gitignore" "$PROJECT/"
  cp -R "$FIXTURE/src" "$PROJECT/src"

  if [ "$seed" != none ]; then
    local seed_dir="$FIXTURE/state-seeds/$seed"
    [ -d "$seed_dir" ] || die "unknown seed: $seed"
    # Seeds store their state un-dotted so .gitignore does not swallow them.
    if [ -d "$seed_dir/ai" ]; then
      mkdir -p "$PROJECT/.ai"
      cp -R "$seed_dir/ai/." "$PROJECT/.ai/"
    fi
    if [ -d "$seed_dir/orchestraitor" ]; then
      cp -R "$seed_dir/orchestraitor" "$PROJECT/.orchestraitor"
    fi
    [ -d "$seed_dir/src" ] && cp -R "$seed_dir/src/." "$PROJECT/src/"
  fi

  (
    cd "$PROJECT" || exit 1
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init -q -b main
    GIT_CONFIG_GLOBAL=/dev/null git add -A
    GIT_CONFIG_GLOBAL=/dev/null \
      GIT_AUTHOR_NAME=sdd-flows GIT_AUTHOR_EMAIL=sdd-flows@example.invalid \
      GIT_COMMITTER_NAME=sdd-flows GIT_COMMITTER_EMAIL=sdd-flows@example.invalid \
      git commit -qm 'fixture baseline'
  ) || die "could not initialise the scratch git repo"
}

# Run one orchestraitor turn headlessly, bounded by a wall clock.
run_agent() {
  local prompt="$1"
  local started elapsed
  : > "$EVENTS"
  "$OPENCODE_BIN" run \
    --dir "$PROJECT" \
    --agent orchestraitor \
    --format json \
    --auto \
    --title "$CURRENT" \
    "$prompt" > "$EVENTS" 2> "$STDERR_LOG" &
  RUN_PID=$!
  started="$SECONDS"
  while kill -0 "$RUN_PID" 2>/dev/null; do
    elapsed=$((SECONDS - started))
    if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
      terminate_run "$RUN_PID"
      RUN_PID=""
      printf '     timed out after %ss\n' "$TIMEOUT_SECONDS" >&2
      return 1
    fi
    sleep "$POLL_SECONDS"
  done
  wait "$RUN_PID"
  local status=$?
  RUN_PID=""
  return "$status"
}

# --- Assertions --------------------------------------------------------------

assert_file() {
  [ -f "$1" ] || verdict_fail "expected file $(short "$1")"
}

assert_absent() {
  [ ! -e "$1" ] || verdict_fail "expected $(short "$1") not to exist"
}

assert_first_line_matches() {
  local file="$1" pattern="$2" first
  [ -f "$file" ] || { verdict_fail "expected file $(short "$file")"; return 1; }
  first="$(head -n 1 "$file")"
  # shellcheck disable=SC2254  # the pattern is matched as a glob on purpose
  case "$first" in
    $pattern) return 0 ;;
    *) verdict_fail "$(short "$file") line 1 is '$first', expected to match '$pattern'" ;;
  esac
}

assert_grep() {
  grep -Fq "$2" "$1" || verdict_fail "$(short "$1") is missing '$2'"
}

assert_not_grep() {
  grep -Fq "$2" "$1" && verdict_fail "$(short "$1") still contains '$2'"
  return 0
}

short() { printf '%s' "${1#"$SCRATCH"/}"; }

# `opencode run --format json` emits one JSON object per line, each carrying a
# top-level .type plus the .part it describes: a delegation is a `tool` part
# named `task` whose .state.input.subagent_type is the agent that ran.
SUBAGENT_JQ='select(.part?.tool == "task") | .part.state.input.subagent_type // empty'
TOOL_JQ='select(.part?.type == "tool") | .part.tool'
TEXT_JQ='select(.part?.type == "text") | .part.text'

launched_subagents() {
  jq -r "$SUBAGENT_JQ" "$EVENTS" 2>/dev/null | sort -u
}

# Unlike launched_subagents this keeps duplicates, so rounds can be counted.
launched_subagents_all() {
  jq -r "$SUBAGENT_JQ" "$EVENTS" 2>/dev/null
}

output_tokens() {
  jq -r '[.[] | select(.type == "step_finish") | .part.tokens.output // 0] | add // 0' \
    -s "$EVENTS" 2>/dev/null
}

assert_launched() {
  launched_subagents | grep -qx "$1" ||
    verdict_fail "expected the run to launch $1 (saw: $(launched_subagents | tr '\n' ' '))"
}

assert_not_launched() {
  launched_subagents | grep -qx "$1" &&
    verdict_fail "the run launched $1 and should not have"
  return 0
}

word_count() { wc -w < "$1" | tr -d ' '; }

# A completed run archives the change, so a scenario's folder may be either
# still active or already under changes/archive/<date>-<name>/. With a name,
# look for that change; without one, take whichever single change exists.
find_change_dir() {
  local name="${1:-}" dir
  if [ -n "$name" ]; then
    for dir in "$PROJECT/.ai/orchestrator/changes/$name" \
      "$PROJECT"/.ai/orchestrator/changes/archive/*-"$name"; do
      [ -d "$dir" ] && { printf '%s\n' "$dir"; return 0; }
    done
    return 1
  fi
  dir="$(find "$PROJECT/.ai/orchestrator/changes" -mindepth 1 -maxdepth 1 \
    -type d ! -name archive -print -quit 2>/dev/null)"
  [ -n "$dir" ] || dir="$(find "$PROJECT/.ai/orchestrator/changes/archive" \
    -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)"
  [ -n "$dir" ] && printf '%s\n' "$dir"
}

# --- probe -------------------------------------------------------------------

# The gate for every paid scenario. Answers, cheaply: does --agent orchestraitor
# resolve headlessly, what does a delegation look like in the JSON stream, and
# what does the question tool do under --auto.
probe() {
  CURRENT=probe
  setup_scenario none
  log "probe: scratch $SCRATCH"
  run_agent "Delega en el subagente general esta tarea trivial y de solo lectura: contar cuántos archivos .java hay bajo src/. Cuando tengas el número, reportalo y preguntame en una línea si quiero que agregue un test." ||
    log "probe: the run exited non-zero or timed out — see $STDERR_LOG"

  log ""
  log "--- probe findings ---"
  log "events file:      $EVENTS ($(wc -l < "$EVENTS" | tr -d ' ') lines)"
  log "stderr:           $STDERR_LOG ($(wc -l < "$STDERR_LOG" | tr -d ' ') lines)"
  log ""
  log "distinct event types:"
  jq -r '.type // "<no .type>"' "$EVENTS" 2>/dev/null | sort | uniq -c | sort -rn | head -20
  log ""
  log "tool names seen:"
  jq -r "$TOOL_JQ" "$EVENTS" 2>/dev/null | sort | uniq -c | sort -rn | head -20
  log ""
  log "subagents extracted by SUBAGENT_JQ:"
  launched_subagents | sed 's/^/  /'
  log ""
  log "question tool invoked: $(jq -r "$TOOL_JQ" "$EVENTS" 2>/dev/null | grep -cx question) time(s)"
  log "output tokens:         $(output_tokens)"
  log ""
  log "final assistant text:"
  jq -r "$TEXT_JQ" "$EVENTS" 2>/dev/null | tail -5 | sed 's/^/  /'
  log ""
  log "scratch kept at $SCRATCH"
  KEEP=1
}

# --- Scenarios ---------------------------------------------------------------

scenario_SDD_LIGHT_01() {
  CURRENT=SDD-LIGHT-01
  setup_scenario none
  run_agent "usa SDD en modo automático para agregar a Order un método totalQuantity() que devuelva la suma de las cantidades de sus líneas, con su test. Es un cambio acotado: elegí depth light, TDD tests alongside, judgment none, delivery none." ||
    { verdict_fail "the run exited non-zero or timed out"; return; }

  local change_dir
  change_dir="$(find_change_dir)"
  [ -n "$change_dir" ] || { verdict_fail "no change folder under .ai/orchestrator/changes/"; return; }

  assert_file "$change_dir/change.md" || return
  assert_absent "$change_dir/proposal.md" || return
  assert_absent "$change_dir/tasks.md" || return
  assert_first_line_matches "$change_dir/change.md" '*Depth: light*' || return
  assert_grep "$change_dir/change.md" '## Spec Deltas' || return
  assert_grep "$change_dir/change.md" '## Tasks' || return

  local words
  words="$(word_count "$change_dir/change.md")"
  [ "$words" -lt 800 ] || { verdict_fail "change.md is $words words, the light budget is under 800"; return; }

  local agent
  for agent in sdd-proposal sdd-spec sdd-design sdd-tasks; do
    assert_not_launched "$agent" || return
  done
  verdict_pass
}

scenario_SDD_FULL_02() {
  CURRENT=SDD-FULL-02
  setup_scenario none
  run_agent "vamos con sdd en modo automático, depth full, TDD tests alongside, judgment none, delivery none: quiero cupones de descuento por porcentaje aplicables a una orden, que convivan con el descuento por volumen existente y se reflejen en el total." ||
    { verdict_fail "the run exited non-zero or timed out"; return; }

  local change_dir
  change_dir="$(find_change_dir)"
  [ -n "$change_dir" ] || { verdict_fail "no change folder under .ai/orchestrator/changes/"; return; }

  assert_file "$change_dir/proposal.md" || return
  assert_file "$change_dir/tasks.md" || return
  [ -n "$(find "$change_dir/specs" -name spec.md -print -quit 2>/dev/null)" ] ||
    { verdict_fail "no specs/<capability>/spec.md delta was written"; return; }
  assert_first_line_matches "$change_dir/proposal.md" '*Depth: full*' || return
  assert_grep "$change_dir/tasks.md" 'Shared hotspots:' || return
  assert_grep "$change_dir/tasks.md" 'Files:' || return

  assert_launched sdd-proposal || return
  assert_launched sdd-spec || return
  assert_launched sdd-tasks || return
  verdict_pass
}

scenario_SDD_ADOPT_01() {
  CURRENT=SDD-ADOPT-01
  setup_scenario ready-plan
  run_agent "ejecuta el plan enforce-order-limit en modo automático, TDD tests alongside, judgment none, delivery none." ||
    { verdict_fail "the run exited non-zero or timed out"; return; }

  local adopted
  adopted="$(find_change_dir enforce-order-limit)"
  [ -n "$adopted" ] || { verdict_fail "enforce-order-limit was not adopted into .ai/orchestrator/changes/"; return; }
  assert_file "$adopted/proposal.md" || return
  assert_absent "$PROJECT/.ai/refactor-planner/changes/enforce-order-limit" || return
  assert_first_line_matches "$adopted/proposal.md" 'Status: ready-for-sdd | Source: refactor-planner' || return
  # The kickoff line goes on the first line after the marker block.
  sed -n '2,4p' "$adopted/proposal.md" | grep -q 'Mode:.*Depth: full' ||
    { verdict_fail "no kickoff line with Depth: full right after the marker"; return; }

  local agent
  for agent in sdd-proposal sdd-spec sdd-design sdd-tasks; do
    assert_not_launched "$agent" || return
  done
  assert_launched sdd-implement || return
  verdict_pass
}

scenario_SDD_ARCH_01() {
  CURRENT=SDD-ARCH-01
  setup_scenario canonical-spec
  run_agent "continúa adjust-order-pricing. Todas sus tareas ya están hechas: verificá y archivá el cambio." ||
    { verdict_fail "the run exited non-zero or timed out"; return; }

  local canonical="$PROJECT/.ai/orchestrator/specs/order-pricing/spec.md"
  assert_file "$canonical" || return
  # ADDED appended.
  assert_grep "$canonical" 'Discount share per line' || return
  # MODIFIED replaced with no stale text left behind.
  assert_grep "$canonical" 'reaches one hundred units' || return
  assert_not_grep "$canonical" 'reaches the bulk threshold' || return
  # REMOVED gone.
  assert_not_grep "$canonical" 'Legacy leaflet rounding' || return
  # Folder archived under a dated name.
  [ -n "$(find "$PROJECT/.ai/orchestrator/changes/archive" -maxdepth 1 -name '*-adjust-order-pricing' -print -quit 2>/dev/null)" ] ||
    { verdict_fail "the change was not moved to changes/archive/<date>-adjust-order-pricing/"; return; }
  assert_absent "$PROJECT/.ai/orchestrator/changes/adjust-order-pricing" || return
  verdict_pass

  # SDD-ARCH-02 is the negative half of this same run: the archive procedure
  # documents ADDED/MODIFIED/REMOVED only, so a RENAMED delta has no defined
  # merge. Report what actually happened rather than asserting a contract that
  # does not exist yet.
  CURRENT=SDD-ARCH-02
  local old_present new_present
  grep -Fq 'Requirement: Money scale' "$canonical" && old_present=yes || old_present=no
  grep -Fq 'Monetary rounding' "$canonical" && new_present=yes || new_present=no
  printf 'INFO %s — RENAMED delta outcome: old name present=%s, new name present=%s\n' \
    "$CURRENT" "$old_present" "$new_present"
  if [ "$old_present" = no ] && [ "$new_present" = yes ]; then
    printf '     the rename was applied even though the archive procedure does not define it\n'
  else
    printf '     the rename was NOT applied — the known defect reproduces\n'
  fi
}

scenario_SDD_JDG_04() {
  CURRENT=SDD-JDG-04
  setup_scenario none
  run_agent "usa SDD en modo automático, depth light, TDD tests alongside, judgment light, delivery none: agregá a OrderPricing un método discountShare(Order, BigDecimal) que reemplace a discountPerLine y devuelva el descuento repartido por línea, con su test." ||
    { verdict_fail "the run exited non-zero or timed out"; return; }

  assert_launched jd-solo || return
  assert_not_launched jd-judge-a || return
  assert_not_launched jd-judge-b || return

  local ledger
  ledger="$(find "$PROJECT/.ai/orchestrator/changes" -name judgment.md -print -quit 2>/dev/null)"
  if [ -z "$ledger" ]; then
    printf 'INFO %s — no judgment.md was written; light mode may have found nothing to record\n' "$CURRENT"
  else
    grep -q 'JS-[0-9]' "$ledger" ||
      { verdict_fail "judgment.md carries no JS-nnn finding ids"; return; }
  fi

  local fix_rounds
  fix_rounds="$(launched_subagents_all | grep -cx jd-fix || true)"
  [ "$fix_rounds" -le 1 ] ||
    { verdict_fail "light mode ran $fix_rounds jd-fix rounds, the budget is one"; return; }
  verdict_pass
}

# --- Entry point -------------------------------------------------------------

SMOKE=(SDD-LIGHT-01 SDD-FULL-02 SDD-ADOPT-01 SDD-ARCH-01 SDD-JDG-04)

run_scenario() {
  local id="$1"
  local fn="scenario_${id//-/_}"
  declare -F "$fn" >/dev/null || die "unknown scenario: $id"
  "$fn"
  [ "${KEEP_CURRENT:-0}" = 1 ] && KEEP=1
  return 0
}

main() {
  [ "$#" -ge 1 ] || die "usage: $0 probe|smoke|<scenario-id>"
  [ -n "${OPENCODE_BIN:-}" ] || die "OPENCODE_BIN is required (this suite spends real credits)"
  [ -x "$OPENCODE_BIN" ] || die "OPENCODE_BIN is not executable: $OPENCODE_BIN"
  command -v jq >/dev/null 2>&1 || die "jq is required"
  [ -f "$FIXTURE/pom.xml" ] || die "fixture is missing at $FIXTURE"

  case "$1" in
    probe) probe ;;
    smoke)
      local id
      for id in "${SMOKE[@]}"; do run_scenario "$id"; done
      ;;
    *) run_scenario "$1" ;;
  esac

  if [ "$FAILURES" -gt 0 ]; then
    printf 'FAIL: %d scenario(s) failed, %d passed.\n' "$FAILURES" "$PASSES"
    exit 1
  fi
  [ "$1" = probe ] || printf 'PASS: %d scenario(s) OK.\n' "$PASSES"
}

main "$@"
