# SDD Domain

Full spec-driven implementation around one human-readable `change.md`. `orchestraitor` owns adoption, execution, verification, canonical specs, and archive.

## Quick path

1. Request full implementation, resume, or execution of a ready change.
2. Confirm unresolved Mode, TDD, Judgment, and Delivery choices.
3. Review verification evidence and the archived change.

## Entry points

| Entry | Operation | Result |
|---|---|---|
| Direct implementation request | `direct-sdd` | Planned and executed change |
| Ready producer `change.md` | `execute-handoff` | Exact-path adoption and execution |
| Existing active state | `resume` | Artifact-driven continuation |
| `/judgment` | Adversarial review | Findings and bounded fixes |

Direct work lives at `.ai/orchestrator/changes/<change>/`. Producer handoffs remain at `.ai/<producer>/changes/<change>/`; SDD preserves their marker and adds `state.md`. Canonical behavior lives under `.ai/orchestrator/specs/`. Ambiguous active changes require an exact path.

| Choice | Values |
|---|---|
| Mode | `interactive` or `automatic` |
| TDD | `first`, `alongside`, or `off` |
| Judgment | `none`, `light`, or `full` |
| Delivery | `none` or `commit-per-wave` |

Work groups declare `Files:` and up to three routed `Skills:`. Disjoint scopes may run in parallel; overlapping scopes run sequentially. Workers never stage, commit, or push. With `commit-per-wave`, only `orchestraitor` commits verified work and it never pushes. See [SDD flow verification](../../docs/sdd-test-plan.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `orchestraitor` | Coordinates full SDD execution |
| Agent (subagent) | `sdd-explore` | Explores code read-only |
| Agent (subagent) | `sdd-implement` | Implements one scoped work wave |
| Agent (subagent) | `sdd-canonical-merge` | Merges verified canonical spec deltas |
| Agent (subagent) | `sdd-verify` | Cold-checks behavior and commands |
| Agent (subagent) | `jd-judge-a` | Reviews correctness independently |
| Agent (subagent) | `jd-judge-b` | Reviews security independently |
| Agent (subagent) | `jd-solo` | Runs lightweight adversarial review |
| Agent (subagent) | `jd-fix` | Applies confirmed review findings |
| Command | `/judgment` | Routes adversarial review |
| Skill | `behavior-characterization` | Captures current behavior during hardening |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `cognitive-doc-design` | Keeps human-facing documentation clear |
| Skill | `graphify-cli` | Queries code graphs read-only |
| Skill | `java-testing` | Implements focused Java tests |
| Skill | `legacy-code-safety` | Protects behavior during legacy changes |
| Skill | `native-question-ux` | Presents questions through portable native UX |
| Skill | `sdd-cold-verification` | Verifies scoped scenarios independently |
| Skill | `sdd-draft-change` | Drafts one pre-implementation change document |
| Skill | `sdd-execution-skills` | Selects skills for implementation work |
| Skill | `systematic-debugging` | Finds root causes before fixes |
| Skill | `work-unit-commits` | Plans reviewable and cohesive commits |
