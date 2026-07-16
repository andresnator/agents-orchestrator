#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OPENCODE_BIN=${OPENCODE_BIN:-$(command -v opencode || true)}
TEST_TIMEOUT_SECONDS=15
POLL_INTERVAL_SECONDS=0.1
PROCESS_TERMINATION_TIMEOUT_SECONDS=2
FAKE_FILE_COUNT=7
INFO_DURATION_MS=5000
RECOVERY_DURATION_MS=8000

if [[ -z "$OPENCODE_BIN" ]]; then
  echo "FAIL: opencode is required (set OPENCODE_BIN to override)" >&2
  exit 1
fi

for command in curl git jq python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "FAIL: $command is required" >&2
    exit 1
  fi
done

SUITE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/codegraph-init-test.XXXXXX")
SUITE_DIR=$(cd "$SUITE_DIR" && pwd -P)
HOME_DIR="$SUITE_DIR/home"
XDG_DIR="$SUITE_DIR/xdg"
TARGET_DIR="$XDG_DIR/opencode"
FAKE_BIN_DIR="$SUITE_DIR/bin"
FAKE_LOG="$SUITE_DIR/codegraph.log"
SERVER_PID=""
LISTENER_PID=""
EVENTS_FILE=""
SERVER_LOG=""
PORT=""

terminate_pid() {
  local pid=$1
  local attempts=$((PROCESS_TERMINATION_TIMEOUT_SECONDS * 10))
  local attempt

  [[ "$pid" =~ ^[0-9]+$ ]] || return
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
    return
  fi

  kill "$pid" 2>/dev/null || true
  for ((attempt = 0; attempt < attempts; attempt++)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      return
    fi
    sleep "$POLL_INTERVAL_SECONDS"
  done

  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

cleanup_fake_initializers() {
  local pid_file
  local state_dir
  local pid

  while IFS= read -r -d '' pid_file; do
    state_dir=$(dirname "$pid_file")
    pid=$(<"$pid_file")
    : >"$state_dir/release"
    terminate_pid "$pid"
  done < <(find "$SUITE_DIR/repos" -type f -path '*/.fake-codegraph/init.pid' -print0 2>/dev/null)
}

cleanup_processes() {
  cleanup_fake_initializers
  if [[ -n "$LISTENER_PID" ]]; then
    terminate_pid "$LISTENER_PID"
    LISTENER_PID=""
  fi
  if [[ -n "$SERVER_PID" ]]; then
    terminate_pid "$SERVER_PID"
    SERVER_PID=""
  fi
  cleanup_fake_initializers
}

cleanup() {
  cleanup_processes
  rm -rf "$SUITE_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  echo "FAIL: $*" >&2
  if [[ -n "$SERVER_LOG" && -f "$SERVER_LOG" ]]; then
    sed -n '1,160p' "$SERVER_LOG" >&2
  fi
  if [[ -f "$FAKE_LOG" ]]; then
    sed -n '1,160p' "$FAKE_LOG" >&2
  fi
  exit 1
}

wait_for_file() {
  local file=$1
  local attempts=$((TEST_TIMEOUT_SECONDS * 10))
  local attempt
  for ((attempt = 0; attempt < attempts; attempt++)); do
    [[ -e "$file" ]] && return 0
    sleep "$POLL_INTERVAL_SECONDS"
  done
  fail "timed out waiting for file $file"
}

wait_for_pattern() {
  local pattern=$1
  local file=$2
  local attempts=$((TEST_TIMEOUT_SECONDS * 10))
  local attempt
  for ((attempt = 0; attempt < attempts; attempt++)); do
    [[ -f "$file" ]] && grep -Fq "$pattern" "$file" && return 0
    sleep "$POLL_INTERVAL_SECONDS"
  done
  fail "timed out waiting for '$pattern' in $file"
}

assert_toast() {
  local message=$1
  local variant=$2
  local duration=$3
  local expected_count=${4:-1}

  if ! python3 - "$EVENTS_FILE" "$message" "$variant" "$duration" "$expected_count" <<'PY'
import json
import sys

events_file, expected_message, expected_variant, expected_duration, expected_count = sys.argv[1:]
toasts = []
with open(events_file, encoding="utf-8") as events:
    for line in events:
        if not line.startswith("data: "):
            continue
        try:
            event = json.loads(line.removeprefix("data: "))
        except json.JSONDecodeError:
            continue
        payload = event.get("payload", {})
        if payload.get("type") == "tui.toast.show":
            toasts.append(payload.get("properties", {}))

matches = [toast for toast in toasts if toast.get("message") == expected_message]
valid_matches = [
    toast
    for toast in matches
    if toast.get("variant") == expected_variant
    and toast.get("duration") == int(expected_duration)
]
if len(matches) != int(expected_count) or len(valid_matches) != int(expected_count):
    print(
        f"expected {expected_count} exact toast(s), found {len(matches)}; all toasts: {json.dumps(toasts)}",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
  then
    fail "toast contract mismatch for: $message"
  fi
}

assert_toast_message_pattern() {
  local message_pattern=$1
  local variant=$2
  local duration=$3
  local expected_count=${4:-1}

  if ! python3 - "$EVENTS_FILE" "$message_pattern" "$variant" "$duration" "$expected_count" <<'PY'
import json
import re
import sys

events_file, message_pattern, expected_variant, expected_duration, expected_count = sys.argv[1:]
toasts = []
with open(events_file, encoding="utf-8") as events:
    for line in events:
        if not line.startswith("data: "):
            continue
        try:
            event = json.loads(line.removeprefix("data: "))
        except json.JSONDecodeError:
            continue
        payload = event.get("payload", {})
        if payload.get("type") == "tui.toast.show":
            toasts.append(payload.get("properties", {}))

matches = [toast for toast in toasts if re.fullmatch(message_pattern, toast.get("message", ""))]
valid_matches = [
    toast
    for toast in matches
    if toast.get("variant") == expected_variant
    and toast.get("duration") == int(expected_duration)
]
if len(matches) != int(expected_count) or len(valid_matches) != int(expected_count):
    print(
        f"expected {expected_count} matching toast(s), found {len(matches)}; all toasts: {json.dumps(toasts)}",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
  then
    fail "toast contract mismatch for pattern: $message_pattern"
  fi
}

wait_for_url() {
  local url=$1
  local attempts=$((TEST_TIMEOUT_SECONDS * 10))
  local attempt
  for ((attempt = 0; attempt < attempts; attempt++)); do
    curl -fsS --max-time 1 "$url" >/dev/null 2>&1 && return 0
    sleep "$POLL_INTERVAL_SECONDS"
  done
  fail "timed out waiting for $url"
}

free_port() {
  python3 - <<'PY'
import socket

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

start_server() {
  local name=$1
  local autoinit=$2
  local path_value=$3
  local codegraph_dir=${4:-}

  cleanup_processes
  PORT=$(free_port)
  EVENTS_FILE="$SUITE_DIR/$name.events"
  SERVER_LOG="$SUITE_DIR/$name.server.log"
  : >"$EVENTS_FILE"

  # The sentinel "unset" launches with OPENCODE_CODEGRAPH_AUTOINIT truly absent (env -u),
  # so an ambient value from the parent shell cannot leak in and mask default-on behavior.
  local -a autoinit_prefix
  if [[ "$autoinit" == unset ]]; then
    autoinit_prefix=(env -u OPENCODE_CODEGRAPH_AUTOINIT)
  else
    autoinit_prefix=(env "OPENCODE_CODEGRAPH_AUTOINIT=$autoinit")
  fi

  HOME="$HOME_DIR" \
    XDG_CONFIG_HOME="$XDG_DIR" \
    PATH="$path_value" \
    CODEGRAPH_DIR="$codegraph_dir" \
    FAKE_CODEGRAPH_LOG="$FAKE_LOG" \
    "${autoinit_prefix[@]}" \
    "$OPENCODE_BIN" serve --hostname 127.0.0.1 --port "$PORT" --print-logs --log-level ERROR \
    >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!

  wait_for_url "http://127.0.0.1:$PORT/global/health"
  curl -NsS --max-time 120 "http://127.0.0.1:$PORT/global/event" >"$EVENTS_FILE" 2>>"$SERVER_LOG" &
  LISTENER_PID=$!
  sleep 0.2
}

request_config() {
  local root=$1
  local output=$2
  curl -fsS --max-time 5 --get --data-urlencode "directory=$root" \
    "http://127.0.0.1:$PORT/config" >"$output"
  jq -e . "$output" >/dev/null
}

make_repo() {
  local name=$1
  local root="$SUITE_DIR/repos/$name"
  mkdir -p "$root"
  git -C "$root" init -q
  printf '%s\n' "$root"
}

make_linked_worktree() {
  local name=$1
  local primary="$SUITE_DIR/repos/$name-primary"
  local worktree="$SUITE_DIR/repos/$name"
  mkdir -p "$primary"
  git -C "$primary" init -q
  git -C "$primary" config user.email codegraph-test@example.invalid
  git -C "$primary" config user.name codegraph-test
  : >"$primary/tracked"
  git -C "$primary" add tracked
  git -C "$primary" commit -qm initial
  git -C "$primary" worktree add -qb "$name-branch" "$worktree"
  printf '%s\n' "$worktree"
}

count_init_calls() {
  local root=$1
  if [[ ! -f "$FAKE_LOG" ]]; then
    printf '0\n'
    return
  fi
  grep -Fc "init|$root|" "$FAKE_LOG" || true
}

count_index_calls() {
  local root=$1
  if [[ ! -f "$FAKE_LOG" ]]; then
    printf '0\n'
    return
  fi
  # "init|" never appears inside an "index|" line, so this counts repairs only.
  grep -Fc "index|$root|" "$FAKE_LOG" || true
}

mkdir -p "$HOME_DIR" "$TARGET_DIR" "$FAKE_BIN_DIR" "$SUITE_DIR/repos"

cat >"$FAKE_BIN_DIR/codegraph" <<'FAKE_CODEGRAPH'
#!/usr/bin/env bash
set -euo pipefail

command_name=${1:-}
root=${2:-$PWD}
codegraph_dir=${CODEGRAPH_DIR:-.codegraph}
index_dir="$root/$codegraph_dir"
state_dir="$root/.fake-codegraph"
repo_name=$(basename "$root")
mkdir -p "$state_dir"
printf '%s|%s|CODEGRAPH_DIR=%s\n' "$command_name" "$root" "${CODEGRAPH_DIR:-}" >>"$FAKE_CODEGRAPH_LOG"

case "$command_name" in
  status)
    case "$repo_name" in
      malformed-status-repo)
        printf '{"initialized":"false","indexPath":"%s"}\n' "$index_dir"
        exit 0
        ;;
      unknown-status-repo)
        printf '{"initialized":true,"indexPath":"%s","index":{"state":"unknown"}}\n' "$index_dir"
        exit 0
        ;;
      status-null-repo)
        # Repairs to complete once the fake index --force writes the ready marker.
        if [[ -f "$state_dir/ready" ]]; then
          state=complete
          initialized=true
        else
          printf '{"initialized":true,"indexPath":"%s","fileCount":0,"index":{"state":null}}\n' "$index_dir"
          exit 0
        fi
        ;;
      healthy-repo)
        state=complete
        initialized=true
        ;;
      partial-repo | failed-index-repo | abandoned-repo)
        # Unhealthy until a fake index --force writes the ready marker, then complete.
        if [[ -f "$state_dir/ready" ]]; then
          state=complete
          initialized=true
        else
          case "$repo_name" in
            partial-repo) state=partial ;;
            failed-index-repo) state=failed ;;
            abandoned-repo) state=indexing ;;
          esac
          initialized=true
        fi
        ;;
      repair-fail-repo | repair-incomplete-repo)
        # Stay partial regardless of markers: repair-fail-repo's index exits non-zero;
        # repair-incomplete-repo's index succeeds but the index never becomes complete.
        state=partial
        initialized=true
        ;;
      *)
        if [[ -f "$state_dir/ready" ]]; then
          state=complete
          initialized=true
        else
          state=null
          initialized=false
        fi
        ;;
    esac
    if [[ "$state" == null ]]; then
      printf '{"initialized":false,"indexPath":"%s","lastIndexed":null}\n' "$index_dir"
    else
      printf '{"initialized":%s,"indexPath":"%s","fileCount":%s,"index":{"state":"%s"}}\n' \
        "$initialized" "$index_dir" "${FAKE_CODEGRAPH_FILE_COUNT:-7}" "$state"
    fi
    ;;
  init)
    : >"$state_dir/init-started"
    printf '%s\n' "$$" >"$state_dir/init.pid"
    trap 'rm -f "$state_dir/init.pid"' EXIT
    if [[ "$repo_name" == fail-repo ]]; then
      echo "synthetic init failure" >&2
      exit 9
    fi
    until [[ -f "$state_dir/release" ]]; do
      sleep 0.05
    done
    mkdir -p "$index_dir"
    : >"$state_dir/ready"
    : >"$state_dir/init-finished"
    ;;
  index)
    # Repair path (index --force). Non-blocking: no release handshake.
    [[ "${3:-}" == "--force" ]] || { echo "index called without --force" >&2; exit 64; }
    : >"$state_dir/index-started"
    if [[ "$repo_name" == repair-fail-repo ]]; then
      echo "synthetic index failure" >&2
      exit 9
    fi
    mkdir -p "$index_dir"
    : >"$state_dir/ready"
    : >"$state_dir/index-finished"
    ;;
  *)
    echo "unexpected fake CodeGraph command: $command_name" >&2
    exit 64
    ;;
esac
FAKE_CODEGRAPH
chmod +x "$FAKE_BIN_DIR/codegraph"

HOME="$HOME_DIR" XDG_CONFIG_HOME="$XDG_DIR" \
  "$ROOT_DIR/installers/opencode.sh" install --domain common --target "$TARGET_DIR" >/dev/null

shouldKeepConfigResponsiveWhenIndexingInBackground() {
  # Given
  local root
  local response="$SUITE_DIR/background.config.json"
  root=$(make_repo success-repo)
  start_server background 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$root" "$response"

  # Then
  wait_for_file "$root/.fake-codegraph/init-started"
  [[ ! -e "$root/.fake-codegraph/init-finished" ]] || fail "fake init completed before release"
  wait_for_pattern "CodeGraph is indexing success-repo in the background. You can keep working." "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is indexing success-repo in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"

  : >"$root/.fake-codegraph/release"
  wait_for_file "$root/.fake-codegraph/init-finished"
  wait_for_pattern "CodeGraph index for success-repo is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  assert_toast_message_pattern \
    "CodeGraph index for success-repo is ready: $FAKE_FILE_COUNT files in [0-9]+\\.[0-9]s\\." \
    success \
    "$INFO_DURATION_MS"
  grep -Fxq '.codegraph/' "$root/.git/info/exclude" || fail "default CodeGraph directory was not Git-excluded"
  [[ $(count_init_calls "$root") -eq 1 ]] || fail "expected one init call for background case"
  cleanup_processes
}

shouldStaySilentWhenHealthyAndIdempotent() {
  # Given
  local success_root="$SUITE_DIR/repos/success-repo"
  local healthy_root
  local response="$SUITE_DIR/idempotent.config.json"
  local calls_before
  healthy_root=$(make_repo healthy-repo)
  calls_before=$(count_init_calls "$success_root")
  start_server idempotent 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$success_root" "$response"
  request_config "$healthy_root" "$SUITE_DIR/healthy.config.json"
  wait_for_pattern "status|$healthy_root|" "$FAKE_LOG"
  sleep 0.3

  # Then
  [[ $(count_init_calls "$success_root") -eq "$calls_before" ]] || fail "second session re-initialized healthy index"
  [[ $(count_init_calls "$healthy_root") -eq 0 ]] || fail "healthy index was initialized"
  ! grep -Fq '"type":"tui.toast.show"' "$EVENTS_FILE" || fail "healthy indexes emitted a toast"
  cleanup_processes
}

shouldRepairUnhealthyIndexesAutomatically() {
  # Given
  local partial_root
  local failed_index_root
  local abandoned_root
  local failed_root
  partial_root=$(make_repo partial-repo)
  failed_index_root=$(make_repo failed-index-repo)
  abandoned_root=$(make_repo abandoned-repo)
  failed_root=$(make_repo fail-repo)
  start_server unhealthy 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$partial_root" "$SUITE_DIR/partial.config.json"
  request_config "$failed_index_root" "$SUITE_DIR/failed-index.config.json"
  request_config "$abandoned_root" "$SUITE_DIR/abandoned.config.json"
  request_config "$failed_root" "$SUITE_DIR/failed.config.json"

  # Then: initialized-but-unhealthy indexes are repaired with index --force, not init.
  wait_for_pattern "CodeGraph is repairing the partial-repo index in the background." "$EVENTS_FILE"
  wait_for_pattern "CodeGraph index for partial-repo is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  wait_for_pattern "CodeGraph index for failed-index-repo is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  wait_for_pattern "CodeGraph index for abandoned-repo is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  wait_for_pattern "CodeGraph indexing failed for fail-repo, but this session is still operational." "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is repairing the partial-repo index in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  assert_toast \
    "CodeGraph is repairing the failed-index-repo index in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  assert_toast \
    "CodeGraph is repairing the abandoned-repo index in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  assert_toast_message_pattern \
    "CodeGraph index for partial-repo is ready: $FAKE_FILE_COUNT files in [0-9]+\\.[0-9]s\\." \
    success \
    "$INFO_DURATION_MS"
  assert_toast_message_pattern \
    "CodeGraph index for failed-index-repo is ready: $FAKE_FILE_COUNT files in [0-9]+\\.[0-9]s\\." \
    success \
    "$INFO_DURATION_MS"
  assert_toast_message_pattern \
    "CodeGraph index for abandoned-repo is ready: $FAKE_FILE_COUNT files in [0-9]+\\.[0-9]s\\." \
    success \
    "$INFO_DURATION_MS"
  # An uninitialized index still uses init, and its failure still surfaces an error toast.
  assert_toast \
    "CodeGraph indexing failed for fail-repo, but this session is still operational. Run: codegraph status '$failed_root'" \
    error \
    "$RECOVERY_DURATION_MS"
  [[ $(count_index_calls "$partial_root") -eq 1 ]] || fail "partial index was not repaired exactly once"
  [[ $(count_index_calls "$failed_index_root") -eq 1 ]] || fail "failed index was not repaired exactly once"
  [[ $(count_index_calls "$abandoned_root") -eq 1 ]] || fail "abandoned index was not repaired exactly once"
  [[ $(count_init_calls "$partial_root") -eq 0 ]] || fail "repair used init instead of index"
  [[ $(count_init_calls "$failed_index_root") -eq 0 ]] || fail "repair used init instead of index"
  [[ $(count_init_calls "$abandoned_root") -eq 0 ]] || fail "repair used init instead of index"
  [[ $(count_index_calls "$failed_root") -eq 0 ]] || fail "uninitialized repo was repaired instead of initialized"
  [[ $(count_init_calls "$failed_root") -eq 1 ]] || fail "failed case did not attempt init exactly once"
  grep -Fxq '.codegraph/' "$partial_root/.git/info/exclude" || fail "repaired index was not Git-excluded"
  cleanup_processes
}

shouldUseRecoveryOnlyWhenStatusPayloadIsUnsafe() {
  # Given
  local malformed_root
  local unknown_root
  malformed_root=$(make_repo malformed-status-repo)
  unknown_root=$(make_repo unknown-status-repo)
  start_server unsafe-status 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$malformed_root" "$SUITE_DIR/malformed-status.config.json"
  request_config "$unknown_root" "$SUITE_DIR/unknown-status.config.json"

  # Then
  wait_for_pattern "CodeGraph indexing failed for malformed-status-repo" "$EVENTS_FILE"
  wait_for_pattern "CodeGraph indexing failed for unknown-status-repo" "$EVENTS_FILE"
  assert_toast \
    "CodeGraph indexing failed for malformed-status-repo, but this session is still operational. Run: codegraph status '$malformed_root'" \
    error \
    "$RECOVERY_DURATION_MS"
  assert_toast \
    "CodeGraph indexing failed for unknown-status-repo, but this session is still operational. Run: codegraph status '$unknown_root'" \
    error \
    "$RECOVERY_DURATION_MS"
  [[ $(count_init_calls "$malformed_root") -eq 0 ]] || fail "malformed status triggered lifecycle mutation"
  [[ $(count_init_calls "$unknown_root") -eq 0 ]] || fail "unknown status triggered lifecycle mutation"
  [[ $(count_index_calls "$malformed_root") -eq 0 ]] || fail "malformed status triggered index repair"
  [[ $(count_index_calls "$unknown_root") -eq 0 ]] || fail "unknown status triggered index repair"
  cleanup_processes
}

shouldRepairWhenInitializedIndexStateIsNull() {
  # Given
  local root
  root=$(make_repo status-null-repo)
  start_server status-null 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$root" "$SUITE_DIR/status-null.config.json"

  # Then: an initialized index with an unknown (null) state is treated as unhealthy and repaired.
  wait_for_pattern "CodeGraph is repairing the status-null-repo index in the background." "$EVENTS_FILE"
  wait_for_pattern "CodeGraph index for status-null-repo is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is repairing the status-null-repo index in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  assert_toast_message_pattern \
    "CodeGraph index for status-null-repo is ready: $FAKE_FILE_COUNT files in [0-9]+\\.[0-9]s\\." \
    success \
    "$INFO_DURATION_MS"
  [[ $(count_index_calls "$root") -eq 1 ]] || fail "null index state was not repaired exactly once"
  [[ $(count_init_calls "$root") -eq 0 ]] || fail "null index state used init instead of index"
  cleanup_processes
}

shouldTerminateHeldInitializerDuringCleanup() {
  # Given
  local root
  local initializer_pid
  root=$(make_repo cleanup-repo)
  start_server cleanup-held-init 1 "$FAKE_BIN_DIR:/usr/bin:/bin"
  request_config "$root" "$SUITE_DIR/cleanup-held-init.config.json"
  wait_for_file "$root/.fake-codegraph/init.pid"
  initializer_pid=$(<"$root/.fake-codegraph/init.pid")
  kill -0 "$initializer_pid" 2>/dev/null || fail "fake initializer was not running before cleanup"

  # When
  cleanup_processes

  # Then
  ! kill -0 "$initializer_pid" 2>/dev/null || fail "fake initializer survived cleanup"
}

shouldRespectCustomCodeGraphDirectory() {
  # Given
  local root
  root=$(make_repo custom-dir-repo)
  start_server custom-dir 1 "$FAKE_BIN_DIR:/usr/bin:/bin" .cg-custom

  # When
  request_config "$root" "$SUITE_DIR/custom.config.json"
  wait_for_file "$root/.fake-codegraph/init-started"
  : >"$root/.fake-codegraph/release"

  # Then
  wait_for_file "$root/.fake-codegraph/init-finished"
  wait_for_pattern "CodeGraph index for custom-dir-repo is ready" "$EVENTS_FILE"
  grep -Fq "init|$root|CODEGRAPH_DIR=.cg-custom" "$FAKE_LOG" || fail "CODEGRAPH_DIR was not passed to CodeGraph"
  grep -Fxq '.cg-custom/' "$root/.git/info/exclude" || fail "custom CodeGraph directory was not Git-excluded"
  cleanup_processes
}

shouldExcludeIndexFromLinkedWorktreeGitMetadata() {
  # Given
  local root
  local exclude_path
  root=$(make_linked_worktree linked-worktree-repo)
  exclude_path=$(git -C "$root" rev-parse --git-path info/exclude)
  [[ "$exclude_path" == /* ]] || exclude_path="$root/$exclude_path"
  start_server linked-worktree 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$root" "$SUITE_DIR/linked-worktree.config.json"
  wait_for_file "$root/.fake-codegraph/init-started"
  : >"$root/.fake-codegraph/release"

  # Then
  wait_for_file "$root/.fake-codegraph/init-finished"
  wait_for_pattern "CodeGraph index for linked-worktree-repo is ready" "$EVENTS_FILE"
  grep -Fxq '.codegraph/' "$exclude_path" || fail "linked worktree index was not added to the real Git exclude file"
  [[ ! -d "$root/.git" ]] || fail "linked worktree fixture unexpectedly used a .git directory"
  cleanup_processes
}

shouldRunByDefaultWithoutEnvironmentFlag() {
  # Given
  local root
  root=$(make_repo default-on-repo)
  start_server default-on unset "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$root" "$SUITE_DIR/default-on.config.json"

  # Then: the initializer runs with OPENCODE_CODEGRAPH_AUTOINIT absent (default-on).
  wait_for_file "$root/.fake-codegraph/init-started"
  wait_for_pattern "CodeGraph is indexing default-on-repo in the background." "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is indexing default-on-repo in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  : >"$root/.fake-codegraph/release"
  wait_for_file "$root/.fake-codegraph/init-finished"
  wait_for_pattern "CodeGraph index for default-on-repo is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  [[ $(count_init_calls "$root") -eq 1 ]] || fail "default-on did not initialize exactly once"
  cleanup_processes
}

shouldToastErrorWhenRepairFails() {
  # Given
  local fail_root
  local incomplete_root
  fail_root=$(make_repo repair-fail-repo)
  incomplete_root=$(make_repo repair-incomplete-repo)
  start_server repair-fail 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$fail_root" "$SUITE_DIR/repair-fail.config.json"
  request_config "$incomplete_root" "$SUITE_DIR/repair-incomplete.config.json"

  # Then: a failed repair errors; a repair that leaves the index unhealthy warns.
  wait_for_pattern "CodeGraph indexing failed for repair-fail-repo, but this session is still operational." "$EVENTS_FILE"
  wait_for_pattern "CodeGraph index for repair-incomplete-repo is incomplete (index state is partial)." "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is repairing the repair-fail-repo index in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  assert_toast \
    "CodeGraph indexing failed for repair-fail-repo, but this session is still operational. Run: codegraph status '$fail_root'" \
    error \
    "$RECOVERY_DURATION_MS"
  assert_toast \
    "CodeGraph index for repair-incomplete-repo is incomplete (index state is partial). Run: codegraph index '$incomplete_root' --force" \
    warning \
    "$RECOVERY_DURATION_MS"
  [[ $(count_index_calls "$fail_root") -eq 1 ]] || fail "repair-fail did not attempt index exactly once"
  [[ $(count_index_calls "$incomplete_root") -eq 1 ]] || fail "repair-incomplete did not attempt index exactly once"
  [[ $(count_init_calls "$fail_root") -eq 0 ]] || fail "repair-fail used init instead of index"
  cleanup_processes
}

shouldAggregateNestedRepositoriesUnderPlainRoot() {
  # Given a plain (non-git) workspace root holding git repositories two levels deep.
  local aggregate_root="$SUITE_DIR/repos/aggregate-root"
  local repo_a="$aggregate_root/gitlab/repo-a"
  local repo_b="$aggregate_root/gitlab/repo-b"
  local dep_repo="$aggregate_root/node_modules/dep-repo"
  local hidden_repo="$aggregate_root/.hidden/secret-repo"
  mkdir -p "$repo_a" "$repo_b" "$dep_repo" "$hidden_repo"
  git -C "$repo_a" init -q
  git -C "$repo_b" init -q
  git -C "$dep_repo" init -q
  git -C "$hidden_repo" init -q
  start_server aggregate 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$aggregate_root" "$SUITE_DIR/aggregate.config.json"

  # Then: one aggregate start toast naming exactly the two discoverable repositories.
  wait_for_pattern "CodeGraph is indexing 2 repositories under aggregate-root in the background." "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is indexing 2 repositories under aggregate-root in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"

  # Repositories are indexed sequentially: repo-b must not start until repo-a is released.
  wait_for_file "$repo_a/.fake-codegraph/init-started"
  sleep 0.3
  [[ ! -e "$repo_b/.fake-codegraph/init-started" ]] || fail "aggregate indexing was not sequential"
  : >"$repo_a/.fake-codegraph/release"
  wait_for_file "$repo_a/.fake-codegraph/init-finished"
  wait_for_file "$repo_b/.fake-codegraph/init-started"
  : >"$repo_b/.fake-codegraph/release"
  wait_for_file "$repo_b/.fake-codegraph/init-finished"

  # And one aggregate summary toast.
  wait_for_pattern "CodeGraph indexed 2 repositories under aggregate-root in" "$EVENTS_FILE"
  assert_toast_message_pattern \
    "CodeGraph indexed 2 repositories under aggregate-root in [0-9]+\\.[0-9]s\\." \
    success \
    "$INFO_DURATION_MS"

  # Only the two gitlab repos were touched; node_modules, hidden dirs, and the root were skipped.
  [[ $(count_init_calls "$repo_a") -eq 1 ]] || fail "repo-a was not initialized"
  [[ $(count_init_calls "$repo_b") -eq 1 ]] || fail "repo-b was not initialized"
  [[ $(count_init_calls "$dep_repo") -eq 0 ]] || fail "node_modules repo was initialized"
  [[ $(count_init_calls "$hidden_repo") -eq 0 ]] || fail "hidden repo was initialized"
  [[ $(count_init_calls "$aggregate_root") -eq 0 ]] || fail "plain workspace root was initialized"
  grep -Fxq '.codegraph/' "$repo_a/.git/info/exclude" || fail "repo-a index was not Git-excluded"
  grep -Fxq '.codegraph/' "$repo_b/.git/info/exclude" || fail "repo-b index was not Git-excluded"
  ! grep -Fq "CodeGraph is indexing repo-a" "$EVENTS_FILE" || fail "aggregate emitted a per-repo start toast"
  cleanup_processes
}

shouldFallBackToSingleRootWhenPlainDirHasNoNestedRepos() {
  # Given a plain (non-git) directory with no nested repositories.
  local root="$SUITE_DIR/repos/plain-fallback"
  mkdir -p "$root"
  : >"$root/loose-file"
  start_server plain-fallback 1 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$root" "$SUITE_DIR/plain-fallback.config.json"

  # Then: the folder root itself is initialized as a single root.
  wait_for_file "$root/.fake-codegraph/init-started"
  wait_for_pattern "CodeGraph is indexing plain-fallback in the background." "$EVENTS_FILE"
  assert_toast \
    "CodeGraph is indexing plain-fallback in the background. You can keep working." \
    info \
    "$INFO_DURATION_MS"
  : >"$root/.fake-codegraph/release"
  wait_for_file "$root/.fake-codegraph/init-finished"
  wait_for_pattern "CodeGraph index for plain-fallback is ready: $FAKE_FILE_COUNT files" "$EVENTS_FILE"
  [[ $(count_init_calls "$root") -eq 1 ]] || fail "plain fallback did not initialize the folder root once"
  cleanup_processes
}

shouldDoNothingWhenOptedOut() {
  # Given
  local root
  local log_size_before=0
  root=$(make_repo opt-out-repo)
  [[ -f "$FAKE_LOG" ]] && log_size_before=$(wc -c <"$FAKE_LOG" | tr -d ' ')
  start_server opt-out 0 "$FAKE_BIN_DIR:/usr/bin:/bin"

  # When
  request_config "$root" "$SUITE_DIR/opt-out.config.json"
  sleep 0.3

  # Then
  [[ $(wc -c <"$FAKE_LOG" | tr -d ' ') -eq "$log_size_before" ]] || fail "opt-out called CodeGraph"
  ! grep -Fq '"type":"tui.toast.show"' "$EVENTS_FILE" || fail "opt-out emitted a toast"
  cleanup_processes
}

shouldWarnWhenBinaryIsMissing() {
  # Given
  local root
  root=$(make_repo missing-binary-repo)
  start_server missing-binary 1 "/usr/bin:/bin"

  # When
  request_config "$root" "$SUITE_DIR/missing.config.json"

  # Then
  wait_for_pattern "CodeGraph CLI was not found. Run: npm install -g @colbymchenry/codegraph@1.4.1" "$EVENTS_FILE"
  wait_for_pattern '"variant":"warning"' "$EVENTS_FILE"
  cleanup_processes
}

shouldKeepConfigResponsiveWhenIndexingInBackground
shouldStaySilentWhenHealthyAndIdempotent
shouldRepairUnhealthyIndexesAutomatically
shouldUseRecoveryOnlyWhenStatusPayloadIsUnsafe
shouldRepairWhenInitializedIndexStateIsNull
shouldToastErrorWhenRepairFails
shouldRunByDefaultWithoutEnvironmentFlag
shouldTerminateHeldInitializerDuringCleanup
shouldRespectCustomCodeGraphDirectory
shouldExcludeIndexFromLinkedWorktreeGitMetadata
shouldAggregateNestedRepositoriesUnderPlainRoot
shouldFallBackToSingleRootWhenPlainDirHasNoNestedRepos
shouldDoNothingWhenOptedOut
shouldWarnWhenBinaryIsMissing

echo "PASS: codegraph-init background and notification contracts"
