#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OPENCODE_BIN=${OPENCODE_BIN:-$(command -v opencode || true)}
[[ "${SDD_SWARM_REAL_BENCHMARK_APPROVED:-0}" == 1 ]] || {
  echo "FAIL: set SDD_SWARM_REAL_BENCHMARK_APPROVED=1 because the Task probe spends model tokens" >&2
  exit 1
}
[[ -n "$OPENCODE_BIN" ]] || { echo "FAIL: opencode is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }

OUTPUT=${SDD_SWARM_TASK_PROBE_OUTPUT:-$PWD/.ai/sdd-swarm-task-probe.jsonl}
REPORT=${SDD_SWARM_TASK_PROBE_REPORT:-${OUTPUT%.jsonl}.report.json}
CANCEL_OUTPUT=${SDD_SWARM_TASK_CANCEL_OUTPUT:-${OUTPUT%.jsonl}.cancel.jsonl}
MODEL_ARGS=()
[[ -z "${SDD_SWARM_TASK_PROBE_MODEL:-}" ]] || MODEL_ARGS=(--model "$SDD_SWARM_TASK_PROBE_MODEL")
CANCEL_PID=""

cleanup() {
  if [[ -n "$CANCEL_PID" ]] && kill -0 "$CANCEL_PID" >/dev/null 2>&1; then
    kill -TERM "$CANCEL_PID" >/dev/null 2>&1 || true
    wait "$CANCEL_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$(dirname "$OUTPUT")" "$(dirname "$REPORT")" "$(dirname "$CANCEL_OUTPUT")"
STARTED_MS=$(node -e 'console.log(Date.now())')
OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true "$OPENCODE_BIN" run \
  --dir "$ROOT" \
  --agent orchestraitor \
  "${MODEL_ARGS[@]}" \
  --format json \
  --auto \
  "Read-only Task probe: in one response launch exactly four general subagents with background true. Assign one distinct README or documentation file to each, ask only for its first heading, do not edit anything, do not poll, and allow the automatic completion notifications to arrive." \
  >"$OUTPUT"
ENDED_MS=$(node -e 'console.log(Date.now())')

START_COUNT=$(jq -s '[.[] | select(.part?.tool == "task" and .part.state.input?.background == true)] | length' "$OUTPUT")
NOTIFICATION_COUNT=$(jq -s '[.[] | select(((.part?.text? // "") | test("<task id=.* state=\\\"(completed|error)\\\">")))] | length' "$OUTPUT")
LAST_START_LINE=$(jq -r 'select(.part?.tool == "task" and .part.state.input?.background == true) | input_line_number' "$OUTPUT" | tail -1)
FIRST_NOTIFICATION_LINE=$(jq -r 'select(((.part?.text? // "") | test("<task id=.* state=\\\"(completed|error)\\\">"))) | input_line_number' "$OUTPUT" | head -1)
[[ "$START_COUNT" -eq 4 ]] || { echo "FAIL: expected 4 background Task calls, observed $START_COUNT" >&2; exit 1; }
[[ "$NOTIFICATION_COUNT" -eq 4 ]] || { echo "FAIL: expected 4 automatic Task notifications, observed $NOTIFICATION_COUNT" >&2; exit 1; }
[[ -n "$LAST_START_LINE" && -n "$FIRST_NOTIFICATION_LINE" && "$LAST_START_LINE" -lt "$FIRST_NOTIFICATION_LINE" ]] || {
  echo "FAIL: the four Task calls were not all launched before the first notification" >&2
  exit 1
}

OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true "$OPENCODE_BIN" run \
  --dir "$ROOT" \
  --agent orchestraitor \
  "${MODEL_ARGS[@]}" \
  --format json \
  --auto \
  "Cancellation probe: launch one general subagent with background true to read and compare every Markdown file under docs/. Do not edit. After launch, continue your own read-only inspection so the parent remains active until interrupted." \
  >"$CANCEL_OUTPUT" 2>"${CANCEL_OUTPUT%.jsonl}.stderr.log" &
CANCEL_PID=$!
for ((attempt = 0; attempt < 600; attempt++)); do
  CANCEL_STARTED=$(jq -s '[.[] | select(.part?.tool == "task" and .part.state.input?.background == true)] | length' "$CANCEL_OUTPUT" 2>/dev/null || echo 0)
  [[ "$CANCEL_STARTED" -ge 1 ]] && break
  kill -0 "$CANCEL_PID" >/dev/null 2>&1 || { echo "FAIL: cancellation parent exited before launching Task" >&2; exit 1; }
  sleep 0.1
done
[[ "${CANCEL_STARTED:-0}" -ge 1 ]] || { echo "FAIL: cancellation Task did not start" >&2; exit 1; }
kill -TERM "$CANCEL_PID"
set +e
wait "$CANCEL_PID"
CANCEL_EXIT=$?
set -e
CANCEL_PID=""
[[ "$CANCEL_EXIT" -ne 0 ]] || { echo "FAIL: interrupted Task parent returned success" >&2; exit 1; }

jq -nc \
  --argjson background_calls "$START_COUNT" \
  --argjson notifications "$NOTIFICATION_COUNT" \
  --argjson fanout_before_notification true \
  --argjson wall_ms "$((ENDED_MS - STARTED_MS))" \
  --argjson cancellation_parent_exit "$CANCEL_EXIT" \
  '{background_calls:$background_calls,notifications:$notifications,fanout_before_notification:$fanout_before_notification,wall_ms:$wall_ms,cancellation:{signal:"SIGTERM",parent_exit:$cancellation_parent_exit,background_started:true}}' \
  >"$REPORT"

echo "PASS: OpenCode launched four background Tasks before notification and propagated parent cancellation"
echo "Events: $OUTPUT"
echo "Cancellation events: $CANCEL_OUTPUT"
echo "Report: $REPORT"
