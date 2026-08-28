#!/usr/bin/env bash
# Opt-in paid flow: Deep Plan creates one plan, then Orchestraitor executes it directly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/scripts/fixtures/orchestration-agent-routes/java-orders"
PROFILE="$ROOT/scripts/multi-primary-profile.sh"
[ "${MULTI_PRIMARY_E2E_CONFIRM:-}" = run-exactly-one-paid-workflow ] || {
  printf 'ERROR: set MULTI_PRIMARY_E2E_CONFIRM=run-exactly-one-paid-workflow\n' >&2
  exit 2
}
[ -x "${OPENCODE_BIN:-}" ] || { printf 'ERROR: OPENCODE_BIN is required\n' >&2; exit 2; }

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/multi-primary-e2e.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT INT TERM
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

"$OPENCODE_BIN" run --dir "$PROJECT" --agent deep-planner --format json --auto \
  'Create one execution plan for adding Order.lineCount() with focused coverage. This is localized and has no open product decisions.' \
  > "$SCRATCH/plan.events.jsonl"

PLAN="$(find "$PROJECT/.ai/deep-planner/plans" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print -quit)"
[ -n "$PLAN" ] || { printf 'FAIL: Deep Plan produced no plan\n' >&2; exit 1; }
BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
RELATIVE_PLAN="${PLAN#"$PROJECT/"}"

"$OPENCODE_BIN" run --dir "$PROJECT" --agent orchestraitor --format json --auto \
  "ejecuta el plan $RELATIVE_PLAN" > "$SCRATCH/execute.events.jsonl"

AFTER="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
[ "$BEFORE" = "$AFTER" ] || { printf 'FAIL: source plan changed\n' >&2; exit 1; }
[ ! -e "$PROJECT/.ai/orchestration/runs" ] || { printf 'FAIL: localized plan created SDD state\n' >&2; exit 1; }
grep -Rq 'lineCount' "$PROJECT/src/main" || { printf 'FAIL: lineCount was not implemented\n' >&2; exit 1; }
grep -Rq 'lineCount' "$PROJECT/src/test" || { printf 'FAIL: lineCount has no test\n' >&2; exit 1; }
(cd "$PROJECT" && mvn -q -o test)

printf 'PASS: Deep Plan and direct Orchestraitor E2E\n'
