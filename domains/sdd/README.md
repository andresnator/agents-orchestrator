# SDD Domain

Full spec-driven implementation around one human-readable `change.md`. `orchestraitor` owns adoption, execution, verification, canonical specs, and archive.

## Quick path

1. Install `sdd` for Judgment none, or `sdd,review` for Judgment light/full.
2. Select `orchestraitor` or run `/sdd`, then confirm unresolved choices.
3. Review verification evidence and the archived change.

## Entry points

| Entry | Operation | Result |
|---|---|---|
| `/sdd <request>` | `direct-sdd` | Planned and executed change |
| Ready producer `change.md` | `execute-handoff` | Exact-path adoption and execution |
| Existing active state | `resume` | Artifact-driven continuation |

Direct work lives at `.ai/orchestrator/changes/<change>/`. Producer handoffs remain at `.ai/<producer>/changes/<change>/`; SDD preserves their marker and adds `state.md`. Canonical behavior lives under `.ai/orchestrator/specs/`. Ambiguous active changes require an exact path.

| Choice | Values |
|---|---|
| Mode | `interactive` or `automatic` |
| TDD | `first`, `alongside`, or `off` |
| Judgment | `none`, `light`, or `full` |
| Delivery | `none` or `commit-per-wave` |

Standalone `--domain sdd` supports `Judgment: none`. Light and full Judgment require an explicit `--domain sdd,review` install so SDD can hand the exact scope to `review-coordinator` through `/judgment` and resume the active root afterward.

Work groups declare `Files:` and up to three routed `Skills:`. Disjoint scopes may run in parallel; overlapping scopes run sequentially. Workers never stage, commit, or push. With `commit-per-wave`, only `orchestraitor` commits verified work and it never pushes. See [SDD flow verification](../../docs/sdd-test-plan.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `orchestraitor` | Coordinates full SDD execution directly |
| Agent (subagent) | `sdd-explore` | Explores code read-only |
| Agent (subagent) | `sdd-implement` | Implements one scoped work wave |
| Agent (subagent) | `sdd-canonical-merge` | Merges verified canonical spec deltas |
| Agent (subagent) | `sdd-verify` | Cold-checks behavior and commands |
| Command | `/sdd` | Starts or resumes full SDD |
| Skill | `behavior-characterization` | Captures current behavior during hardening |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `cognitive-doc-design` | Keeps human-facing documentation clear |
| Skill | `graphify-cli` | Queries code graphs read-only |
| Skill | `java-testing` | Implements focused Java tests |
| Skill | `legacy-code-safety` | Protects behavior during legacy changes |
| Skill | `sdd-cold-verification` | Verifies scoped scenarios independently |
| Skill | `sdd-draft-change` | Drafts one pre-implementation change document |
| Skill | `sdd-execution-skills` | Selects skills for implementation work |
| Skill | `systematic-debugging` | Finds root causes before fixes |
| Skill | `work-unit-commits` | Plans reviewable and cohesive commits |
