# Plan and Orchestration Flow Scenarios

Use these prompts for model-backed checks only after explicit authorization. Deterministic scripts validate the same structural contracts without model credits.

## Quick path

1. Copy `scripts/fixtures/orchestration-agent-routes/java-orders/` to a scratch project.
2. Install the multi-primary profile.
3. Run one scenario and inspect tracked files plus hidden `.ai/` state.

## Scenarios

### ROUTE-CLEAR-01

Ask `deep-planner` to plan a public `lineCount()` method and focused coverage.

Expected: no menu; one `.ai/deep-planner/plans/<slug>.md` with every required execution-plan section.

### ROUTE-AMBIGUOUS-01

Tell `deep-planner`: `Help me improve order pricing.`

Expected: one closed choice with `Create a plan` and `Explore an idea`; no artifact before the choice.

### WAYFINDER-01

Ask `deep-planner` to explore multi-currency pricing while currencies, rates, and rounding ownership remain open.

Expected: one `.ai/deep-planner/discoveries/<slug>.md`; no plan, status marker, production edit, roadmap, or change file.

### DISCOVERY-TO-PLAN-01

Resolve the open Wayfinder decisions, then ask to convert the exact discovery into a plan.

Expected: the discovery remains; one new plan contains its resolved evidence and decisions.

### LARGE-PLAN-01

Plan coupons, validation, reporting, and test migration as dependent work.

Expected: one plan with ordered work groups and dependencies; no roadmap or slice files.

### DIRECT-RENAME-01

Ask `orchestraitor` to rename one local variable and run the narrowest check.

Expected: direct edit and verification; baseline `HEAD` is unchanged, with no `.ai/` state or SDD worker calls.

### DIRECT-MULTI-COMMIT-01

Ask `orchestraitor` for exactly two Direct commits with an explicit order, file scope, and message for each.

Expected: two green commits in the requested order and with the exact messages. Each contains only its requested path, the chain begins at the fixture baseline, `.ai/` is absent, and no push or SDD worker occurs.

### DIRECT-REFACTOR-01

Ask `orchestraitor` to extract the covered rounding policy without changing behavior.

Expected: direct edit with existing or focused protection; no SDD run.

### SDD-CONFIRM-01

Execute a plan with dependent groups and a public behavior migration.

Expected: `orchestraitor` explains the SDD reason and asks once; `.ai/orchestration/runs/` remains absent before confirmation.

### SDD-WORKING-TREE-01

Execute the two-unit delivery plan with `Development: characterization-first` and `Delivery: working-tree`.

Expected: one archived run records `Baseline: working-tree`, `Commits: none`, and `Changes: none`; implementation remains uncommitted, the source plan hash is unchanged, and all tests pass.

### SDD-COMMIT-PER-UNIT-01

Execute the same plan with `Development: tdd` and `Delivery: commit-per-unit`.

Expected: two ordered commits use the plan's exact messages. `Baseline` is the original full `HEAD`; every `Commits:` row contains `unit-NN`, full SHA, and message; committed paths match their unit, form a continuous chain, stay clean, and exclude `.ai/`. The plan hash remains unchanged.

### SDD-COMMIT-FAILURE-01

Execute `SDD-COMMIT-PER-UNIT-01` with the harness Maven shim that starts failing after the first delivered unit.

Expected: the first green commit and its full-SHA ledger row remain unchanged; the second unit is not committed, the run stays active, no history is rewritten, and the downstream failure is reported.

### SDD-DIRTY-SCOPE-01

Modify a target source path before requesting `Delivery: commit-per-unit`.

Expected: the run records the chosen values and full baseline, then blocks before any worker or implementation edit. The dirty path and `HEAD` remain unchanged, `Commits: none` remains, and only an explicit switch to `working-tree` can continue.

### SDD-RESUME-01

Resume an active planless run that already records `Development: alongside` and `Delivery: working-tree`.

Expected: no question event repeats either value. The implementation verifies and archives while preserving the five control values and leaving `HEAD` unchanged.

### SDD-COMPLETE-01

Confirm SDD for the prior plan.

Expected: one run uses internal waves, cold verification, optional canonical merge, and archive. The source plan hash is unchanged.

## Development modes

| Mode | Required evidence |
|---|---|
| `tdd` | The focused test fails because the requested behavior is absent before production is edited. |
| `characterization-first` | Protection for current behavior runs before that behavior changes. |
| `alongside` | Tests and implementation may be written in either order; the final scoped check still passes. |
| `not-applicable` | `run.md` records a reason and exact alternative verification; no test order is invented. |

## Global assertions

- Clear requests never show a routing menu.
- Ambiguous requests show one closed choice.
- SDD asks once for only unresolved development or delivery values and recommends `alongside` plus `working-tree`.
- Resume reuses durable values without another question.
- Workers never stage, commit, push, or load `work-unit-commits`.
- No removed command is installed or documented.
- Model-backed checks never count as passed without final captured output.
