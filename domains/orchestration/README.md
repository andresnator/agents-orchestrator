# Orchestration Domain

`orchestraitor` is the single primary agent: it plans, executes changes directly or through durable SDD runs, and loads review or architecture skills on request. Git delivery is opt-in; the default is a verified, uncommitted diff.

## Quick path

1. Select `orchestraitor` and request a change or exact plan.
2. Request commits or TCR when wanted, directly or through the plan's `Delivery:` line.
3. Approve any newly generated SDD contract, then inspect fresh verification, optional commit SHAs, and any archived run.

## Entry points

| Request | Route | Result |
|---|---|---|
| Planning request | `oc-plan-light` or `oc-plan-deep` | Plan only, no implementation |
| Review or architecture request | `oc-review` or `oc-arch` | Skill result, never delivery |
| Clear localized change | Direct | Verified working-tree change by default |
| Explicit commits | Direct or SDD | Cohesive commits after focused checks pass |
| Explicit TCR | Direct only | Commit green microsteps; revert attributable red changes |
| Explicit SDD request | Contract approval | Present the generated contract before implementation |
| `ejecuta el plan <path>` | Plan execution | Direct or SDD without another approval |
| `continúa <run>` | Resume | Continue the approved run without reconfirmation |

Direct handles localized, reversible work without `.ai/` state or workers. SDD workers are `general` subagents briefed to load an `oc-sdd-*` skill. Use SDD for dependencies, public contracts, migrations, high risk, durable resume, parallel coordination, or canonical specs; generated contracts require approval before implementation.

Present Intent, Scope, all WHEN/THEN scenarios, Approach, and Done means with native Approve / Request adjustments / Cancel choices; an explicit response approving the presented contract also counts. Direct → SDD uses one informed approval for both contract and route. Adjustments require presenting and approving the revised draft; silence and initial SDD intent do not count. Before approval, only exploration and drafting in conversation are allowed, with no run creation, implementation workers, implementation edits, staging, or commits. On interruption, present the unapproved draft again.

Executing an exact existing plan skips this gate and content reapproval while retaining structural validation and checksum checks. TCR requires safe Direct work; otherwise choose `commit-per-unit` for SDD or reduce scope before editing.

### Delivery

Use the current explicit execution instruction, then the plan's optional `Delivery:` value, then `working-tree`. A valid plan value authorizes delivery without another confirmation. Duplicate lines, unknown values, or contradictions within either source block before editing; delivery cannot change after editing starts.

Only `orchestraitor` owns Git delivery. It preserves unrelated changes and staged entries, excludes `.ai/`, and runs hooks. Workers never stage, commit, roll back, or push. See [oc-commits](skills/oc-commits/SKILL.md) and [tcr](skills/oc-tcr/SKILL.md) for preflight, commit, and failure rules.

### SDD resume

Runs live at `.ai/orchestration/runs/<slug>/run.md` and retain the external plan path and SHA-256, or the complete generated contract including Scope and Approach. They record `Approval: explicit | plan-execution` and `Approval evidence:` with the actual authorizing response or instruction. Resume requires this evidence and never asks again; missing approval blocks as an incomplete contract without migration. Contractual sections remain immutable while execution state tracks progress and delivery. A required behavior, scope, or acceptance change stops implementation for communication.

In `commit-per-unit`, units run serially: save pending delivery before staging and hooks, then record each verified commit. Resume requires matching `HEAD` and saved Git state, including when the first hook fails. Cold verification checks exactly `<Baseline>..HEAD`; completion archives the run with no pending unit.

Working-tree SDD permits disjoint, dependency-ready units in parallel and verifies the scoped working-tree diff. See [oc-sdd](skills/oc-sdd/SKILL.md) for the approval gate, run controls, and execution rules.

Push, PRs, merge, Review, and Judgment remain separate from delivery; request a review explicitly to load `oc-review`. Validate changes with the [Orchestration manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `orchestraitor` | Routes, executes, and owns Git delivery |
| Skill | `oc-sdd` | Coordinates approved durable SDD runs |
| Skill | `oc-sdd-explore` | Explores code read-only |
| Skill | `oc-sdd-implement` | Implements scoped units without Git authority |
| Skill | `oc-sdd-merge` | Merges verified canonical spec deltas |
| Skill | `oc-conventions` | Applies code and test conventions |
| Skill | `oc-doc-design` | Keeps human-facing documentation clear |
| Skill | `oc-graphify` | Queries code graphs read-only |
| Skill | `oc-routing` | Selects implementation skills without delivery skills |
| Skill | `oc-java-test` | Implements focused Java tests |
| Skill | `oc-legacy` | Characterizes and protects legacy behavior |
| Skill | `oc-sdd-verify` | Verifies `working-tree` or the recorded commit range |
| Skill | `oc-debug` | Finds root causes before fixes |
| Skill | `oc-tcr` | Commits green microsteps; reverts attributable failures |
| Skill | `oc-commits` | Delivers cohesive verified units as commits |
| Skill | `oc-plan-light` | Quick IDSD plan for localized work |
| Skill | `oc-plan-deep` | Evidence-first deep plans and discoveries |
| Skill | `oc-refactor-lens` | Behavior-preserving refactor analysis |
| Skill | `oc-review` | Coordinates review, judgment, and defend |
| Skill | `oc-judge` | Independent judge lenses a, b, solo |
| Skill | `oc-judge-fix` | Applies accepted judgment fixes |
| Skill | `oc-arch` | Architecture map, review, ideate, boundary |
