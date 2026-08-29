#!/usr/bin/env bash
# Opt-in paid flow: Deep Plan creates one plan, then Orchestraitor executes it directly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/scripts/fixtures/orchestration-agent-routes/java-orders"
PROFILE="$ROOT/scripts/multi-primary-profile.sh"
TIMEOUT_SECONDS="${MULTI_PRIMARY_E2E_TIMEOUT:-2400}"
TERMINATION_GRACE_SECONDS=5
POLL_INTERVAL_SECONDS=2
RUN_PID=""
SCRATCH=""

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

terminate_active_run() {
  local terminated_at
  [ -n "$RUN_PID" ] || return 0
  if kill -0 "$RUN_PID" 2>/dev/null; then
    kill -TERM "$RUN_PID" 2>/dev/null || true
    terminated_at=$SECONDS
    while kill -0 "$RUN_PID" 2>/dev/null &&
      ((SECONDS - terminated_at < TERMINATION_GRACE_SECONDS)); do
      sleep "$POLL_INTERVAL_SECONDS"
    done
    if kill -0 "$RUN_PID" 2>/dev/null; then
      kill -KILL "$RUN_PID" 2>/dev/null || true
    fi
  fi
  wait "$RUN_PID" 2>/dev/null || true
  RUN_PID=""
}

cleanup() {
  terminate_active_run
  if [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ]; then rm -rf "$SCRATCH"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_model_call() {
  local agent="$1" events="$2" prompt="$3" started status
  : > "$events"
  "$OPENCODE_BIN" run --dir "$PROJECT" --agent "$agent" --format json --auto "$prompt" > "$events" &
  RUN_PID=$!
  started=$SECONDS

  while kill -0 "$RUN_PID" 2>/dev/null; do
    if ((SECONDS - started >= TIMEOUT_SECONDS)); then
      terminate_active_run
      fail "$agent model call timed out after ${TIMEOUT_SECONDS}s"
    fi
    sleep "$POLL_INTERVAL_SECONDS"
  done

  if wait "$RUN_PID"; then status=0; else status=$?; fi
  RUN_PID=""
  [ "$status" -eq 0 ] || fail "$agent model call exited with status $status"
  [ -s "$events" ] || fail "$agent model call returned no events: $events"
}

[ "${MULTI_PRIMARY_E2E_CONFIRM:-}" = run-exactly-one-paid-workflow ] || {
  printf 'ERROR: set MULTI_PRIMARY_E2E_CONFIRM=run-exactly-one-paid-workflow\n' >&2
  exit 2
}
[ -x "${OPENCODE_BIN:-}" ] || { printf 'ERROR: OPENCODE_BIN is required\n' >&2; exit 2; }

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/multi-primary-e2e.XXXXXX")"
PROJECT="$SCRATCH/project"
mkdir -p "$PROJECT"
cp "$FIXTURE/pom.xml" "$FIXTURE/.gitignore" "$PROJECT/"
cp -R "$FIXTURE/src" "$PROJECT/src"

(
  cd "$PROJECT"
  git init -q -b main
  git add -A
  GIT_AUTHOR_NAME=multi-primary GIT_AUTHOR_EMAIL=e2e@example.invalid \
    GIT_COMMITTER_NAME=multi-primary GIT_COMMITTER_EMAIL=e2e@example.invalid \
    git commit -qm 'fixture baseline'
)

OPENCODE_BIN="$OPENCODE_BIN" \
  "$PROFILE" install --project-root "$PROJECT" --no-install-brew-tools \
  > "$SCRATCH/profile-install.log" 2>&1 || {
    printf 'FAIL: current checkout profile install failed; see %s\n' "$SCRATCH/profile-install.log" >&2
    exit 1
  }

run_model_call deep-planner "$SCRATCH/plan.events.jsonl" \
  'Create one execution plan for adding Order.lineCount() with focused coverage. This is localized and has no open product decisions.'

PLAN="$(find "$PROJECT/.ai/deep-planner/plans" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print -quit)"
[ -n "$PLAN" ] || { printf 'FAIL: Deep Plan produced no plan\n' >&2; exit 1; }
BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
RELATIVE_PLAN="${PLAN#"$PROJECT/"}"

run_model_call orchestraitor "$SCRATCH/execute.events.jsonl" \
  "ejecuta el plan $RELATIVE_PLAN"

AFTER="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
[ "$BEFORE" = "$AFTER" ] || { printf 'FAIL: source plan changed\n' >&2; exit 1; }
[ ! -e "$PROJECT/.ai/orchestration/runs" ] || { printf 'FAIL: localized plan created SDD state\n' >&2; exit 1; }
grep -Rq 'lineCount' "$PROJECT/src/main" || { printf 'FAIL: lineCount was not implemented\n' >&2; exit 1; }
grep -Rq 'lineCount' "$PROJECT/src/test" || { printf 'FAIL: lineCount has no test\n' >&2; exit 1; }
(cd "$PROJECT" && mvn -q -o test)

printf 'PASS: Deep Plan and direct Orchestraitor E2E\n'
