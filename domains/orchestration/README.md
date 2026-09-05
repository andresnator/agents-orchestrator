# Orchestration Domain

`orchestraitor` executes local changes directly or coordinates durable SDD runs. Git delivery is opt-in; the default is a verified, uncommitted diff.

## Quick path

1. Select `orchestraitor` and request a change or exact plan.
2. Request commits or TCR when wanted, directly or through the plan's `Delivery:` line.
3. Inspect fresh verification, optional commit SHAs, and any archived run.

## Entry points

| Request | Route | Result |
|---|---|---|
| Clear localized change | Direct | Verified working-tree change by default |
| Explicit commits | Direct or SDD | Cohesive commits after focused checks pass |
| Explicit TCR | Direct only | Commit green microsteps; revert attributable red changes |
| `ejecuta el plan <path>` | Plan execution | Direct work or confirmed SDD |
| `continúa <run>` | Resume | Continue the exact recorded SDD run |

Direct handles localized, reversible work without `.ai/` state or workers. Use SDD for dependencies, public contracts, migrations, high risk, durable resume, parallel coordination, or canonical specs; it requires explicit intent or confirmation. TCR requires safe Direct work; otherwise choose `commit-per-unit` for SDD or reduce scope before editing.

### Delivery

Use the current explicit execution instruction, then the plan's optional `Delivery:` value, then `working-tree`. A valid plan value authorizes delivery without another confirmation. Duplicate lines, unknown values, or contradictions within either source block before editing; delivery cannot change after editing starts.

Only `orchestraitor` owns Git delivery. It preserves unrelated changes and staged entries, excludes `.ai/`, and runs hooks. Workers never stage, commit, roll back, or push. See [work-unit-commits](skills/work-unit-commits/SKILL.md) and [tcr](skills/tcr/SKILL.md) for preflight, commit, and failure rules.

### SDD resume

Runs live at `.ai/orchestration/runs/<slug>/run.md` and retain the plan path and checksum. In `commit-per-unit`, units run serially: save pending delivery before staging and hooks, then record each verified commit. Resume requires matching `HEAD` and saved Git state, including when the first hook fails. Cold verification checks exactly `<Baseline>..HEAD`; completion archives the run with no pending unit.

Working-tree SDD permits disjoint, dependency-ready units in parallel and verifies the scoped working-tree diff. See [orchestraitor](agents/orchestraitor.md) for the run controls.

Push, PRs, merge, Review, and Judgment remain separate workflows. For later evaluation, select `review-coordinator`. Validate changes with the [Orchestration manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `orchestraitor` | Executes changes and opt-in Git delivery |
| Agent (subagent) | `sdd-explore` | Explores code read-only |
| Agent (subagent) | `sdd-implement` | Implements scoped units without Git authority |
| Agent (subagent) | `sdd-canonical-merge` | Merges verified canonical spec deltas |
| Agent (subagent) | `sdd-verify` | Cold-checks behavior and commands |
| Skill | `behavior-characterization` | Captures current behavior during hardening |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `cognitive-doc-design` | Keeps human-facing documentation clear |
| Skill | `graphify-cli` | Queries code graphs read-only |
| Skill | `implementation-skill-routing` | Selects implementation skills without delivery skills |
| Skill | `java-testing` | Implements focused Java tests |
| Skill | `legacy-code-safety` | Protects behavior during legacy changes |
| Skill | `sdd-cold-verification` | Verifies `working-tree` or the recorded commit range |
| Skill | `systematic-debugging` | Finds root causes before fixes |
| Skill | `tcr` | Commits green microsteps; reverts attributable failures |
| Skill | `work-unit-commits` | Delivers cohesive verified units as commits |
