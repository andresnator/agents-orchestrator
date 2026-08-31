#!/usr/bin/env bash
# shellcheck disable=SC2016 # Backticks in prompts are literal Markdown.
# Opt-in model-backed checks for adaptive orchestration and Git delivery.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/scripts/fixtures/orchestration-agent-routes/java-orders"
PROFILE="$ROOT/scripts/multi-primary-profile.sh"
TIMEOUT_SECONDS="${ORCHESTRATION_FLOW_TIMEOUT:-1200}"
SCENARIO="${1:-probe}"
RUN_PID=""
SCRATCH=""
PROJECT=""
EVENTS=""
STDERR_LOG=""
BASELINE_HEAD=""
MODEL_PATH="$PATH"

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
    git config user.name orchestration-flow
    git config user.email flow@example.invalid
    git config commit.gpgsign false
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git add -A
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git commit -qm 'fixture baseline'
  )
  BASELINE_HEAD="$(git -C "$PROJECT" rev-parse HEAD)"
}

install_current_profile() {
  OPENCODE_BIN="$OPENCODE_BIN" \
    "$PROFILE" install --project-root "$PROJECT" --no-install-brew-tools \
    > "$SCRATCH/profile-install.log" 2>&1 ||
    die "current checkout profile install failed; see $SCRATCH/profile-install.log"
}

run_agent() {
  local agent="$1" label="$2" prompt="$3" started status
  EVENTS="$SCRATCH/$label.events.jsonl"
  STDERR_LOG="$SCRATCH/$label.stderr.log"
  : > "$EVENTS"
  : > "$STDERR_LOG"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null PATH="$MODEL_PATH" \
    "$OPENCODE_BIN" run --dir "$PROJECT" --agent "$agent" --format json --auto \
    --title "$SCENARIO-$label" "$prompt" > "$EVENTS" 2> "$STDERR_LOG" &
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
    ! launched | grep -qx "$worker" || die "direct or blocked run launched $worker"
  done
}

assert_no_question() {
  ! jq -e 'select(.part?.tool == "question")' "$EVENTS" >/dev/null ||
    die 'run repeated a resolved question'
}

assert_sdd_confirmation_question() {
  jq -e 'select(.part?.tool == "question")' "$EVENTS" >/dev/null ||
    die 'SDD recommendation emitted no question event'
  jq -e 'select(.part?.tool == "question") | .part.state.input | tostring | contains("SDD")' \
    "$EVENTS" >/dev/null || die 'confirmation question did not offer SDD'
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

assert_head_unchanged() {
  [ "$(git -C "$PROJECT" rev-parse HEAD)" = "$BASELINE_HEAD" ] ||
    die 'run created an unexpected commit'
}

commit_count() {
  git -C "$PROJECT" rev-list --count "$BASELINE_HEAD..HEAD"
}

assert_commit_messages() {
  local expected="$1" actual
  actual="$(git -C "$PROJECT" log --reverse --format=%s "$BASELINE_HEAD..HEAD")"
  [ "$actual" = "$expected" ] || die "unexpected commit messages or order: $actual"
}

assert_commit_paths() {
  local commit="$1" expected="$2" actual
  actual="$(git -C "$PROJECT" diff-tree --no-commit-id --name-only -r "$commit" | LC_ALL=C sort)"
  [ "$actual" = "$expected" ] || die "unexpected paths in commit $commit: $actual"
}

assert_commit_chain() {
  local previous="$BASELINE_HEAD" commit parent
  while IFS= read -r commit; do
    [ -n "$commit" ] || continue
    parent="$(git -C "$PROJECT" rev-parse "$commit^")"
    [ "$parent" = "$previous" ] || die "non-continuous commit parent at $commit"
    previous="$commit"
  done < <(git -C "$PROJECT" rev-list --reverse "$BASELINE_HEAD..HEAD")
  [ "$previous" = "$(git -C "$PROJECT" rev-parse HEAD)" ] || die 'commit chain does not end at HEAD'
}

assert_no_ai_commits() {
  if git -C "$PROJECT" diff --name-only "$BASELINE_HEAD..HEAD" | grep -Eq '^\.ai(/|$)'; then
    die 'implementation commits contain .ai state'
  fi
}

assert_scope_clean() {
  [ -z "$(git -C "$PROJECT" status --short -- src/main src/test)" ] ||
    die 'committed implementation scope is not clean'
}

find_active_run() {
  find "$PROJECT/.ai/orchestration/runs" -mindepth 1 -maxdepth 1 -type d ! -name archive -print -quit 2>/dev/null
}

find_archived_run() {
  find "$PROJECT/.ai/orchestration/runs/archive" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null
}

require_active_run() {
  local run
  run="$(find_active_run)"
  [ -n "$run" ] || die 'expected active SDD run is missing'
  printf '%s\n' "$run"
}

require_archived_run() {
  local run
  run="$(find_archived_run)"
  [ -n "$run" ] || die 'completed SDD run was not archived'
  printf '%s\n' "$run"
}

assert_run_line() {
  local run="$1" expected="$2"
  grep -Fxq "$expected" "$run/run.md" || die "run ledger is missing: $expected"
}

assert_run_commit_ledger() {
  local run="$1" expected_rows actual_rows ordinal=1 commit message unit
  expected_rows="$(commit_count)"
  actual_rows="$(grep -c '^Commits: unit-' "$run/run.md" || true)"
  [ "$actual_rows" -eq "$expected_rows" ] ||
    die "run ledger has $actual_rows commit rows; expected $expected_rows"
  while IFS=$'\t' read -r commit message; do
    [ -n "$commit" ] || continue
    printf -v unit 'unit-%02d' "$ordinal"
    grep -Fxq "Commits: $unit | $commit | $message" "$run/run.md" ||
      die "run ledger is missing $unit full SHA or message"
    ordinal=$((ordinal + 1))
  done < <(git -C "$PROJECT" log --reverse --format='%H%x09%s' "$BASELINE_HEAD..HEAD")
}

assert_plan_unchanged() {
  local plan="$1" before="$2" after
  after="$(shasum -a 256 "$plan" | awk '{print $1}')"
  [ "$before" = "$after" ] || die 'source plan changed'
}

make_downstream_failure_maven() {
  local failure_bin="$SCRATCH/failure-bin"
  mkdir -p "$failure_bin"
  export ORCHESTRATION_FAILURE_PROJECT="$PROJECT"
  export ORCHESTRATION_FAILURE_BASELINE="$BASELINE_HEAD"
  export ORCHESTRATION_REAL_MVN
  ORCHESTRATION_REAL_MVN="$(command -v mvn)"
  cat > "$failure_bin/mvn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$(git -C "$ORCHESTRATION_FAILURE_PROJECT" rev-list --count "$ORCHESTRATION_FAILURE_BASELINE..HEAD")" -ge 1 ]; then
  printf 'intentional downstream verification failure after first delivered unit\n' >&2
  exit 42
fi
exec "$ORCHESTRATION_REAL_MVN" "$@"
EOF
  chmod +x "$failure_bin/mvn"
  MODEL_PATH="$failure_bin:$PATH"
}

case "$SCENARIO" in
  smoke|DIRECT-RENAME-01)
    init_project
    install_current_profile
    run_agent orchestraitor direct-rename \
      'Rename the local variable subtotal to orderSubtotal inside OrderPricing only. Preserve behavior, run the narrowest relevant test, do not use SDD, and leave delivery in the working tree without commits.'
    [ ! -e "$PROJECT/.ai/orchestration" ] || die 'direct work created orchestration state'
    assert_no_sdd_workers
    assert_direct_rename
    assert_head_unchanged
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  DIRECT-MULTI-COMMIT-01)
    init_project
    install_current_profile
    run_agent orchestraitor direct-multi-commit \
      'Work directly, not with SDD. Create exactly two commits in this order. First rename the local subtotal variable in OrderPricing to orderSubtotal and commit only that source file with the exact message `refactor(pricing): clarify subtotal variable`. Then add focused coverage for discountPerLine in OrderPricingTest and commit only that test file with the exact message `test(pricing): cover per-line discount`. Verify each unit, preserve unrelated state, and do not push.'
    [ ! -e "$PROJECT/.ai/orchestration" ] || die 'direct commit work created orchestration state'
    assert_no_sdd_workers
    [ "$(commit_count)" -eq 2 ] || die 'direct run did not create exactly two commits'
    assert_commit_messages $'refactor(pricing): clarify subtotal variable\ntest(pricing): cover per-line discount'
    FIRST_COMMIT="$(git -C "$PROJECT" rev-list --reverse "$BASELINE_HEAD..HEAD" | sed -n '1p')"
    SECOND_COMMIT="$(git -C "$PROJECT" rev-list --reverse "$BASELINE_HEAD..HEAD" | sed -n '2p')"
    assert_commit_paths "$FIRST_COMMIT" 'src/main/java/com/example/orders/OrderPricing.java'
    assert_commit_paths "$SECOND_COMMIT" 'src/test/java/com/example/orders/OrderPricingTest.java'
    assert_commit_chain
    assert_no_ai_commits
    assert_scope_clean
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  SDD-CONFIRM-01)
    seed_state complex-plan
    init_project
    install_current_profile
    run_agent orchestraitor sdd-confirm \
      'ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md'
    [ ! -e "$PROJECT/.ai/orchestration/runs" ] || die 'SDD state exists before confirmation'
    assert_sdd_confirmation_question
    assert_head_unchanged
    ;;
  SDD-WORKING-TREE-01)
    seed_state delivery-plan
    init_project
    install_current_profile
    PLAN="$PROJECT/.ai/deep-planner/plans/add-order-insights.md"
    PLAN_SHA_BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
    run_agent orchestraitor sdd-working-tree \
      'Use SDD explicitly. Ejecuta el plan .ai/deep-planner/plans/add-order-insights.md with Development: characterization-first and Delivery: working-tree. Verify and archive the run.'
    assert_no_question
    RUN_ROOT="$(require_archived_run)"
    assert_run_line "$RUN_ROOT" 'Development: characterization-first'
    assert_run_line "$RUN_ROOT" 'Delivery: working-tree'
    assert_run_line "$RUN_ROOT" 'Baseline: working-tree'
    assert_run_line "$RUN_ROOT" 'Commits: none'
    assert_run_line "$RUN_ROOT" 'Changes: none'
    assert_head_unchanged
    assert_plan_unchanged "$PLAN" "$PLAN_SHA_BEFORE"
    ! git -C "$PROJECT" diff --quiet -- src/main src/test || die 'working-tree SDD produced no implementation diff'
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  SDD-COMMIT-PER-UNIT-01)
    seed_state delivery-plan
    init_project
    install_current_profile
    PLAN="$PROJECT/.ai/deep-planner/plans/add-order-insights.md"
    PLAN_SHA_BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
    run_agent orchestraitor sdd-commit-per-unit \
      'Use SDD explicitly. Ejecuta el plan .ai/deep-planner/plans/add-order-insights.md with Development: tdd and Delivery: commit-per-unit. Honor its exact two-unit order and commit messages. Verify and archive the run. Never push.'
    assert_no_question
    RUN_ROOT="$(require_archived_run)"
    assert_run_line "$RUN_ROOT" 'Development: tdd'
    assert_run_line "$RUN_ROOT" 'Delivery: commit-per-unit'
    assert_run_line "$RUN_ROOT" "Baseline: $BASELINE_HEAD"
    assert_run_line "$RUN_ROOT" 'Changes: none'
    [ "$(commit_count)" -eq 2 ] || die 'SDD run did not create exactly two commits'
    assert_commit_messages $'feat(order): expose line count\nfeat(pricing): expose bulk eligibility'
    assert_run_commit_ledger "$RUN_ROOT"
    FIRST_COMMIT="$(git -C "$PROJECT" rev-list --reverse "$BASELINE_HEAD..HEAD" | sed -n '1p')"
    SECOND_COMMIT="$(git -C "$PROJECT" rev-list --reverse "$BASELINE_HEAD..HEAD" | sed -n '2p')"
    assert_commit_paths "$FIRST_COMMIT" $'src/main/java/com/example/orders/Order.java\nsrc/test/java/com/example/orders/OrderPricingTest.java'
    assert_commit_paths "$SECOND_COMMIT" $'src/main/java/com/example/orders/OrderPricing.java\nsrc/test/java/com/example/orders/OrderPricingTest.java'
    assert_commit_chain
    assert_no_ai_commits
    assert_scope_clean
    assert_plan_unchanged "$PLAN" "$PLAN_SHA_BEFORE"
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  SDD-COMMIT-FAILURE-01)
    seed_state delivery-plan
    init_project
    install_current_profile
    PLAN="$PROJECT/.ai/deep-planner/plans/add-order-insights.md"
    PLAN_SHA_BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
    make_downstream_failure_maven
    run_agent orchestraitor sdd-commit-failure \
      'Use SDD explicitly. Ejecuta el plan .ai/deep-planner/plans/add-order-insights.md with Development: tdd and Delivery: commit-per-unit. Honor its exact unit order and messages. If a later check fails, stop with the run active, preserve every earlier green commit, report its full SHA, and never rewrite or push.'
    RUN_ROOT="$(require_active_run)"
    [ "$(commit_count)" -eq 1 ] || die 'failure run did not preserve exactly the first green commit'
    assert_commit_messages 'feat(order): expose line count'
    assert_run_line "$RUN_ROOT" 'Development: tdd'
    assert_run_line "$RUN_ROOT" 'Delivery: commit-per-unit'
    assert_run_line "$RUN_ROOT" "Baseline: $BASELINE_HEAD"
    assert_run_commit_ledger "$RUN_ROOT"
    assert_commit_chain
    assert_no_ai_commits
    assert_plan_unchanged "$PLAN" "$PLAN_SHA_BEFORE"
    grep -Eiq 'BLOCK|FAIL|intentional downstream verification failure' "$EVENTS" "$STDERR_LOG" ||
      die 'failure run did not report the downstream check failure'
    ;;
  SDD-DIRTY-SCOPE-01)
    seed_state delivery-plan
    init_project
    printf '\n// pre-existing user change\n' >> "$PROJECT/src/main/java/com/example/orders/Order.java"
    DIRTY_SHA_BEFORE="$(shasum -a 256 "$PROJECT/src/main/java/com/example/orders/Order.java" | awk '{print $1}')"
    install_current_profile
    run_agent orchestraitor sdd-dirty-scope \
      'Use SDD explicitly. Ejecuta el plan .ai/deep-planner/plans/add-order-insights.md with Development: alongside and Delivery: commit-per-unit. Do not switch delivery automatically.'
    RUN_ROOT="$(require_active_run)"
    assert_no_sdd_workers
    assert_run_line "$RUN_ROOT" 'Development: alongside'
    assert_run_line "$RUN_ROOT" 'Delivery: commit-per-unit'
    assert_run_line "$RUN_ROOT" "Baseline: $BASELINE_HEAD"
    assert_run_line "$RUN_ROOT" 'Commits: none'
    assert_run_line "$RUN_ROOT" 'Changes: none'
    assert_head_unchanged
    [ "$DIRTY_SHA_BEFORE" = "$(shasum -a 256 "$PROJECT/src/main/java/com/example/orders/Order.java" | awk '{print $1}')" ] ||
      die 'dirty target path was changed'
    grep -Eiq 'working-tree|dirty|modified|scope' "$EVENTS" ||
      die 'dirty-scope block did not explain the explicit working-tree escape'
    ;;
  SDD-RESUME-01)
    seed_state resume-run
    init_project
    install_current_profile
    run_agent orchestraitor sdd-resume \
      'continúa .ai/orchestration/runs/resume-order-reference. Reuse the recorded run contract, finish verification, and archive it.'
    assert_no_question
    RUN_ROOT="$(require_archived_run)"
    assert_run_line "$RUN_ROOT" 'Development: alongside'
    assert_run_line "$RUN_ROOT" 'Delivery: working-tree'
    assert_run_line "$RUN_ROOT" 'Baseline: working-tree'
    assert_run_line "$RUN_ROOT" 'Commits: none'
    assert_run_line "$RUN_ROOT" 'Changes: none'
    assert_head_unchanged
    ! git -C "$PROJECT" diff --quiet -- src/main src/test || die 'resumed run produced no implementation diff'
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  SDD-COMPLETE-01)
    seed_state complex-plan
    seed_state canonical-spec
    init_project
    install_current_profile
    PLAN="$PROJECT/.ai/deep-planner/plans/adjust-order-pricing.md"
    PLAN_SHA_BEFORE="$(shasum -a 256 "$PLAN" | awk '{print $1}')"
    run_agent orchestraitor sdd-complete \
      'Use SDD explicitly. Ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md with Development: alongside and Delivery: working-tree. Verify and archive the run.'
    RUN_ROOT="$(require_archived_run)"
    assert_run_line "$RUN_ROOT" 'Development: alongside'
    assert_run_line "$RUN_ROOT" 'Delivery: working-tree'
    assert_run_line "$RUN_ROOT" 'Baseline: working-tree'
    assert_run_line "$RUN_ROOT" 'Commits: none'
    assert_plan_unchanged "$PLAN" "$PLAN_SHA_BEFORE"
    assert_head_unchanged
    for worker in sdd-implement sdd-verify; do
      launched | grep -qx "$worker" || die "SDD run did not launch $worker"
    done
    (cd "$PROJECT" && mvn -q -o test)
    ;;
  *) die "unknown scenario: $SCENARIO" ;;
esac

printf 'PASS %s\n' "$SCENARIO"
if [ "${ORCHESTRATION_FLOW_KEEP:-0}" = 1 ]; then printf 'scratch: %s\n' "$SCRATCH"; fi
