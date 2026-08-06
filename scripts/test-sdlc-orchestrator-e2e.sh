#!/usr/bin/env bash
# Opt-in paid proof for the project-local SDLC orchestrator POC.
#
# This runner performs exactly two workflows, once each, with no retry loop:
#   1. natural-language Deep Plan, then SDD execution in the same primary session;
#   2. a natural-language bounded implementation routed through SDD Lite.
#
# It uses the caller's real OpenCode credentials and stores sanitized session
# exports plus project evidence below the repository's ignored .ai/ directory.
# It is deliberately not called by scripts/validate-harness.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/scripts/fixtures/sdd-agent-routes/java-orders"
PROFILE="$ROOT/scripts/sdlc-orchestrator-poc.sh"
OPENCODE_BIN="${OPENCODE_BIN:-}"
TIMEOUT_SECONDS="${SDLC_POC_E2E_TIMEOUT:-2400}"
POLL_SECONDS=2
RUN_PID=""
SCRATCH=""
CALLS=0
FAILURES=0

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_ROOT="${SDLC_POC_E2E_EVIDENCE_DIR:-$ROOT/.ai/evidence/sdlc-orchestrator-poc/$timestamp}"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
DATABASE="$DATA_ROOT/opencode.db"

log() { printf '%s\n' "$*"; }

fail() {
  printf 'FAIL %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
  return 1
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 2
}

terminate_run() {
  local pid="$1" attempt
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  kill -TERM "$pid" 2>/dev/null || true
  for ((attempt = 0; attempt < 50; attempt++)); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done
  kill -KILL "$pid" 2>/dev/null || true
}

snapshot_project() {
  local label="$1" project="$2"
  local target="$EVIDENCE_ROOT/$label/project"
  mkdir -p "$target"
  (
    cd "$project" || exit 1
    git status --short --branch > "$target/git-status.txt"
    git diff --stat > "$target/git-diff-stat.txt"
    git diff > "$target/git-diff.patch"
  )
  [ -d "$project/.ai" ] && cp -R "$project/.ai" "$target/ai-state"
  [ -d "$project/src" ] && cp -R "$project/src" "$target/src"
  [ -f "$project/pom.xml" ] && cp "$project/pom.xml" "$target/pom.xml"
  [ -d "$project/target/surefire-reports" ] &&
    cp -R "$project/target/surefire-reports" "$target/surefire-reports"
  [ -f "$project/.opencode/opencode.jsonc" ] &&
    cp "$project/.opencode/opencode.jsonc" "$target/opencode.jsonc"
  [ -f "$project/.opencode/.agents-orchestrator-manifest" ] &&
    cp "$project/.opencode/.agents-orchestrator-manifest" "$target/installer-manifest.tsv"
  [ -f "$project/.opencode/.sdlc-orchestrator-poc-manifest" ] &&
    cp "$project/.opencode/.sdlc-orchestrator-poc-manifest" "$target/profile-manifest.tsv"
}

cleanup() {
  [ -n "$RUN_PID" ] && terminate_run "$RUN_PID"
  if [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ]; then
    [ -d "$SCRATCH/plan-project" ] && snapshot_project plan-sdd "$SCRATCH/plan-project" || true
    [ -d "$SCRATCH/lite-project" ] && snapshot_project sdd-lite "$SCRATCH/lite-project" || true
    rm -rf "$SCRATCH"
  fi
  {
    printf 'finished_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'opencode_calls\t%s\n' "$CALLS"
    printf 'workflow_attempts\t2\n'
    printf 'retries\t0\n'
    printf 'failures\t%s\n' "$FAILURES"
  } >> "$EVIDENCE_ROOT/run-metadata.tsv" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

copy_fixture() {
  local project="$1"
  mkdir -p "$project"
  cp "$FIXTURE/pom.xml" "$FIXTURE/.gitignore" "$project/"
  cp -R "$FIXTURE/src" "$project/src"
  (
    cd "$project" || exit 1
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init -q -b main
    GIT_CONFIG_GLOBAL=/dev/null git add -A
    GIT_CONFIG_GLOBAL=/dev/null \
      GIT_AUTHOR_NAME=sdlc-poc-e2e GIT_AUTHOR_EMAIL=sdlc-poc-e2e@example.invalid \
      GIT_COMMITTER_NAME=sdlc-poc-e2e GIT_COMMITTER_EMAIL=sdlc-poc-e2e@example.invalid \
      git commit -qm 'fixture baseline'
  ) || die "could not initialise fixture project at $project"
}

install_profile() {
  local label="$1" project="$2"
  local evidence="$EVIDENCE_ROOT/$label"
  mkdir -p "$evidence"
  OPENCODE_BIN="$OPENCODE_BIN" "$PROFILE" install --project-root "$project" \
    > "$evidence/profile-install.txt" 2>&1 || die "$label profile install failed"
  OPENCODE_BIN="$OPENCODE_BIN" "$PROFILE" status --project-root "$project" \
    > "$evidence/profile-status.txt" 2>&1 || die "$label profile status failed"
  (
    cd "$project" || exit 1
    OPENCODE_GRAPHIFY_AUTOINIT=0 "$OPENCODE_BIN" --pure debug config
  ) > "$evidence/resolved-config.json" 2> "$evidence/resolved-config.stderr" ||
    die "$label resolved-config check failed"
  jq -e '.default_agent == "sdlc-orchestrator" and .subagent_depth == 2' \
    "$evidence/resolved-config.json" >/dev/null ||
    die "$label did not resolve the POC primary and depth"
}

run_turn() {
  local project="$1" events="$2" stderr_log="$3" title="$4" prompt="$5"
  local session_id="${6:-}" started elapsed status
  [ ! -e "$events" ] || die "refusing to overwrite paid-run evidence: $events"
  CALLS=$((CALLS + 1))
  if [ -n "$session_id" ]; then
    OPENCODE_GRAPHIFY_AUTOINIT=0 "$OPENCODE_BIN" run \
      --dir "$project" --session "$session_id" --format json --auto \
      "$prompt" > "$events" 2> "$stderr_log" &
  else
    OPENCODE_GRAPHIFY_AUTOINIT=0 "$OPENCODE_BIN" run \
      --dir "$project" --format json --auto --title "$title" \
      "$prompt" > "$events" 2> "$stderr_log" &
  fi
  RUN_PID=$!
  started="$SECONDS"
  while kill -0 "$RUN_PID" 2>/dev/null; do
    elapsed=$((SECONDS - started))
    if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
      terminate_run "$RUN_PID"
      RUN_PID=""
      fail "$title timed out after ${TIMEOUT_SECONDS}s"
      return 1
    fi
    sleep "$POLL_SECONDS"
  done
  wait "$RUN_PID"
  status=$?
  RUN_PID=""
  [ "$status" -eq 0 ] || { fail "$title exited with status $status"; return 1; }
  return 0
}

session_id_from_events() {
  jq -rs '[.[] | .sessionID // .part.sessionID // empty] | map(select(length > 0)) | first // empty' "$1"
}

assert_session_id() {
  [[ "$1" =~ ^ses_[A-Za-z0-9]+$ ]] || die "could not extract a safe OpenCode session id"
}

write_session_tree() {
  local root_id="$1" target="$2"
  assert_session_id "$root_id"
  sqlite3 -header -separator $'\t' "$DATABASE" \
    "WITH RECURSIVE tree(id,parent_id,agent,title,time_created,time_updated,tokens_input,tokens_output,tokens_reasoning,tokens_cache_read,cost) AS (
       SELECT id,parent_id,agent,title,time_created,time_updated,tokens_input,tokens_output,tokens_reasoning,tokens_cache_read,cost
       FROM session WHERE id='$root_id'
       UNION ALL
       SELECT s.id,s.parent_id,s.agent,s.title,s.time_created,s.time_updated,s.tokens_input,s.tokens_output,s.tokens_reasoning,s.tokens_cache_read,s.cost
       FROM session s JOIN tree t ON s.parent_id=t.id
     )
     SELECT * FROM tree ORDER BY time_created,id;" > "$target"
}

tree_has_agent() {
  awk -F '\t' -v agent="$2" 'NR > 1 && $3 == agent { found=1 } END { exit found ? 0 : 1 }' "$1"
}

assert_tree_has() {
  tree_has_agent "$1" "$2" || fail "session tree is missing agent $2"
}

assert_tree_lacks() {
  ! tree_has_agent "$1" "$2" || fail "session tree unexpectedly contains agent $2"
}

export_tree() {
  local tree="$1" target="$2" id
  mkdir -p "$target"
  tail -n +2 "$tree" | while IFS=$'\t' read -r id _; do
    [ -n "$id" ] || continue
    "$OPENCODE_BIN" export --sanitize "$id" > "$target/$id.json" 2> "$target/$id.stderr" ||
      fail "could not export session $id"
  done
}

write_usage() {
  local tree="$1" target="$2"
  awk -F '\t' '
    NR > 1 {
      input += $7; output += $8; reasoning += $9; cache += $10; cost += $11
    }
    END {
      printf "sessions\t%d\ninput_tokens\t%d\noutput_tokens\t%d\nreasoning_tokens\t%d\ncache_read_tokens\t%d\ncost\t%.8f\n", NR-1, input, output, reasoning, cache, cost
    }
  ' "$tree" > "$target"
}

assert_maven_green() {
  local project="$1" target="$2"
  (cd "$project" && mvn -q test) > "$target" 2>&1 || fail "Maven verification failed for $project"
}

run_plan_sdd_workflow() {
  local project="$SCRATCH/plan-project" evidence="$EVIDENCE_ROOT/plan-sdd"
  local plan_events="$evidence/01-plan.events.jsonl"
  local execute_events="$evidence/02-execute.events.jsonl"
  local root_id bundle_dir bundle_rel change archived tree_before="$evidence/session-tree-before.tsv"
  local tree_after="$evidence/session-tree-after.tsv" agent

  log "E2E 1/2: natural Deep Plan -> same-session SDD"
  copy_fixture "$project"
  install_profile plan-sdd "$project"
  assert_maven_green "$project" "$evidence/maven-baseline.log" || return 1

  run_turn "$project" "$plan_events" "$evidence/01-plan.stderr" \
    "SDLC POC E2E plan and execute" \
    "Quiero planificar a fondo, sin implementar todavía, un cambio acotado: agrega a Order un método público lineCount() que devuelva exactamente el número de líneas de la orden y una prueba automatizada. Es un único bundle ejecutable, no un roadmap ni una investigación. Conserva las convenciones Java y JUnit existentes; no hay decisiones de producto abiertas, no cambies precios ni cantidades y usa la recomendación segura para cualquier detalle menor." || return 1

  root_id="$(session_id_from_events "$plan_events")"
  assert_session_id "$root_id"
  printf '%s\n' "$root_id" > "$evidence/root-session-id.txt"
  write_session_tree "$root_id" "$tree_before"
  assert_tree_has "$tree_before" sdlc-orchestrator || return 1
  assert_tree_has "$tree_before" deep-planner || return 1
  assert_tree_lacks "$tree_before" orchestraitor || return 1
  for agent in sdd-proposal sdd-spec sdd-design sdd-tasks; do
    assert_tree_lacks "$tree_before" "$agent" || return 1
  done

  bundle_dir="$(find "$project/.ai/deep-planner/changes" -mindepth 1 -maxdepth 1 -type d ! -name archive -print -quit 2>/dev/null)"
  [ -n "$bundle_dir" ] || { fail "Deep Plan produced no active producer bundle"; return 1; }
  bundle_rel="${bundle_dir#"$project/"}"
  change="$(basename "$bundle_dir")"
  printf '%s\n' "$bundle_rel" > "$evidence/bundle-before-path.txt"
  [ -f "$bundle_dir/change.md" ] || { fail "producer bundle is missing change.md"; return 1; }
  for path in proposal.md design.md tasks.md specs; do
    [ ! -e "$bundle_dir/$path" ] || { fail "producer bundle retains retired $path"; return 1; }
  done
  head -n 1 "$bundle_dir/change.md" | grep -Fxq 'Status: ready-for-sdd | Source: deep-planner' ||
    { fail "producer marker is invalid"; return 1; }
  grep -Fq '## Behavior' "$bundle_dir/change.md" || { fail "change.md has no Behavior section"; return 1; }
  grep -Fq '## Work' "$bundle_dir/change.md" || { fail "change.md has no Work section"; return 1; }
  (cd "$project" && find "$bundle_rel" -type f -print0 | sort -z | xargs -0 shasum -a 256) \
    > "$evidence/bundle-before.sha256"
  (
    cd "$project" || exit 1
    git status --porcelain --untracked-files=all |
      awk '$2 !~ /^\.ai\// && $2 !~ /^\.opencode\//'
  ) > "$evidence/non-planning-status-before-execute.txt"
  [ ! -s "$evidence/non-planning-status-before-execute.txt" ] ||
    { fail "Deep Plan changed files outside planning/profile state"; return 1; }

  run_turn "$project" "$execute_events" "$evidence/02-execute.stderr" \
    "SDLC POC E2E plan and execute" \
    "Implementa ahora mediante SDD exactamente el change.md ready-for-sdd que acabas de producir. Reutiliza ese handoff y no vuelvas a redactarlo. Usa Mode automatic, TDD alongside, Judgment none y Delivery none." \
    "$root_id" || return 1

  [ "$(session_id_from_events "$execute_events")" = "$root_id" ] ||
    { fail "the SDD turn did not continue the same primary session"; return 1; }
  write_session_tree "$root_id" "$tree_after"
  export_tree "$tree_after" "$evidence/sessions"
  write_usage "$tree_after" "$evidence/usage.tsv"
  for agent in sdlc-orchestrator deep-planner orchestraitor sdd-implement sdd-verify; do
    assert_tree_has "$tree_after" "$agent" || return 1
  done

  for agent in sdd-proposal sdd-spec sdd-design sdd-tasks; do
    assert_tree_lacks "$tree_after" "$agent" || return 1
  done

  archived="$(find "$project/.ai/deep-planner/changes/archive" -mindepth 1 -maxdepth 1 -type d -name "*-$change" -print -quit 2>/dev/null)"
  [ -n "$archived" ] || { fail "executed bundle was not archived under its producer root"; return 1; }
  [ ! -e "$project/.ai/orchestrator/changes/$change" ] ||
    { fail "producer bundle was copied into the direct-SDD root"; return 1; }
  grep -Rq 'lineCount' "$project/src/main" || { fail "lineCount was not implemented"; return 1; }
  grep -Rq 'lineCount' "$project/src/test" || { fail "lineCount has no test"; return 1; }
  assert_maven_green "$project" "$evidence/maven-test.log" || return 1

  printf '%s\n' "${archived#"$project/"}" > "$evidence/bundle-after-path.txt"
  log "PASS E2E 1/2: session $root_id, bundle ${archived#"$project/"}"
}

run_lite_workflow() {
  local project="$SCRATCH/lite-project" evidence="$EVIDENCE_ROOT/sdd-lite"
  local events="$evidence/01-lite.events.jsonl" root_id tree="$evidence/session-tree.tsv"
  local archived agent

  log "E2E 2/2: natural bounded request -> SDD Lite"
  copy_fixture "$project"
  install_profile sdd-lite "$project"
  assert_maven_green "$project" "$evidence/maven-baseline.log" || return 1

  run_turn "$project" "$events" "$evidence/01-lite.stderr" \
    "SDLC POC E2E bounded implementation" \
    "Implementa este cambio pequeño y de bajo riesgo: agrega a Order un método público totalQuantity() que sume las cantidades de todas sus líneas y una prueba automatizada. El alcance está limitado a Order.java y OrderPricingTest.java, usa TDD alongside, conserva las convenciones existentes y no cambies el comportamiento de precios. Apruebo de antemano el borrador recomendado de change.md; no hay decisiones abiertas." || return 1

  root_id="$(session_id_from_events "$events")"
  assert_session_id "$root_id"
  printf '%s\n' "$root_id" > "$evidence/root-session-id.txt"
  write_session_tree "$root_id" "$tree"
  export_tree "$tree" "$evidence/sessions"
  write_usage "$tree" "$evidence/usage.tsv"
  for agent in sdlc-orchestrator orchestralite lite-verify; do
    assert_tree_has "$tree" "$agent" || return 1
  done
  for agent in deep-planner architect orchestraitor review-coordinator \
    sdd-implement sdd-verify; do
    assert_tree_lacks "$tree" "$agent" || return 1
  done
  grep -Rq 'totalQuantity' "$project/src/main" || { fail "totalQuantity was not implemented"; return 1; }
  grep -Rq 'totalQuantity' "$project/src/test" || { fail "totalQuantity has no test"; return 1; }
  assert_maven_green "$project" "$evidence/maven-test.log" || return 1
  archived="$(find "$project/.ai/sdd-lite/changes/archive" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)"
  [ -n "$archived" ] || { fail "SDD Lite change was not archived"; return 1; }
  [ ! -e "$project/.ai/orchestrator" ] || { fail "SDD Lite touched full-SDD state"; return 1; }
  printf '%s\n' "${archived#"$project/"}" > "$evidence/change-after-path.txt"
  log "PASS E2E 2/2: session $root_id, change ${archived#"$project/"}"
}

[ "${SDLC_POC_E2E_CONFIRM:-}" = "run-exactly-two-paid-workflows" ] ||
  die "set SDLC_POC_E2E_CONFIRM=run-exactly-two-paid-workflows to authorize the paid E2E run"
[ -n "$OPENCODE_BIN" ] || die "OPENCODE_BIN is required"
[ -x "$OPENCODE_BIN" ] || die "OPENCODE_BIN is not executable: $OPENCODE_BIN"
[ -f "$FIXTURE/pom.xml" ] || die "fixture is missing at $FIXTURE"
[ -f "$DATABASE" ] || die "OpenCode database is missing at $DATABASE"
for command in git jq mvn python3 shasum sqlite3; do
  command -v "$command" >/dev/null 2>&1 || die "$command is required"
done
[ ! -e "$EVIDENCE_ROOT" ] || die "evidence destination already exists: $EVIDENCE_ROOT"

mkdir -p "$EVIDENCE_ROOT"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-orchestrator-e2e.XXXXXX")"
{
  printf 'started_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'repository_head\t%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
  printf 'opencode_version\t%s\n' "$($OPENCODE_BIN --version)"
  printf 'evidence_root\t%s\n' "$EVIDENCE_ROOT"
  printf 'paid_workflows\t2\n'
  printf 'retry_policy\tnone\n'
} > "$EVIDENCE_ROOT/run-metadata.tsv"

bash "$ROOT/scripts/test-sdlc-orchestrator-contracts.sh" > "$EVIDENCE_ROOT/contracts.log" 2>&1 ||
  die "deterministic SDLC contracts failed"
bash "$ROOT/scripts/test-sdlc-orchestrator-poc.sh" > "$EVIDENCE_ROOT/profile-contracts.log" 2>&1 ||
  die "deterministic profile contracts failed"

run_plan_sdd_workflow || true
run_lite_workflow || true

if [ "$CALLS" -ne 3 ]; then
  fail "expected three OpenCode turns across two workflows, observed $CALLS"
fi
if [ "$FAILURES" -gt 0 ]; then
  printf 'FAIL: %d finding(s); evidence preserved at %s\n' "$FAILURES" "$EVIDENCE_ROOT" >&2
  exit 1
fi

printf 'PASS: exactly 2 paid SDLC workflows, 3 turns, 0 retries.\n'
printf 'Evidence: %s\n' "$EVIDENCE_ROOT"
