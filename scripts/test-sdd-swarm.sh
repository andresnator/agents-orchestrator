#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN="$ROOT/domains/sdd/plugins/sdd-swarm.ts"
REPORTER="$ROOT/scripts/sdd-swarm-benchmark-report.ts"
FIXTURE="$ROOT/scripts/fixtures/sdd-swarm/java-checkout"
CHANGE=parallel-checkout
PROCESS_TIMEOUT_SECONDS=30

for command in git jq mvn node; do
  command -v "$command" >/dev/null 2>&1 || { echo "FAIL: $command is required" >&2; exit 1; }
done
node -e 'process.exit(process.features && process.features.typescript ? 0 : 1)' >/dev/null 2>&1 || {
  echo "FAIL: sdd-swarm tests need Node with native TypeScript type stripping (>= 22.18)" >&2
  exit 1
}

SUITE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sdd-swarm-test.XXXXXX")
SUITE_DIR=$(cd "$SUITE_DIR" && pwd -P)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export SDD_SWARM_WORKTREE_ROOT="$SUITE_DIR/worktrees"
export MAVEN_OPTS="-Dstyle.color=never -Dmaven.repo.local=$SUITE_DIR/m2 -Djansi.tmpdir=$SUITE_DIR/java-tmp -Djava.io.tmpdir=$SUITE_DIR/java-tmp"
mkdir -p "$SUITE_DIR/java-tmp" "$SUITE_DIR/m2" "$SDD_SWARM_WORKTREE_ROOT"
export TMPDIR="$SUITE_DIR/tmp"
mkdir -p "$TMPDIR"
if [[ -d "${HOME}/.m2/repository" ]]; then
  cp -R "${HOME}/.m2/repository/." "$SUITE_DIR/m2/"
fi

cleanup() {
  rm -rf "$SUITE_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

setup_repo() {
  local name=$1
  local project="$SUITE_DIR/$name"
  mkdir -p "$project"
  cp -R "$FIXTURE/." "$project/"
  mv "$project/state-seeds/swarm-change/ai" "$project/.ai"
  rm -rf "$project/state-seeds"
  if ! (
    cd "$project"
    git init -q -b main
    git config user.name sdd-swarm-tests
    git config user.email sdd-swarm-tests@example.invalid
    git add -A
    git commit -qm "fixture baseline"
    MAVEN_OPTS="$MAVEN_OPTS -Djansi.tmpdir=$SUITE_DIR/java-tmp -Djava.io.tmpdir=$SUITE_DIR/java-tmp" mvn -B -q test >/dev/null
  ); then
    fail "could not initialize Maven fixture $name"
  fi
  printf '%s\n' "$project"
}

setup_deep_plan_repo() {
  local name=$1 with_roadmap=${2:-0}
  local project proposal roadmap
  project=$(setup_repo "$name")
  mkdir -p "$project/.ai/deep-planner/changes"
  mv "$project/.ai/orchestrator/changes/$CHANGE" "$project/.ai/deep-planner/changes/$CHANGE"
  proposal="$project/.ai/deep-planner/changes/$CHANGE/proposal.md"
  node - "$proposal" "$with_roadmap" <<'NODE'
const fs = require("node:fs")
const [file, withRoadmap] = process.argv.slice(2)
const lines = fs.readFileSync(file, "utf8").split("\n")
lines[0] = "Status: ready-for-sdd | Source: deep-planner"
if (withRoadmap === "1") lines.splice(1, 0, "Roadmap: parallel-delivery | Slice: 1/2")
fs.writeFileSync(file, lines.join("\n"))
NODE
  if [[ "$with_roadmap" == 1 ]]; then
    roadmap="$project/.ai/roadmaps/parallel-delivery.md"
    mkdir -p "$(dirname "$roadmap")"
    node - "$roadmap" <<'NODE'
const fs = require("node:fs")
fs.writeFileSync(process.argv[2], `# Roadmap: parallel-delivery
Status: active | Source: deep-planner
Outcome: Deliver the fixture in controlled slices.

| # | Slice | Scope | Depends on | Status | Bundle |
|---|---|---|---|---|---|
| 1 | parallel-checkout | Implement checkout policies | — | planned | .ai/deep-planner/changes/parallel-checkout/ |
| 2 | verify-checkout | Verify the integrated result | 1 | pending | — |
`)
NODE
  fi
  printf '%s\n' "$project"
}

run_sync() {
  local project=$1
  local output=$2
  local timeout=${3:-$PROCESS_TIMEOUT_SECONDS}
  node "$PLUGIN" run-sync --root "$project" --change "$CHANGE" --execution mock --max-workers 4 --timeout "$timeout" >"$output"
}

run_background() {
  local project=$1
  local output=$2
  local timeout=${3:-$PROCESS_TIMEOUT_SECONDS}
  local start="$output.start"
  local run_id state status attempt
  node "$PLUGIN" run --root "$project" --change "$CHANGE" --execution mock --max-workers 4 --timeout "$timeout" >"$start"
  run_id=$(jq -r .run_id "$start")
  state="$project/.ai/sdd-swarm/$run_id/run.json"
  for ((attempt = 0; attempt < 600; attempt++)); do
    status=$(jq -r .status "$state" 2>/dev/null || true)
    case "$status" in
      completed|blocked|failed|aborted|interrupted)
        cp "$state" "$output"
        return
        ;;
    esac
    sleep 0.1
  done
  fail "background controller did not reach a terminal state"
}

cleanup_run() {
  local project=$1
  local result=$2
  local run_id
  run_id=$(jq -r .run_id "$result")
  node "$PLUGIN" cleanup --root "$project" --run-id "$run_id" >/dev/null
}

assert_completed_run() {
  local result=$1
  jq -e '
    .status == "completed" and
    .max_parallel == 4 and
    .current_wave == 3 and
    ([.workers[].status] | all(. == "passed")) and
    (.metrics.wall_time_ms > 0) and
    (.metrics.worker_wall_time_ms > 0) and
    (.metrics.integration_wall_time_ms > 0)
  ' "$result" >/dev/null || fail "completed run contract failed: $result"
}

node "$ROOT/scripts/sdd-swarm-contracts.ts"

REPORT_RESULTS="$SUITE_DIR/report-results.jsonl"
REPORT_OUTPUT="$SUITE_DIR/report.md"
for repetition in 1 2 3; do
  {
    jq -nc --argjson repetition "$repetition" \
      '{arm:"single",repetition:$repetition,correct:true,wall_ms:1000,cost:1,tokens:100,model:"provider/same",worker_ms:0,integration_ms:0,verified_groups:6,retries:0,timeouts:0,conflicts:0,out_of_scope:0}'
    jq -nc --argjson repetition "$repetition" \
      '{arm:"swarm-same",repetition:$repetition,correct:true,wall_ms:500,cost:1,tokens:60,model:"provider/same",supervisor_model:"provider/same",worker_ms:300,integration_ms:100,verified_groups:6,retries:0,timeouts:0,conflicts:0,out_of_scope:0}'
    jq -nc --argjson repetition "$repetition" \
      '{arm:"swarm-tiered",repetition:$repetition,correct:true,wall_ms:800,cost:0,tokens:80,model:"provider/worker",supervisor_model:"provider/frontier",worker_ms:500,integration_ms:200,verified_groups:6,retries:0,timeouts:0,conflicts:0,out_of_scope:0}'
  } >>"$REPORT_RESULTS"
done
node "$REPORTER" "$REPORT_RESULTS" "$REPORT_OUTPUT" >/dev/null
grep -Fq '| swarm-same | 3/3 |' "$REPORT_OUTPUT" || fail "benchmark report omitted same-model arm"
grep -Fq '1.41x | PROMOTE TO A CONTROLLED PILOT' "$REPORT_OUTPUT" || fail "benchmark USD efficiency contract failed"
grep -Fq '1.25x | PROMOTE TO A CONTROLLED PILOT' "$REPORT_OUTPUT" || fail "benchmark token-fallback efficiency contract failed"

SUCCESS_PROJECT=$(setup_repo success)
PLAN_JSON="$SUITE_DIR/plan.json"
node "$PLUGIN" plan --root "$SUCCESS_PROJECT" --change "$CHANGE" --max-workers 4 >"$PLAN_JSON"
jq -e '.waves == [["1","2","3","4"],["5"],["6"]]' "$PLAN_JSON" >/dev/null || fail "unexpected fixture waves"

DEEP_PLAN_PROJECT=$(setup_deep_plan_repo deep-plan-plan 1)
DEEP_PLAN_JSON="$SUITE_DIR/deep-plan.json"
node "$PLUGIN" plan --root "$DEEP_PLAN_PROJECT" --change "$CHANGE" --max-workers 4 >"$DEEP_PLAN_JSON"
jq -e '.waves == [["1","2","3","4"],["5"],["6"]]' "$DEEP_PLAN_JSON" >/dev/null ||
  fail "deep-plan bundle did not produce the expected waves"
[[ ! -e "$DEEP_PLAN_PROJECT/.ai/deep-planner/changes/$CHANGE" ]] || fail "deep-plan source bundle was not adopted"
[[ -f "$DEEP_PLAN_PROJECT/.ai/orchestrator/changes/$CHANGE/design.md" ]] || fail "adopted deep-plan bundle is incomplete"
grep -Fq "| 1 | parallel-checkout | Implement checkout policies | — | adopted | .ai/orchestrator/changes/parallel-checkout/ |" \
  "$DEEP_PLAN_PROJECT/.ai/roadmaps/parallel-delivery.md" || fail "roadmap slice was not updated during adoption"

AMBIGUOUS_PROJECT=$(setup_deep_plan_repo ambiguous-bundles)
mkdir -p "$AMBIGUOUS_PROJECT/.ai/refactor-planner/changes"
cp -R "$AMBIGUOUS_PROJECT/.ai/deep-planner/changes/$CHANGE" "$AMBIGUOUS_PROJECT/.ai/refactor-planner/changes/$CHANGE"
node - "$AMBIGUOUS_PROJECT/.ai/refactor-planner/changes/$CHANGE/proposal.md" <<'NODE'
const fs = require("node:fs")
const file = process.argv[2]
const lines = fs.readFileSync(file, "utf8").split("\n")
lines[0] = "Status: ready-for-sdd | Source: refactor-planner"
fs.writeFileSync(file, lines.join("\n"))
NODE
if node "$PLUGIN" plan --root "$AMBIGUOUS_PROJECT" --change "$CHANGE" >"$SUITE_DIR/ambiguous.log" 2>&1; then
  fail "planning adopted one of multiple ready-for-sdd bundles"
fi
grep -Fq "ambiguous ready-for-sdd bundles" "$SUITE_DIR/ambiguous.log" || fail "ambiguous bundle error was not specific"

DEEP_RUN_PROJECT=$(setup_deep_plan_repo deep-plan-run)
DEEP_RUN_RESULT="$SUITE_DIR/deep-plan-run.json"
run_sync "$DEEP_RUN_PROJECT" "$DEEP_RUN_RESULT"
assert_completed_run "$DEEP_RUN_RESULT"
[[ ! -e "$DEEP_RUN_PROJECT/.ai/deep-planner/changes/$CHANGE" ]] || fail "run did not adopt the deep-plan source bundle"
cleanup_run "$DEEP_RUN_PROJECT" "$DEEP_RUN_RESULT"

INCOMPLETE_PROJECT=$(setup_repo incomplete-bundle)
rm "$INCOMPLETE_PROJECT/.ai/orchestrator/changes/$CHANGE/design.md"
if node "$PLUGIN" plan --root "$INCOMPLETE_PROJECT" --change "$CHANGE" >"$SUITE_DIR/incomplete.log" 2>&1; then
  fail "planning accepted an incomplete full-depth bundle"
fi
grep -Fq "full-depth bundle is missing design.md" "$SUITE_DIR/incomplete.log" || fail "incomplete bundle error was not specific"

NO_IGNORE_PROJECT=$(setup_repo no-ai-ignore)
awk '$0 != ".ai/"' "$NO_IGNORE_PROJECT/.gitignore" >"$NO_IGNORE_PROJECT/.gitignore.next"
mv "$NO_IGNORE_PROJECT/.gitignore.next" "$NO_IGNORE_PROJECT/.gitignore"
git -C "$NO_IGNORE_PROJECT" add .gitignore
git -C "$NO_IGNORE_PROJECT" commit -qm "test: remove ai ignore prerequisite"
if node "$PLUGIN" plan --root "$NO_IGNORE_PROJECT" --change "$CHANGE" >"$SUITE_DIR/no-ignore.log" 2>&1; then
  fail "planning accepted a repository that does not ignore .ai/"
fi
grep -Fq "add '.ai/' to .gitignore or .git/info/exclude" "$SUITE_DIR/no-ignore.log" || fail ".ai ignore remediation was not specific"

SUCCESS_RESULT="$SUITE_DIR/success.json"
run_background "$SUCCESS_PROJECT" "$SUCCESS_RESULT"
assert_completed_run "$SUCCESS_RESULT"
SUCCESS_EVENTS="$SUCCESS_PROJECT/.ai/sdd-swarm/$(jq -r .run_id "$SUCCESS_RESULT")/events.jsonl"
jq -e -s 'length > 1 and (.[-1].status == "completed")' "$SUCCESS_EVENTS" >/dev/null ||
  fail "durable event ledger contract failed"
INTEGRATION=$(jq -r .integration_worktree "$SUCCESS_RESULT")
(cd "$INTEGRATION" && bash .sdd-swarm/golden-verify.sh) || fail "golden verification failed"

DIRTY_WORKTREE=$(jq -r '.workers["1"].worktree' "$SUCCESS_RESULT")
touch "$DIRTY_WORKTREE/DIRTY.txt"
RUN_ID=$(jq -r .run_id "$SUCCESS_RESULT")
if node "$PLUGIN" cleanup --root "$SUCCESS_PROJECT" --run-id "$RUN_ID" >"$SUITE_DIR/dirty-cleanup.log" 2>&1; then
  fail "cleanup removed a dirty worktree"
fi
grep -Fq "refusing to remove dirty worktree" "$SUITE_DIR/dirty-cleanup.log" || fail "dirty cleanup reason missing"
rm "$DIRTY_WORKTREE/DIRTY.txt"
cleanup_run "$SUCCESS_PROJECT" "$SUCCESS_RESULT"
jq -e '.cleaned == true' "$SUCCESS_PROJECT/.ai/sdd-swarm/$RUN_ID/run.json" >/dev/null || fail "cleanup state not recorded"

OUTSIDE_PROJECT=$(setup_repo outside)
OUTSIDE_RESULT="$SUITE_DIR/outside.json"
SDD_SWARM_MOCK_SCENARIO=out-of-scope run_sync "$OUTSIDE_PROJECT" "$OUTSIDE_RESULT"
jq -e '.status == "blocked" and (.error | contains("out-of-scope"))' "$OUTSIDE_RESULT" >/dev/null ||
  fail "out-of-scope changes did not block integration"
cleanup_run "$OUTSIDE_PROJECT" "$OUTSIDE_RESULT"

RETRY_PROJECT=$(setup_repo retry)
RETRY_RESULT="$SUITE_DIR/retry.json"
SDD_SWARM_MOCK_SCENARIO=retry-once run_sync "$RETRY_PROJECT" "$RETRY_RESULT"
assert_completed_run "$RETRY_RESULT"
jq -e '.workers["1"].attempts == 2' "$RETRY_RESULT" >/dev/null || fail "technical retry contract failed"
cleanup_run "$RETRY_PROJECT" "$RETRY_RESULT"

TIMEOUT_PROJECT=$(setup_repo timeout)
TIMEOUT_RESULT="$SUITE_DIR/timeout.json"
SDD_SWARM_MOCK_SCENARIO=timeout run_sync "$TIMEOUT_PROJECT" "$TIMEOUT_RESULT" 1
jq -e '.status == "blocked" and .workers["1"].status == "timed_out" and .workers["1"].attempts == 2' "$TIMEOUT_RESULT" >/dev/null ||
  fail "timeout contract failed"
cleanup_run "$TIMEOUT_PROJECT" "$TIMEOUT_RESULT"

RECEIPT_PROJECT=$(setup_repo receipt)
RECEIPT_RESULT="$SUITE_DIR/receipt.json"
SDD_SWARM_MOCK_SCENARIO=missing-receipt run_sync "$RECEIPT_PROJECT" "$RECEIPT_RESULT"
jq -e '.status == "blocked" and (.error | contains("receipt"))' "$RECEIPT_RESULT" >/dev/null ||
  fail "missing receipt did not block integration"
cleanup_run "$RECEIPT_PROJECT" "$RECEIPT_RESULT"

RECOVERY_PROJECT=$(setup_repo recovery)
RECOVERY_START="$SUITE_DIR/recovery-start.json"
SDD_SWARM_MOCK_SCENARIO=timeout node "$PLUGIN" run --root "$RECOVERY_PROJECT" --change "$CHANGE" --execution mock --max-workers 4 --timeout 30 >"$RECOVERY_START"
RECOVERY_RUN_ID=$(jq -r .run_id "$RECOVERY_START")
RECOVERY_STATE="$RECOVERY_PROJECT/.ai/sdd-swarm/$RECOVERY_RUN_ID/run.json"
for ((attempt = 0; attempt < 100; attempt++)); do
  jq -e '[.workers[].status] | any(. == "running")' "$RECOVERY_STATE" >/dev/null 2>&1 && break
  sleep 0.1
done
CONTROLLER_PID=$(jq -r .controller_pid "$RECOVERY_STATE")
WORKER_PIDS=$(jq -r '.workers[].pid // empty' "$RECOVERY_STATE")
kill "$CONTROLLER_PID"
for ((attempt = 0; attempt < 100; attempt++)); do
  kill -0 "$CONTROLLER_PID" >/dev/null 2>&1 || break
  sleep 0.1
done
node "$PLUGIN" status --root "$RECOVERY_PROJECT" --run-id "$RECOVERY_RUN_ID" >"$SUITE_DIR/recovery.json"
jq -e '
  .status == "interrupted" and
  ([.workers[] | has("pid")] | all(. == false)) and
  ([.workers[].status] | all(. != "running"))
' "$SUITE_DIR/recovery.json" >/dev/null || fail "interrupted-controller recovery contract failed"
sleep 0.3
for worker_pid in $WORKER_PIDS; do
  kill -0 "$worker_pid" >/dev/null 2>&1 && fail "recovery left worker process $worker_pid running"
done
cleanup_run "$RECOVERY_PROJECT" "$SUITE_DIR/recovery.json"

ABORT_PROJECT=$(setup_repo abort)
ABORT_START="$SUITE_DIR/abort-start.json"
SDD_SWARM_MOCK_SCENARIO=timeout node "$PLUGIN" run --root "$ABORT_PROJECT" --change "$CHANGE" --execution mock --max-workers 4 --timeout 30 >"$ABORT_START"
ABORT_RUN_ID=$(jq -r .run_id "$ABORT_START")
ABORT_STATE="$ABORT_PROJECT/.ai/sdd-swarm/$ABORT_RUN_ID/run.json"
for ((attempt = 0; attempt < 100; attempt++)); do
  jq -e '[.workers[].status] | any(. == "running")' "$ABORT_STATE" >/dev/null 2>&1 && break
  sleep 0.1
done
node "$PLUGIN" abort --root "$ABORT_PROJECT" --run-id "$ABORT_RUN_ID" >"$SUITE_DIR/abort.json"
jq -e '.status == "aborted" and .error == "aborted by user"' "$SUITE_DIR/abort.json" >/dev/null || fail "abort contract failed"
sleep 0.2
cleanup_run "$ABORT_PROJECT" "$SUITE_DIR/abort.json"

echo "PASS: sdd-swarm scheduling, ledger recovery, worktrees, fresh retries, receipts, validation, integration metrics, abort, benchmark report, and safe cleanup"
