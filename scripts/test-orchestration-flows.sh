#!/usr/bin/env bash
# Opt-in model-backed checks for adaptive orchestration.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/scripts/fixtures/orchestration-agent-routes/java-orders"
PROFILE="$ROOT/scripts/multi-primary-profile.sh"
TIMEOUT_SECONDS="${ORCHESTRATION_FLOW_TIMEOUT:-1200}"
SCENARIO="${1:-probe}"
RUN_PID=""
SCRATCH=""

die() { printf 'ERROR: %s\n' "$1" >&2; exit 2; }

cleanup() {
  if [ -n "$RUN_PID" ] && kill -0 "$RUN_PID" 2>/dev/null; then kill "$RUN_PID" 2>/dev/null || true; fi
  if [ -n "$SCRATCH" ] && [ "${ORCHESTRATION_FLOW_KEEP:-0}" != 1 ]; then rm -rf "$SCRATCH"; fi
}
trap cleanup EXIT INT TERM

[ -n "${OPENCODE_BIN:-}" ] || die 'OPENCODE_BIN is required'
[ -x "$OPENCODE_BIN" ] || die "OPENCODE_BIN is not executable: $OPENCODE_BIN"

if [ "$SCENARIO" = probe ]; then
  "$OPENCODE_BIN" --version
  (cd "$FIXTURE" && mvn -q -o test)
  printf 'PASS probe\n'
  exit 0
fi

[ "${ORCHESTRATION_FLOW_CONFIRM:-}" = run-paid-flow ] ||
  die 'set ORCHESTRATION_FLOW_CONFIRM=run-paid-flow to authorize model credits'
command -v jq >/dev/null 2>&1 || die 'jq is required'

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/orchestration-flow.XXXXXX")"
PROJECT="$SCRATCH/project"
EVENTS="$SCRATCH/events.jsonl"
STDERR_LOG="$SCRATCH/stderr.log"
mkdir -p "$PROJECT"
cp "$FIXTURE/pom.xml" "$FIXTURE/.gitignore" "$PROJECT/"
cp -R "$FIXTURE/src" "$PROJECT/src"

seed_state() {
  local seed="$1" source
  source="$FIXTURE/state-seeds/$seed/ai"
  [ -d "$source" ] || die "unknown seed: $seed"
  mkdir -p "$PROJECT/.ai"
  cp -R "$source/." "$PROJECT/.ai/"
}

init_project() {
  (
    cd "$PROJECT"
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init -q -b main
    GIT_CONFIG_GLOBAL=/dev/null git add -A
    GIT_CONFIG_GLOBAL=/dev/null \
      GIT_AUTHOR_NAME=orchestration-flow GIT_AUTHOR_EMAIL=flow@example.invalid \
      GIT_COMMITTER_NAME=orchestration-flow GIT_COMMITTER_EMAIL=flow@example.invalid \
      git commit -qm 'fixture baseline'
  )
}

install_current_profile() {
  OPENCODE_BIN="$OPENCODE_BIN" \
    "$PROFILE" install --project-root "$PROJECT" --no-install-brew-tools \
    > "$SCRATCH/profile-install.log" 2>&1 ||
    die "current checkout profile install failed; see $SCRATCH/profile-install.log"
}

run_agent() {
  local agent="$1" prompt="$2" started status
  : > "$EVENTS"
  "$OPENCODE_BIN" run --dir "$PROJECT" --agent "$agent" --format json --auto \
    --title "$SCENARIO" "$prompt" > "$EVENTS" 2> "$STDERR_LOG" &
  RUN_PID=$!
  started=$SECONDS
  while kill -0 "$RUN_PID" 2>/dev/null; do
    if [ $((SECONDS - started)) -ge "$TIMEOUT_SECONDS" ]; then
      kill "$RUN_PID" 2>/dev/null || true
      wait "$RUN_PID" 2>/dev/null || true
      RUN_PID=""
      die "model run timed out after ${TIMEOUT_SECONDS}s"
    fi
    sleep 2
  done
  set +e
  wait "$RUN_PID"
  status=$?
  set -e
  RUN_PID=""
  [ "$status" -eq 0 ] || die "model run failed; see $STDERR_LOG"
  [ -s "$EVENTS" ] || die 'model run returned no final output'
}

launched() {
  jq -r 'select(.part?.tool == "task") | .part.state.input.subagent_type // empty' "$EVENTS" | sort -u
}

assert_no_sdd_workers() {
  local worker
  for worker in sdd-explore sdd-implement sdd-verify sdd-canonical-merge; do
    ! launched | grep -qx "$worker" || die "direct run launched $worker"
  done
}

assert_direct_rename() {
  local source="src/main/java/com/example/orders/OrderPricing.java"
  grep -Fq 'BigDecimal orderSubtotal = order.subtotal();' "$PROJECT/$source" ||
    die 'direct run did not rename the local declaration'
  grep -Fq 'bulkDiscount(orderSubtotal)' "$PROJECT/$source" ||
    die 'direct run did not rename the local use'
  ! grep -Fq 'BigDecimal subtotal = order.subtotal();' "$PROJECT/$source" ||
    die 'direct run retained the old local variable'
  ! git -C "$PROJECT" diff --quiet -- "$source" ||
    die 'direct run produced no source diff'
}

assert_sdd_confirmation_question() {
  jq -e 'select(.part?.tool == "question")' "$EVENTS" >/dev/null ||
    die 'SDD recommendation emitted no question event'
  jq -e 'select(.part?.tool == "question") | .part.state.input | tostring | contains("SDD")' \
    "$EVENTS" >/dev/null || die 'confirmation question did not offer SDD'
}

case "$SCENARIO" in
  smoke|DIRECT-RENAME-01)
    init_project
    install_current_profile
    run_agent orchestraitor 'Rename the local variable subtotal to orderSubtotal inside OrderPricing only. Preserve behavior, run the narrowest relevant test, and do not use SDD.'
    [ ! -e "$PROJECT/.ai/orchestration" ] || die 'direct work created orchestration state'
    assert_no_sdd_workers
    assert_direct_rename
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  SDD-CONFIRM-01)
    seed_state complex-plan
    init_project
    install_current_profile
    run_agent orchestraitor 'ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md'
    [ ! -e "$PROJECT/.ai/orchestration/runs" ] || die 'SDD state exists before confirmation'
    assert_sdd_confirmation_question
    ;;
  SDD-COMPLETE-01)
    seed_state complex-plan
    seed_state canonical-spec
    init_project
    install_current_profile
    PLAN="$PROJECT/.ai/deep-planner/plans/adjust-order-pricing.md"
    BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
    run_agent orchestraitor 'Use SDD explicitly. Ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md with automatic execution, tests alongside, no Judgment, and no commits.'
    AFTER="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
    [ "$BEFORE" = "$AFTER" ] || die 'source plan changed'
    find "$PROJECT/.ai/orchestration/runs/archive" -mindepth 1 -maxdepth 1 -type d -print -quit | grep -q . ||
      die 'completed SDD run was not archived'
    for worker in sdd-implement sdd-verify; do
      launched | grep -qx "$worker" || die "SDD run did not launch $worker"
    done
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  *) die "unknown scenario: $SCENARIO" ;;
esac

printf 'PASS %s\n' "$SCENARIO"
if [ "${ORCHESTRATION_FLOW_KEEP:-0}" = 1 ]; then printf 'scratch: %s\n' "$SCRATCH"; fi
