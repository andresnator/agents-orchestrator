# Plan Domain

`deep-planner` turns repository evidence into a durable plan or one executable `change.md`. SDD owns implementation.

## Quick path

1. Select `deep-planner` or run a planning command.
2. Answer only unresolved product, acceptance, or risk questions.
3. Review the returned plan, roadmap slice, or ready `change.md`.

## Entry points

| Entry | Internal route | Result |
|---|---|---|
| `/deep-plan` | `deep-plan`, `intent=auto` | Ready change, final plan, or roadmap slice |
| `/wayfinder` | `deep-plan`, `intent=discovery` | One durable discovery plan |
| `/refactor-plan` | `refactor`, `intent=auto` | Safe refactor or prerequisite hardening |
| `/harden-plan` | `refactor`, `intent=hardening` | Hardening-only ready change |

`/wayfinder` and `/harden-plan` are compatibility aliases; machine returns use only `plan/deep-plan` or `plan/refactor`. Bounded work writes `.ai/deep-planner/changes/<change>/change.md`; decisions and discovery use `.ai/deep-planner/plans/<slug>.md`; oversized work adds `.ai/roadmaps/<goal>.md` and plans one unblocked slice at a time.

A ready change begins with `Status: ready-for-sdd | Source: deep-planner`. Roadmap slices add `Roadmap: <goal> | Slice: <n>/<total>`. Each Work group records `Files:` and at most three `Skills:` selected through `sdd-execution-skills`. The planner never edits production files; SDD executes the exact handoff path. Continue an existing roadmap with the literal trigger `"continúa el roadmap <goal>"`.

Copy-ready prompts and expected evidence remain in [Plan flow test scenarios](../../docs/plan-flow-test-scenarios.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `deep-planner` | Produces plans and ready changes directly |
| Agent (subagent) | `refactor-analyzer` | Applies one read-only analysis lens |
| Command | `/deep-plan` | Routes normal planning work |
| Command alias | `/wayfinder` | Routes durable discovery planning |
| Command | `/refactor-plan` | Routes protected refactor planning |
| Command alias | `/harden-plan` | Forces hardening-only planning |
| Skill | `architecture-impact-review` | Classifies local versus architectural risk |
| Skill | `behavior-characterization` | Records observable legacy behavior |
| Skill | `characterization-test-scoping` | Scopes tests, seams, and rollback |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `cohesion-coupling` | Detects cohesion and coupling problems |
| Skill | `complexity-big-o` | Evaluates algorithmic and control complexity |
| Skill | `dependency-inversion` | Detects concrete dependency boundary risks |
| Skill | `dependency-seam-detection` | Finds safe testability seams |
| Skill | `design-patterns-pragmatic` | Applies patterns to evidenced forces |
| Skill | `domain-modeling` | Builds and sharpens domain models |
| Skill | `dry-business-knowledge` | Distinguishes knowledge duplication from similarity |
| Skill | `evidence-first-planning` | Builds evidence-first executable plans |
| Skill | `general-naming-readability` | Improves language-neutral naming and readability |
| Skill | `god-object-detection` | Detects oversized multi-responsibility objects |
| Skill | `graphify-cli` | Queries code graphs read-only |
| Skill | `grilling` | Stress-tests plans through focused interviews |
| Skill | `input-validation-preconditions` | Detects missing or duplicated preconditions |
| Skill | `java-api-design` | Reviews Java API boundaries |
| Skill | `java-exception-robustness` | Reviews Java failure handling |
| Skill | `java-immutability-modeling` | Reviews safe Java data models |
| Skill | `java-naming-readability` | Reviews Java naming and readability |
| Skill | `java-secure-coding` | Reviews Java security practices |
| Skill | `java-testing` | Designs focused Java test coverage |
| Skill | `kiss-yagni` | Prevents speculative refactor complexity |
| Skill | `legacy-code-safety` | Protects untested behavior during change |
| Skill | `logging-observability` | Evaluates operational logging and observability |
| Skill | `native-question-ux` | Presents questions through portable native UX |
| Skill | `null-safety` | Detects conservative null-safety hazards |
| Skill | `open-closed-principle` | Detects extension pressure without speculation |
| Skill | `refactor` | Supplies cross-language refactoring techniques |
| Skill | `risk-assessment` | Classifies technical and functional risk |
| Skill | `scope-analysis` | Delimits the target boundary |
| Skill | `sdd-draft-change` | Drafts one pre-implementation change document |
| Skill | `sdd-execution-skills` | Selects skills for implementation work |
| Skill | `single-responsibility` | Detects multiple reasons to change |
| Skill | `spaghetti-code-detection` | Detects tangled flow and hidden ordering |
| Skill | `tooling-audit` | Detects test-tooling gaps |
| Skill | `tooling-compatibility-matrix` | Selects compatible quality tooling |
| Skill | `type-contracts` | Detects weak or implicit types |
