#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN="$ROOT/domains/sdd/plugins/sdd-swarm.ts"
FIXTURE="$ROOT/scripts/fixtures/sdd-swarm/java-checkout"
CHANGE=parallel-checkout
VERIFIED_GROUPS=$(awk '/^## [0-9]+\./ { count += 1 } END { print count + 0 }' \
  "$FIXTURE/state-seeds/swarm-change/ai/orchestrator/changes/$CHANGE/tasks.md")

[[ "${SDD_SWARM_REAL_BENCHMARK_APPROVED:-0}" == 1 ]] || {
  echo "FAIL: set SDD_SWARM_REAL_BENCHMARK_APPROVED=1 after approving model spend" >&2
  exit 1
}
[[ "${SDD_SWARM_MAX_COST_USD:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
  echo "FAIL: set a positive SDD_SWARM_MAX_COST_USD budget" >&2
  exit 1
}
awk -v budget="$SDD_SWARM_MAX_COST_USD" 'BEGIN { exit !(budget > 0) }' || {
  echo "FAIL: SDD_SWARM_MAX_COST_USD must be greater than zero" >&2
  exit 1
}
[[ -n "${SDD_SWARM_SAME_MODEL:-}" ]] || { echo "FAIL: set SDD_SWARM_SAME_MODEL=provider/model" >&2; exit 1; }
[[ -n "${SDD_SWARM_TIERED_SUPERVISOR_MODEL:-}" ]] || { echo "FAIL: set SDD_SWARM_TIERED_SUPERVISOR_MODEL=provider/model" >&2; exit 1; }
[[ -n "${SDD_SWARM_TIERED_WORKER_MODEL:-}" ]] || { echo "FAIL: set SDD_SWARM_TIERED_WORKER_MODEL=provider/model" >&2; exit 1; }

OPENCODE_BIN=${OPENCODE_BIN:-$(command -v opencode || true)}
[[ -n "$OPENCODE_BIN" ]] || { echo "FAIL: opencode is required" >&2; exit 1; }
for command in git jq mvn node; do
  command -v "$command" >/dev/null 2>&1 || { echo "FAIL: $command is required" >&2; exit 1; }
done

SINGLE_MODEL=${SDD_SWARM_SINGLE_MODEL:-$SDD_SWARM_SAME_MODEL}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUTPUT_DIR=${SDD_SWARM_BENCHMARK_OUTPUT:-$PWD/.ai/sdd-swarm-benchmark/$STAMP}
BENCH_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sdd-swarm-benchmark.XXXXXX")
BENCH_DIR=$(cd "$BENCH_DIR" && pwd -P)
RESULTS="$OUTPUT_DIR/results.jsonl"
REPORT="$OUTPUT_DIR/report.md"
mkdir -p "$OUTPUT_DIR" "$BENCH_DIR/m2" "$BENCH_DIR/tmp" "$BENCH_DIR/worktrees"
: >"$RESULTS"
export TMPDIR="$BENCH_DIR/tmp"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export SDD_SWARM_WORKTREE_ROOT="$BENCH_DIR/worktrees"
export MAVEN_OPTS="-Dstyle.color=never -Dmaven.repo.local=$BENCH_DIR/m2 -Djansi.tmpdir=$BENCH_DIR/tmp -Djava.io.tmpdir=$BENCH_DIR/tmp"
if [[ -d "${HOME}/.m2/repository" ]]; then cp -R "${HOME}/.m2/repository/." "$BENCH_DIR/m2/"; fi

cleanup() {
  rm -rf "$BENCH_DIR"
}
trap cleanup EXIT INT TERM

milliseconds() {
  node -e 'console.log(Date.now())'
}

event_cost() {
  local cost
  if ! cost=$(jq -ers '
    [.[].part.cost? | select(type == "number")] as $costs |
    if ($costs | length) == 0 then error("provider cost unavailable") else ($costs | add) end
  ' "$1"); then
    echo "FAIL: provider cost is unavailable in $1; refusing to continue an unmetered benchmark" >&2
    return 1
  fi
  printf '%s\n' "$cost"
}

event_tokens() {
  jq -s '[.[] | ((.part.tokens.input // 0) + (.part.tokens.output // 0) + (.part.tokens.cache.read // 0) + (.part.tokens.cache.write // 0))] | add // 0' "$1"
}

state_cost() {
  local cost
  if ! cost=$(jq -er '
    [.workers[] | select(.attempts > 0) | .usage.cost_measurable] as $measurements |
    if (($measurements | length) > 0 and ($measurements | all(. == true)))
    then .metrics.cost
    else error("worker provider cost unavailable")
    end
  ' "$1"); then
    echo "FAIL: one or more worker costs are unavailable in $1; refusing to continue an unmetered benchmark" >&2
    return 1
  fi
  printf '%s\n' "$cost"
}

check_budget() {
  local spent
  spent=$(jq -s '[.[].cost] | add // 0' "$RESULTS")
  awk -v spent="$spent" -v budget="$SDD_SWARM_MAX_COST_USD" 'BEGIN { exit !(spent >= budget) }' && {
    echo "FAIL: completed-run cost $spent reached budget $SDD_SWARM_MAX_COST_USD; stopping before the next run" >&2
    exit 1
  }
  return 0
}

setup_repo() {
  local name=$1
  local project="$BENCH_DIR/$name"
  mkdir -p "$project"
  cp -R "$FIXTURE/." "$project/"
  mv "$project/state-seeds/swarm-change/ai" "$project/.ai"
  rm -rf "$project/state-seeds"
  if ! (
    cd "$project"
    git init -q -b main
    git config user.name sdd-swarm-benchmark
    git config user.email sdd-swarm-benchmark@example.invalid
    git add -A
    git commit -qm "fixture baseline"
    mvn -B -q test >/dev/null
  ); then
    echo "FAIL: could not initialize benchmark fixture $name" >&2
    return 1
  fi
  printf '%s\n' "$project"
}

append_result() {
  local arm=$1 repetition=$2 correct=$3 wall=$4 cost=$5 tokens=$6 model=$7 supervisor=${8:-}
  local worker_ms=${9:-0} integration_ms=${10:-0} verified_groups=${11:-0}
  local retries=${12:-0} timeouts=${13:-0} conflicts=${14:-0} out_of_scope=${15:-0}
  jq -nc \
    --arg arm "$arm" --argjson repetition "$repetition" --argjson correct "$correct" \
    --argjson wall_ms "$wall" --argjson cost "$cost" --argjson tokens "$tokens" \
    --argjson worker_ms "$worker_ms" --argjson integration_ms "$integration_ms" \
    --argjson verified_groups "$verified_groups" --argjson retries "$retries" \
    --argjson timeouts "$timeouts" --argjson conflicts "$conflicts" --argjson out_of_scope "$out_of_scope" \
    --arg model "$model" --arg supervisor "$supervisor" \
    '{arm:$arm,repetition:$repetition,correct:$correct,wall_ms:$wall_ms,cost:$cost,tokens:$tokens,model:$model,
      worker_ms:$worker_ms,integration_ms:$integration_ms,verified_groups:$verified_groups,retries:$retries,
      timeouts:$timeouts,conflicts:$conflicts,out_of_scope:$out_of_scope} +
      (if $supervisor == "" then {} else {supervisor_model:$supervisor} end)' \
    >>"$RESULTS"
  check_budget
}

run_single() {
  local repetition=$1 project events started ended status=0 correct=false baseline commits verified=0 cost
  project=$(setup_repo "single-$repetition")
  events="$OUTPUT_DIR/single-$repetition.events.jsonl"
  baseline=$(git -C "$project" rev-parse HEAD)
  started=$(milliseconds)
  "$OPENCODE_BIN" run --dir "$project" --agent sdd-swarm-baseline --model "$SINGLE_MODEL" --format json --auto \
    "Implement change $CHANGE sequentially as the benchmark control arm, run all configured validations, and create the required single commit." \
    >"$events" 2>"$OUTPUT_DIR/single-$repetition.stderr.log" || status=$?
  ended=$(milliseconds)
  commits=$(git -C "$project" rev-list --count "$baseline..HEAD")
  if [[ "$status" -eq 0 && "$commits" -eq 1 && -z "$(git -C "$project" status --porcelain)" ]] &&
    (cd "$project" && bash .sdd-swarm/golden-verify.sh); then correct=true; fi
  [[ "$correct" == true ]] && verified=$VERIFIED_GROUPS
  cost=$(event_cost "$events")
  append_result single "$repetition" "$correct" "$((ended - started))" "$cost" "$(event_tokens "$events")" "$SINGLE_MODEL" "" 0 0 "$verified"
}

run_swarm() {
  local arm=$1 repetition=$2 supervisor_model=$3 worker_model=$4 project supervisor_events state started ended status=0 correct=false
  local cost supervisor_cost workers_cost tokens worker_ms integration_ms verified=0 retries timeouts conflicts out_of_scope
  project=$(setup_repo "$arm-$repetition")
  supervisor_events="$OUTPUT_DIR/$arm-$repetition-supervisor.events.jsonl"
  state="$OUTPUT_DIR/$arm-$repetition-state.json"
  started=$(milliseconds)
  "$OPENCODE_BIN" run --dir "$project" --agent sdd-swarm --model "$supervisor_model" --format json --auto \
    "Benchmark preflight only: plan change $CHANGE and stop without launching workers." \
    >"$supervisor_events" 2>"$OUTPUT_DIR/$arm-$repetition-supervisor.stderr.log" || status=$?
  if [[ "$status" -eq 0 ]]; then
    SDD_SWARM_WORKER_MODEL="$worker_model" OPENCODE_BIN="$OPENCODE_BIN" \
      node "$PLUGIN" run-sync --root "$project" --change "$CHANGE" --execution opencode --max-workers 4 --timeout 1200 >"$state" || status=$?
  fi
  ended=$(milliseconds)
  if [[ "$status" -eq 0 ]] && jq -e '.status == "completed"' "$state" >/dev/null &&
    (cd "$(jq -r .integration_worktree "$state")" && bash .sdd-swarm/golden-verify.sh); then correct=true; fi
  supervisor_cost=$(event_cost "$supervisor_events")
  workers_cost=$(state_cost "$state")
  cost=$(awk -v supervisor="$supervisor_cost" -v workers="$workers_cost" 'BEGIN { print supervisor + workers }')
  tokens=$(awk -v supervisor="$(event_tokens "$supervisor_events")" -v workers="$(jq -r '(.metrics.input_tokens // 0) + (.metrics.output_tokens // 0) + (.metrics.cache_tokens // 0)' "$state" 2>/dev/null || echo 0)" 'BEGIN { print int(supervisor + workers) }')
  worker_ms=$(jq -r '.metrics.worker_wall_time_ms // 0' "$state" 2>/dev/null || echo 0)
  integration_ms=$(jq -r '.metrics.integration_wall_time_ms // 0' "$state" 2>/dev/null || echo 0)
  retries=$(jq -r '[.workers[].attempts - 1 | select(. > 0)] | add // 0' "$state" 2>/dev/null || echo 0)
  timeouts=$(jq -r '[.workers[].status | select(. == "timed_out")] | length' "$state" 2>/dev/null || echo 0)
  conflicts=$(jq -r 'if ((.error // "") | contains("cherry-pick conflict")) then 1 else 0 end' "$state" 2>/dev/null || echo 0)
  out_of_scope=$(jq -r 'if ((.error // "") | contains("outside scope") or contains("out-of-scope")) then 1 else 0 end' "$state" 2>/dev/null || echo 0)
  [[ "$correct" == true ]] && verified=$VERIFIED_GROUPS
  append_result "$arm" "$repetition" "$correct" "$((ended - started))" "$cost" "$tokens" "$worker_model" "$supervisor_model" \
    "$worker_ms" "$integration_ms" "$verified" "$retries" "$timeouts" "$conflicts" "$out_of_scope"
}

for repetition in 1 2 3; do
  case "$repetition" in
    1) order=(single swarm-same swarm-tiered) ;;
    2) order=(swarm-same swarm-tiered single) ;;
    3) order=(swarm-tiered single swarm-same) ;;
  esac
  for arm in "${order[@]}"; do
    case "$arm" in
      single) run_single "$repetition" ;;
      swarm-same) run_swarm "$arm" "$repetition" "$SDD_SWARM_SAME_MODEL" "$SDD_SWARM_SAME_MODEL" ;;
      swarm-tiered) run_swarm "$arm" "$repetition" "$SDD_SWARM_TIERED_SUPERVISOR_MODEL" "$SDD_SWARM_TIERED_WORKER_MODEL" ;;
    esac
  done
done

node "$ROOT/scripts/sdd-swarm-benchmark-report.ts" "$RESULTS" "$REPORT" >/dev/null
echo "PASS: benchmark completed"
echo "Report: $REPORT"
