# Plan Domain

`deep-planner` separates discovery from executable planning. It never implements changes.

## Quick path

1. Select `deep-planner` and describe the outcome or idea.
2. Answer only unresolved product, acceptance, or risk questions.
3. Review one discovery or one execution plan.

## Entry points

| Request | Route | Result |
|---|---|---|
| Clear executable outcome | Deep Plan | `.ai/deep-planner/plans/<slug>.md` |
| Open destination or decisions | Wayfinder | `.ai/deep-planner/discoveries/<slug>.md` |
| Ambiguous planning intent | Closed choice | `Create a plan` or `Explore an idea` |

Wayfinder records evidence, decisions, and open questions without status markers. When discovery finishes, ask `deep-planner` to convert it into a plan.

Deep Plan always writes one file. Large plans use work groups and dependencies, not roadmaps or slices. Refactor and hardening are internal rules: missing protection places tooling, seams, tests, and revalidation before restructuring.

Every plan recommends `direct` or `SDD`, explains why, and shows `ejecuta el plan <path>`. After changing this domain, run the affected [Plan manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `deep-planner` | Runs Wayfinder and Deep Plan |
| Agent (subagent) | `refactor-analyzer` | Applies one read-only analysis lens |
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
| Skill | `null-safety` | Detects conservative null-safety hazards |
| Skill | `open-closed-principle` | Detects extension pressure without speculation |
| Skill | `refactor` | Supplies cross-language refactoring techniques |
| Skill | `risk-assessment` | Classifies technical and functional risk |
| Skill | `scope-analysis` | Delimits the target boundary |
| Skill | `execution-plan` | Drafts one neutral execution plan |
| Skill | `implementation-skill-routing` | Selects skills for implementation work |
| Skill | `single-responsibility` | Detects multiple reasons to change |
| Skill | `spaghetti-code-detection` | Detects tangled flow and hidden ordering |
| Skill | `tooling-audit` | Detects test-tooling gaps |
| Skill | `tooling-compatibility-matrix` | Selects compatible quality tooling |
| Skill | `type-contracts` | Detects weak or implicit types |
