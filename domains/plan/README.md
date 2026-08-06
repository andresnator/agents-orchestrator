# Plan Domain

`deep-planner` owns both normal delivery planning and protected planning for behavior-preserving refactors. It produces an executable `change.md`, a human decision plan, or a multi-session discovery map; SDD owns implementation.

## Quick path

1. Use natural language through `sdlc-orchestrator`, `/deep-plan`, `/refactor-plan`, or `/harden-plan`.
2. Answer only unresolved product or technical decisions.
3. For an executable goal, review `.ai/deep-planner/changes/<change>/change.md`, then request implementation.

## Outputs

| Need | Output | Next step |
|---|---|---|
| Bounded executable goal | `.ai/deep-planner/changes/<change>/change.md` | SDD executes it in place |
| Behavior-preserving refactor with a safety net | Same path shape | SDD executes the refactor |
| Refactor without a reliable safety net | One `harden-*` change at the same path | SDD hardens first; then plan the refactor again |
| Oversized executable goal | `.ai/roadmaps/<goal>.md` plus the first slice's `change.md` | Plan slices just in time with `"continúa el roadmap <goal>"` |
| Decision or investigation | `.ai/deep-planner/plans/<slug>.md` | Human review; no automatic SDD handoff |
| Foggy multi-session effort | `.ai/wayfinder/<map>/` | Resolve one decision ticket per session, then Deep Plan |

## One-document handoff

A ready change starts with `Status: ready-for-sdd | Source: deep-planner`. The file holds outcome, scope, behavior deltas, approach, ordered work, verification, and non-empty risks. The planner returns its exact path; `orchestraitor` adopts that path, adds execution state, and does not redraft or copy it.

Keep each change bounded. Split large goals into roadmap slices rather than companion proposal, design, spec, and task documents. Safe work groups may run in parallel only when their `Files:` scopes are disjoint.

## Planning depth

Normal delivery planning resolves intended behavior, implementation approach, work scopes, and end-to-end verification. Protected planning adds target scoping, risk classification, behavior-preservation scenarios, seams, characterization coverage, rollback, and relevant tooling baselines.

The modes share one coordinator because they have the same ownership and handoff contract. `refactor-analyzer` remains a specialized read-only worker for medium-or-higher protected plans. Hardening and restructuring are deliberately separate handoffs: characterization establishes the baseline before a later refactor plan relies on it.

The domain declares the shared `sdd-draft-change` contract directly. It assumes `common` for planning methods; SDD owns later execution.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `deep-planner` | Produces normal or protected executable plans and durable decision artifacts |
| Agent (subagent) | `refactor-analyzer` | Applies one read-only refactor or hardening lens |
| Command | `/deep-plan` | Routes executable and decision planning |
| Command | `/harden-plan` | Plans characterization and test safety before restructuring |
| Command | `/refactor-plan` | Plans behavior-preserving restructuring |
| Command | `/wayfinder` | Advances multi-session discovery maps |
| Skill | `architecture-impact-review` | Classifies local versus architectural risk |
| Skill | `behavior-characterization` | Records observable legacy behavior |
| Skill | `characterization-test-scoping` | Scopes tests, seams, containment, and rollback |
| Skill | `dependency-seam-detection` | Finds testability seams |
| Skill | `fable-planning` | Builds evidence-first plans and validates edge cases |
| Skill | `java-api-design` | Reviews Java API boundaries |
| Skill | `java-exception-robustness` | Reviews Java failure handling |
| Skill | `java-immutability-modeling` | Reviews safe Java data models |
| Skill | `java-naming-readability` | Reviews Java naming |
| Skill | `java-secure-coding` | Reviews Java security practices |
| Skill | `java-testing` | Designs Java test coverage |
| Skill | `legacy-code-safety` | Makes untested code safe to change |
| Skill | `null-safety` | Detects null hazards |
| Skill | `refactor` | Supplies cross-language refactoring techniques |
| Skill | `scope-analysis` | Delimits the target boundary |
| Skill | `sdd-draft-change` | Drafts the single pre-implementation change document |
| Skill | `tooling-audit` | Detects test-tooling gaps |
| Skill | `tooling-compatibility-matrix` | Selects compatible quality tooling |
| Skill | `type-contracts` | Detects weak type contracts |
| Skill | `wayfinder` | Maps unresolved decisions across sessions |
