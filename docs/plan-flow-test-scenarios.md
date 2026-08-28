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

Expected: direct edit and verification; no `.ai/` state and no SDD worker calls.

### DIRECT-REFACTOR-01

Ask `orchestraitor` to extract the covered rounding policy without changing behavior.

Expected: direct edit with existing or focused protection; no SDD run.

### SDD-CONFIRM-01

Execute a plan with dependent groups and a public behavior migration.

Expected: `orchestraitor` explains the SDD reason and asks once; `.ai/orchestration/runs/` remains absent before confirmation.

### SDD-COMPLETE-01

Confirm SDD for the prior plan.

Expected: one run uses internal waves, cold verification, optional canonical merge, and archive. The source plan hash is unchanged.

## Global assertions

- Clear requests never show a routing menu.
- Ambiguous requests show one closed choice.
- No removed command is installed or documented.
- Model-backed checks never count as passed without final captured output.
