#!/usr/bin/env bash
# Software factory: run several independent tasks at the same time, each in its
# own Git worktree and branch, with a background worker for each task.
#
# Usage (run from inside the repository):
#   factory.sh add <id> <brief-file|->   Store a brief. State: queued.
#   factory.sh start [<id>...] [--max N] Start queued tasks in the background.
#   factory.sh status                    Write and print .ai/factory/board.md.
#   factory.sh answer <id> <text>        Add an answer and start the task again.
#   factory.sh logs <id> [lines]         Print the end of the log (default 40).
#   factory.sh merge <id>                Merge a done task into the current branch.
#   factory.sh drop <id>                 Stop the task. Remove worktree, branch, state.
#
# Environment:
#   FACTORY_RUNNER     Command that gets the prompt as its last argument and runs
#                      in the worktree. The shell splits it into words, so use
#                      an absolute path without spaces.
#                      Default: opencode run --agent worker --title "factory/<id>"
#                      (plus --auto when `opencode run --help` lists it).
#   FACTORY_WORKTREES  Parent directory of the worktrees. A relative path starts
#                      at the repository root.
#                      Default: <repo-parent>/.<repo-name>-factory
#   FACTORY_DRY_RUN=1  `start` prints the runner command and starts nothing.
#
# Bash 3.2 compatible. No jq.
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
case "$SELF" in /*) ;; *) SELF="$PWD/$SELF" ;; esac

die() {
  echo "factory: $*" >&2
  exit 1
}

usage() {
  sed -n '2,12p' "$SELF" | sed 's/^# \{0,1\}//'
}

# --- Paths -------------------------------------------------------------------

init_paths() {
  REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not in a Git repository"
  # In a factory worktree the state would go to a second, nested factory.
  if [ "$(git -C "$REPO" rev-parse --git-dir)" != "$(git -C "$REPO" rev-parse --git-common-dir)" ]; then
    case "$(git -C "$REPO" symbolic-ref -q --short HEAD || true)" in
      factory/*) die "this is a factory worktree; run from the main working tree of the repository" ;;
    esac
  fi
  FACTORY_DIR="$REPO/.ai/factory"
  TASKS_DIR="$FACTORY_DIR/tasks"
  LOGS_DIR="$FACTORY_DIR/logs"
  STATE_DIR="$FACTORY_DIR/state"
  BOARD="$FACTORY_DIR/board.md"
  WORKTREES="${FACTORY_WORKTREES:-$(dirname "$REPO")/.$(basename "$REPO")-factory}"
  case "$WORKTREES" in /*) ;; *) WORKTREES="$REPO/$WORKTREES" ;; esac
}

init_state() {
  mkdir -p "$TASKS_DIR" "$LOGS_DIR" "$STATE_DIR"
  if ! git -C "$REPO" check-ignore -q .ai/factory; then
    local exclude
    exclude="$(cd "$REPO" && cd "$(git rev-parse --git-common-dir)" && pwd)/info/exclude"
    mkdir -p "$(dirname "$exclude")"
    # Start a new line if the last line of the file has no end.
    if [ -s "$exclude" ] && [ -n "$(tail -c 1 "$exclude")" ]; then echo >>"$exclude"; fi
    echo ".ai/" >>"$exclude"
  fi
}

read_file() {
  if [ -f "$1" ]; then cat "$1"; fi
}

valid_id() {
  echo "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'
}

# The id becomes part of paths that drop deletes. Check its form before each use.
require_id() {
  [ -n "${1:-}" ] || die "missing task id"
  valid_id "$1" || die "invalid id: $1 (use kebab-case, for example fix-login)"
  [ -f "$TASKS_DIR/$1.md" ] || die "unknown task: $1"
}

# --- Task state --------------------------------------------------------------

# Print the text of the last FACTORY: line of the last run, without the prefix.
last_factory_line() {
  local log="$LOGS_DIR/$1.log" esc
  [ -f "$log" ] || return 0
  esc="$(printf '\033')"
  # LC_ALL=C: a log can have bytes that are not valid text in the locale of the user.
  LC_ALL=C tr -d '\r' <"$log" | LC_ALL=C sed "s/${esc}\\[[0-9;]*[A-Za-z]//g" | LC_ALL=C awk '
    /^--- factory run / { last = ""; next }
    {
      line = $0
      sub(/^[ \t`*>]+/, "", line)
      if (line ~ /^FACTORY:[ \t]*(done|needs-input|failed)([ \t`*.:]|$)/) last = line
    }
    END {
      sub(/^FACTORY:[ \t]*/, "", last)
      sub(/[ \t`*]+$/, "", last)
      if (match(last, /^(done|needs-input|failed)/)) {
        key = substr(last, 1, RLENGTH)
        rest = substr(last, RLENGTH + 1)
        sub(/^[ \t`*.:]+/, "", rest)
        print (rest == "" ? key : key " " rest)
      }
    }'
}

pid_alive() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

# Print the start time of a process. Empty if the process or ps is not available.
pid_start() {
  LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | sed 's/^ *//; s/ *$//' || true
}

# True if the runner of the task is alive. The system can give the pid of an
# ended runner to a different process, so the start time must agree too.
runner_alive() {
  local id="$1" pid saved
  pid="$(read_file "$STATE_DIR/$id.pid")"
  saved="$(read_file "$STATE_DIR/$id.pidstart")"
  pid_alive "$pid" || return 1
  [ -z "$saved" ] || [ "$(pid_start "$pid")" = "$saved" ]
}

# Set T_STATE and T_NOTE for a task. Sources: the state mark, the exit code of
# the runner, the pid, and the last FACTORY: line in the log.
task_state() {
  local id="$1" mark rc line
  T_STATE=""
  T_NOTE=""
  mark="$(read_file "$STATE_DIR/$id.state")"
  case "$mark" in
    queued | "")
      T_STATE="queued"
      return 0
      ;;
    merged | conflict)
      T_STATE="$mark"
      T_NOTE="$(read_file "$STATE_DIR/$id.note")"
      return 0
      ;;
  esac
  if [ -f "$STATE_DIR/$id.exit" ]; then
    rc="$(cat "$STATE_DIR/$id.exit")"
    line="$(last_factory_line "$id")"
    if [ "$rc" != "0" ]; then
      T_STATE="failed"
      T_NOTE="runner exit code $rc"
      case "$line" in failed\ *) T_NOTE="${line#failed } (exit code $rc)" ;; esac
      return 0
    fi
    case "$line" in
      done*) T_STATE="done" ;;
      needs-input*)
        T_STATE="needs-input"
        T_NOTE="${line#needs-input}"
        T_NOTE="${T_NOTE# }"
        ;;
      failed*)
        T_STATE="failed"
        T_NOTE="${line#failed}"
        T_NOTE="${T_NOTE# }"
        ;;
      *)
        T_STATE="failed"
        T_NOTE="no FACTORY line in the log"
        ;;
    esac
    return 0
  fi
  if runner_alive "$id"; then
    T_STATE="running"
  elif [ -f "$STATE_DIR/$id.exit" ]; then
    # The runner ended between the two checks. Read the result.
    task_state "$id"
  else
    T_STATE="failed"
    T_NOTE="runner stopped without an exit code"
  fi
}

task_ids() {
  local file
  for file in "$TASKS_DIR"/*.md; do
    [ -f "$file" ] || continue
    basename "$file" .md
  done
}

count_running() {
  local id count=0
  for id in $(task_ids); do
    task_state "$id"
    if [ "$T_STATE" = "running" ]; then count=$((count + 1)); fi
  done
  echo "$count"
}

commits_ahead() {
  local id="$1" base
  if [ -f "$STATE_DIR/$id.commits" ]; then
    cat "$STATE_DIR/$id.commits"
    return 0
  fi
  base="$(read_file "$STATE_DIR/$id.base")"
  if [ -n "$base" ] && git -C "$REPO" rev-parse -q --verify "refs/heads/factory/$id" >/dev/null; then
    git -C "$REPO" rev-list --count "$base..factory/$id"
  else
    echo "-"
  fi
}

# --- Runner ------------------------------------------------------------------

# Print the runner command line without the prompt.
runner_line() {
  local id="$1" line help
  if [ -n "${FACTORY_RUNNER:-}" ]; then
    echo "$FACTORY_RUNNER"
    return 0
  fi
  line="opencode run --agent worker --title \"factory/$id\""
  # OpenCode v2 has --auto. OpenCode v1 does not, and it approves by default.
  # No pipe to grep -q: with pipefail, an early exit of grep can make the test false.
  help="$(opencode run --help 2>&1 || true)"
  case "$help" in *--auto*) line="$line --auto" ;; esac
  echo "$line"
}

require_runner() {
  local first
  if [ -n "${FACTORY_RUNNER:-}" ]; then
    first="${FACTORY_RUNNER%% *}"
    command -v "$first" >/dev/null 2>&1 || die "runner not found: $first (from FACTORY_RUNNER)"
  else
    command -v opencode >/dev/null 2>&1 || die "runner not found: opencode (install it or set FACTORY_RUNNER)"
  fi
}

# The fixed worker contract. It is here, not in the skill, so each run gets the same text.
worker_prompt() {
  local id="$1"
  cat <<EOF
You are a factory worker. You work alone in a Git worktree on the branch factory/$id. No person can answer you during the work.

Rules:
1. Do the task in the brief below. Change files only in this directory.
2. Do not ask questions during the work. The question tool is not available. For a small gap, make the smallest safe assumption and write it in your last message.
3. Run the checks that the brief gives. Fix what fails.
4. Commit your work on this branch. Stage explicit paths only: git add -- <paths>. Do not use "git add ." or "git add -A". Do not commit .ai/.
5. Do not push. Do not change or delete other branches.
6. End your last message with one result line. The line starts with the word FACTORY. Put no other text on that line.
   When the work is complete and committed, the line is: FACTORY: done
   When you cannot continue without the user, the line is: FACTORY: needs-input <one question>
   When the work failed, the line is: FACTORY: failed <short reason>

Brief:

EOF
  cat "$TASKS_DIR/$id.md"
}

# Start the runner for a task in the background. The task must have a worktree.
launch() {
  local id="$1"
  rm -f "$STATE_DIR/$id.exit" "$STATE_DIR/$id.note" "$STATE_DIR/$id.pidstart"
  echo "started" >"$STATE_DIR/$id.state"
  echo "--- factory run $id $(date -u '+%Y-%m-%dT%H:%M:%SZ') ---" >>"$LOGS_DIR/$id.log"
  # Job control gives the job its own process group, so a signal to the group
  # of the caller does not stop it. nohup makes it ignore the hangup signal.
  set -m
  nohup bash "$SELF" __run "$id" </dev/null >>"$LOGS_DIR/$id.log" 2>&1 &
  echo "$!" >"$STATE_DIR/$id.pid"
  set +m
  pid_start "$!" >"$STATE_DIR/$id.pidstart"
}

# Internal: run the runner in the foreground and record its exit code.
cmd_run() {
  local id="$1" rc=0 line prompt
  line="$(runner_line "$id")"
  prompt="$(worker_prompt "$id")"
  (cd "$WORKTREES/$id" && bash -c "$line \"\$1\"" factory-runner "$prompt") || rc=$?
  echo "$rc" >"$STATE_DIR/$id.exit.tmp"
  mv "$STATE_DIR/$id.exit.tmp" "$STATE_DIR/$id.exit"
}

stop_task() {
  local id="$1" pid tries=0
  [ -f "$STATE_DIR/$id.exit" ] && return 0
  pid="$(read_file "$STATE_DIR/$id.pid")"
  runner_alive "$id" || return 0
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  while pid_alive "$pid" && [ "$tries" -lt 50 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
  if pid_alive "$pid"; then
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
  fi
}

remove_worktree() {
  local id="$1"
  if [ -d "$WORKTREES/$id" ]; then
    git -C "$REPO" worktree remove --force "$WORKTREES/$id" 2>/dev/null || rm -rf "${WORKTREES:?}/$id"
  fi
  git -C "$REPO" worktree prune
  if git -C "$REPO" rev-parse -q --verify "refs/heads/factory/$id" >/dev/null; then
    git -C "$REPO" branch -q -D "factory/$id"
  fi
  rmdir "$WORKTREES" 2>/dev/null || true
}

# --- Commands ----------------------------------------------------------------

cmd_add() {
  local id="${1:-}" src="${2:-}"
  [ -n "$id" ] && [ -n "$src" ] || die "usage: add <id> <brief-file|->"
  valid_id "$id" || die "invalid id: $id (use kebab-case, for example fix-login)"
  [ ! -e "$TASKS_DIR/$id.md" ] || die "task exists already: $id"
  if [ "$src" != "-" ] && [ ! -f "$src" ]; then die "brief file not found: $src"; fi
  if [ "$src" = "-" ]; then cat >"$TASKS_DIR/$id.md"; else cat "$src" >"$TASKS_DIR/$id.md"; fi
  if ! grep -q '[^[:space:]]' "$TASKS_DIR/$id.md"; then
    rm -f "$TASKS_DIR/$id.md"
    die "brief is empty: $id"
  fi
  echo "queued" >"$STATE_DIR/$id.state"
  echo "$id: queued"
}

start_one() {
  local id="$1" base
  if [ "${FACTORY_DRY_RUN:-}" = "1" ]; then
    echo "$id: dry-run: $(runner_line "$id") <prompt>"
    return 0
  fi
  if [ ! -d "$WORKTREES/$id" ]; then
    if git -C "$REPO" rev-parse -q --verify "refs/heads/factory/$id" >/dev/null; then
      die "branch exists already: factory/$id"
    fi
    base="$(git -C "$REPO" rev-parse -q --verify 'HEAD^{commit}')" || die "the repository has no commit"
    mkdir -p "$WORKTREES"
    git -C "$REPO" worktree add -q -b "factory/$id" "$WORKTREES/$id" "$base" >/dev/null
    echo "$base" >"$STATE_DIR/$id.base"
  fi
  launch "$id"
  echo "$id: running (branch factory/$id, worktree $WORKTREES/$id)"
}

cmd_start() {
  local max="" ids="" id slots started=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --max)
        max="${2:-}"
        shift 2 || die "--max needs a number"
        ;;
      --max=*)
        max="${1#--max=}"
        shift
        ;;
      -*) die "unknown option: $1" ;;
      *)
        ids="$ids $1"
        shift
        ;;
    esac
  done
  if [ -n "$max" ]; then
    echo "$max" | grep -Eq '^[1-9][0-9]*$' || die "--max needs a number greater than 0"
  fi
  require_runner
  if [ -z "$ids" ]; then
    for id in $(task_ids); do
      task_state "$id"
      if [ "$T_STATE" = "queued" ]; then ids="$ids $id"; fi
    done
    if [ -z "$ids" ]; then
      echo "no queued tasks"
      return 0
    fi
  else
    for id in $ids; do require_id "$id"; done
  fi
  slots=""
  if [ -n "$max" ]; then
    slots=$((max - $(count_running)))
  fi
  for id in $ids; do
    task_state "$id"
    case "$T_STATE" in
      queued | failed | needs-input) ;;
      *)
        echo "$id: not started (state $T_STATE)"
        continue
        ;;
    esac
    if [ -n "$slots" ] && [ "$started" -ge "$slots" ]; then
      echo "$id: $T_STATE (limit --max $max reached)"
      continue
    fi
    start_one "$id"
    started=$((started + 1))
  done
}

cmd_status() {
  local id ids note
  ids="$(task_ids)"
  {
    echo "# Factory board"
    echo
    echo "Updated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo
    if [ -z "$ids" ]; then
      echo "No tasks."
    else
      echo "| Task | State | Commits | Note |"
      echo "| --- | --- | --- | --- |"
      for id in $ids; do
        task_state "$id"
        note="$(printf '%s' "$T_NOTE" | tr '\n' ' ' | sed 's/|/\\|/g')"
        echo "| $id | $T_STATE | $(commits_ahead "$id") | $note |"
      done
    fi
  } >"$BOARD.tmp.$$"
  # The pid in the name keeps two status calls at the same time apart.
  mv "$BOARD.tmp.$$" "$BOARD"
  cat "$BOARD"
}

cmd_answer() {
  local id="${1:-}"
  require_id "$id"
  shift
  [ -n "$*" ] || die "usage: answer <id> <text>"
  task_state "$id"
  case "$T_STATE" in
    running) die "task is running: $id (wait for it or drop it)" ;;
    queued) die "task is not started: $id (run start)" ;;
    merged) die "task is merged: $id" ;;
  esac
  [ -d "$WORKTREES/$id" ] || die "worktree not found: $WORKTREES/$id"
  require_runner
  printf '\n## Answer\n\n%s\n' "$*" >>"$TASKS_DIR/$id.md"
  launch "$id"
  echo "$id: running (answer added)"
}

cmd_logs() {
  local id="${1:-}" lines="${2:-40}"
  require_id "$id"
  echo "$lines" | grep -Eq '^[1-9][0-9]*$' || die "lines must be a number greater than 0"
  if [ -f "$LOGS_DIR/$id.log" ]; then
    tail -n "$lines" "$LOGS_DIR/$id.log"
  else
    echo "$id: no log (the task is not started)"
  fi
}

cmd_merge() {
  local id="${1:-}" count files target
  require_id "$id"
  task_state "$id"
  case "$T_STATE" in
    done | conflict) ;;
    *) die "cannot merge $id: state is $T_STATE (merge needs done)" ;;
  esac
  # A merge of the user is not a conflict of this task. Do not abort it.
  if git -C "$REPO" rev-parse -q --verify MERGE_HEAD >/dev/null; then
    die "a merge is in progress in $REPO; complete it or abort it, then merge $id again"
  fi
  target="$(git -C "$REPO" symbolic-ref -q --short HEAD || echo "detached HEAD")"
  count="$(git -C "$REPO" rev-list --count "$(cat "$STATE_DIR/$id.base")..factory/$id")"
  if ! git -C "$REPO" merge --no-edit "factory/$id" >"$STATE_DIR/$id.merge.log" 2>&1; then
    if git -C "$REPO" rev-parse -q --verify MERGE_HEAD >/dev/null; then
      files="$(git -C "$REPO" diff --name-only --diff-filter=U | tr '\n' ' ')"
      git -C "$REPO" merge --abort
      echo "conflict" >"$STATE_DIR/$id.state"
      echo "merge conflict in: ${files% }" >"$STATE_DIR/$id.note"
      rm -f "$STATE_DIR/$id.merge.log"
      echo "$id: conflict (merge aborted; files: ${files% })" >&2
      exit 1
    fi
    cat "$STATE_DIR/$id.merge.log" >&2
    rm -f "$STATE_DIR/$id.merge.log"
    die "git refused the merge of $id; the state did not change"
  fi
  rm -f "$STATE_DIR/$id.merge.log" "$STATE_DIR/$id.note"
  echo "$count" >"$STATE_DIR/$id.commits"
  echo "merged" >"$STATE_DIR/$id.state"
  # Work that the worker did not commit is not in the merge. Keep it for the user.
  if [ -d "$WORKTREES/$id" ] && [ -n "$(git -C "$WORKTREES/$id" status --porcelain)" ]; then
    echo "worktree kept: files without commit in $WORKTREES/$id" >"$STATE_DIR/$id.note"
    echo "$id: merged into $target (commits: $count); worktree kept because it has files without commit. Run drop $id to remove it."
    return 0
  fi
  remove_worktree "$id"
  echo "$id: merged into $target (commits: $count); worktree and branch removed"
}

cmd_drop() {
  local id="${1:-}" tip=""
  require_id "$id"
  stop_task "$id"
  # Commits that are not in the current branch stay in Git for some time. Give their address.
  if tip="$(git -C "$REPO" rev-parse -q --verify "refs/heads/factory/$id")" &&
    git -C "$REPO" merge-base --is-ancestor "$tip" HEAD 2>/dev/null; then
    tip=""
  fi
  remove_worktree "$id"
  rm -f "$TASKS_DIR/$id.md" "$LOGS_DIR/$id.log" "$STATE_DIR/$id".*
  if [ -n "$tip" ]; then
    echo "$id: dropped (commits not merged; the branch was at $tip)"
  else
    echo "$id: dropped"
  fi
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    "" | help | -h | --help)
      usage
      [ -n "$cmd" ] || exit 2
      exit 0
      ;;
  esac
  shift
  init_paths
  case "$cmd" in
    __run)
      cmd_run "$@"
      return 0
      ;;
  esac
  init_state
  case "$cmd" in
    add) cmd_add "$@" ;;
    start) cmd_start "$@" ;;
    status) cmd_status ;;
    answer) cmd_answer "$@" ;;
    logs) cmd_logs "$@" ;;
    merge) cmd_merge "$@" ;;
    drop) cmd_drop "$@" ;;
    *)
      usage >&2
      die "unknown command: $cmd"
      ;;
  esac
}

main "$@"
