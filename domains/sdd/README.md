# SDD Domain

Full spec-driven implementation around one human-readable pre-implementation file: `change.md`. `orchestraitor` owns planning or handoff adoption, integration, verification, optional judgment, canonical specs, and archive.

## Quick path

1. Start a direct SDD request or ask to execute a ready planner change.
2. Confirm missing execution choices: Mode, TDD, Judgment, and Delivery.
3. Follow progress in the `change.md` work checkboxes and `state.md`.
4. Review verification evidence and the archived change.

## Change contract

Direct work lives at `.ai/orchestrator/changes/<change>/change.md`. Planner handoffs stay at `.ai/<producer>/changes/<change>/change.md` and begin with `Status: ready-for-sdd`; SDD adopts that exact file, preserves its producer marker, and adds active execution in `state.md`. Legacy proposal/design/spec/task bundles are not auto-migrated.

The shared `sdd-draft-change` skill defines outcome, scope, behavior deltas, approach, work groups, verification, and non-empty risks. Work groups use optional `Files:` scopes and required `Skills:` names. Disjoint scopes may run in parallel; unclear overlap runs sequentially. SDD resolves names through the generated registry or runtime catalog, then enforces the worker allowlist.

A roadmap slice adds `Roadmap: <goal> | Slice: <n>/<total>` on line two. SDD preserves that marker, moves its row from `planned` to `adopted` at intake and to `done` at archive, then offers but never auto-plans the next unblocked slice.

## Flow

```text
route -> explore if needed -> write/adopt change.md -> implement waves -> cold verify
      -> optional judgment/fix -> merge canonical specs -> archive
```

Workers never stage, commit, or push. With `Delivery: commit-per-wave`, only `orchestraitor` owns the Git index and commits verified work; it never pushes. User questions return to `sdlc-orchestrator` as compact `ASK` lines.

Canonical behavior remains under `.ai/orchestrator/specs/`. Resume is artifact-driven from the exact active root and `state.md`; ambiguous active changes require the user to choose.

## Execution choices

| Choice | Values |
|---|---|
| Mode | `interactive` or `automatic` |
| TDD | `first`, `alongside`, or `off` |
| Judgment | `none`, `light`, or `full` |
| Delivery | `none` or `commit-per-wave` |

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `orchestraitor` | Coordinates direct SDD, handoffs, resume, and archive |
| Agent (subagent) | `sdd-explore` | Explores code read-only |
| Agent (subagent) | `sdd-implement` | Implements a work wave or merges canonical specs |
| Agent (subagent) | `sdd-verify` | Cold-checks behavior and commands |
| Agent (subagent) | `jd-judge-a` | Reviews correctness independently |
| Agent (subagent) | `jd-judge-b` | Reviews security independently |
| Agent (subagent) | `jd-solo` | Runs the light review path |
| Agent (subagent) | `jd-fix` | Applies confirmed findings |
| Command | `/judgment` | Routes adversarial review |
| Skill | `behavior-characterization` | Captures current behavior during hardening |
| Skill | `code-conventions` | Applies repository code and test conventions |
| Skill | `graphify-cli` | Queries code graphs read-only |
| Skill | `java-testing` | Implements Java tests and characterization seams |
| Skill | `legacy-code-safety` | Protects behavior during legacy changes |
| Skill | `native-question-ux` | Presents questions through portable native UX |
| Skill | `sdd-cold-verification` | Verifies scoped scenarios independently |
| Skill | `sdd-draft-change` | Drafts the single pre-implementation change document |
| Skill | `systematic-debugging` | Applies evidence-first debugging to fix waves |
| Skill | `work-unit-commits` | Plans reviewable, cohesive commits |

Static and opt-in model checks are summarized in [docs/sdd-test-plan.md](../../docs/sdd-test-plan.md).
