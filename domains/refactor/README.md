# Refactor Domain

Risk-gated planning for behavior-preserving refactors and test hardening. Successful plans become one ready-for-sdd `change.md`; this domain never implements them.

## Quick path

1. Use `/harden-plan` when the target lacks a reliable safety net.
2. Execute the resulting change through SDD.
3. Re-run `/refactor-plan` against the hardened code, then execute that change through SDD.

Features and intended behavior changes route to Deep Plan. Replacement candidates, frozen code, and commodity code may end with a recommendation instead of a plan.

## Operations

| Operation | Focus | Output |
|---|---|---|
| `hardening` | Tooling, seams, characterization tests, coverage, mutation baseline | `.ai/refactor-planner/changes/<change>/change.md` |
| `refactor` | Risk, churn, architecture impact, and behavior-preserving restructuring | Same path shape |

`refactor-planner` scopes and classifies risk, then delegates independent read-only lenses to `refactor-analyzer`. Missing optional lenses are reported as skipped. Git-history consent returns through the SDLC primary.

## Handoff

The finished file starts with `Status: ready-for-sdd | Source: refactor-planner`. It records behavior that must remain stable, the approach, ordered work with file scopes, verification commands, and risks. SDD adopts and executes that exact file in place without a second planning pass.

The domain assumes `sdlc`, `common`, and `sdd` are installed.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent coordinator) | `refactor-planner` | Plans refactor or hardening changes |
| Agent (subagent) | `refactor-analyzer` | Analyzes one read-only lens |
| Command | `/harden-plan` | Plans characterization and test safety |
| Command | `/refactor-plan` | Plans behavior-preserving restructuring |
| Skill | `architecture-impact-review` | Classifies local versus architectural risk |
| Skill | `behavior-characterization` | Records observable legacy behavior |
| Skill | `characterization-test-scoping` | Scopes tests, seams, containment, and rollback |
| Skill | `dependency-seam-detection` | Finds testability seams |
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
| Skill | `tooling-audit` | Detects test-tooling gaps |
| Skill | `tooling-compatibility-matrix` | Selects compatible quality tooling |
| Skill | `type-contracts` | Detects weak type contracts |
