# Orchestration Domain

`orchestraitor` is the single primary agent. It plans, executes Direct or SDD, and loads review or architecture skills. By default it gives a verified, uncommitted diff.

## Quick path

1. Select `orchestraitor` and request a change or an exact plan.
2. For commits or TCR, ask directly or use the `Delivery:` line of the plan.
3. Approve each new SDD contract. Inspect the verification and any commits.

## Entry points

| Request | Route | Result |
|---|---|---|
| Planning request | `oc-plan-light` or `oc-plan-deep` | Plan only |
| Review or architecture request | `oc-review` or `oc-arch` | Skill result, no delivery |
| Clear localized change | Direct | Verified working-tree change |
| Explicit commits | Direct or SDD | Cohesive verified commits |
| Explicit TCR | Direct only | Commit on green tests; revert on red |
| Explicit SDD request | Contract approval | Contract before implementation |
| `ejecuta el plan <path>` | Plan execution | No new approval |
| `continúa <run>` | Resume | No reconfirmation |

- Direct does localized, reversible work without `.ai/` state or workers. TCR needs safe Direct work; otherwise use SDD `commit-per-unit` or reduce the scope.
- SDD is for dependencies, public contracts, migrations, high risk, resume, or parallel work. Workers are `general` subagents that load an `oc-sdd-*` skill.
- A generated contract (Intent, Scope, WHEN/THEN scenarios, Approach, Done means) needs explicit approval. Silence is not approval. Before approval, do not create runs, edit, stage, or commit.
- An explicit text reply also counts as approval. A revised draft needs a new approval. After an interruption, present the unapproved draft again. Direct → SDD needs one approval for the contract and the route.
- An exact existing plan skips approval but keeps structural and checksum checks.
- Delivery precedence: the current instruction, then the plan `Delivery:` value, then `working-tree`. Invalid or conflicting values stop the work before editing. Delivery does not change after editing starts.
- Workers never stage, commit, roll back, or push. Only `orchestraitor` stages, commits, or pushes. It keeps unrelated changes, excludes `.ai/`, and runs hooks.
- Runs are at `.ai/orchestration/runs/<slug>/run.md` with `Approval: explicit | plan-execution` and `Approval evidence:`. Resume never asks again. `commit-per-unit` verifies `<Baseline>..HEAD`. `oc-sdd` owns the full resume, checksum, and archive rules.
- In `working-tree` runs, independent ready units can run in parallel. Verification checks the scoped working-tree diff.
- Push, pull requests, merge, and review are separate from delivery. Ask for a review to load `oc-review`.

Details: [oc-sdd](skills/oc-sdd/SKILL.md), [oc-commits](skills/oc-commits/SKILL.md), [tcr](skills/oc-tcr/SKILL.md).

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `orchestraitor` (primary agent) | Routes, executes, and owns Git delivery |
| `oc-sdd` | Coordinates approved durable SDD runs |
| `oc-sdd-explore` | Explores code read-only |
| `oc-sdd-implement` | Implements scoped units, no Git |
| `oc-sdd-merge` | Merges verified canonical spec deltas |
| `oc-conventions` | Applies code and test conventions |
| `oc-doc-design` | Keeps documentation clear |
| `oc-routing` | Selects implementation skills, no delivery |
| `oc-java-test` | Implements focused Java tests |
| `oc-legacy` | Protects legacy behavior |
| `oc-sdd-verify` | Verifies `working-tree` or commit range |
| `oc-debug` | Finds root causes before fixes |
| `oc-tcr` | Commits green, reverts red microsteps |
| `oc-commits` | Delivers verified units as commits |
| `oc-plan-light` | Quick IDSD plan for localized work |
| `oc-plan-deep` | Evidence-first deep plans and discoveries |
| `oc-refactor-lens` | Behavior-preserving refactor analysis |
| `oc-review` | Coordinates review, judgment, and defend |
| `oc-judge` | Independent judge lenses a, b, solo |
| `oc-judge-fix` | Applies accepted judgment fixes |
| `oc-arch` | Architecture map, review, ideate, boundary |
