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
| Skill | `oc-arch-impact` | Classifies local versus architectural risk |
| Skill | `oc-characterize` | Records observable legacy behavior |
| Skill | `oc-char-scope` | Scopes tests, seams, and rollback |
| Skill | `oc-conventions` | Applies code and test conventions |
| Skill | `oc-coupling` | Detects cohesion and coupling problems |
| Skill | `oc-big-o` | Evaluates algorithmic and control complexity |
| Skill | `oc-dip` | Detects concrete dependency boundary risks |
| Skill | `oc-seams` | Finds safe testability seams |
| Skill | `oc-patterns` | Applies patterns to evidenced forces |
| Skill | `oc-domain` | Builds and sharpens domain models |
| Skill | `oc-dry` | Distinguishes knowledge duplication from similarity |
| Skill | `oc-evidence` | Builds evidence-first executable plans |
| Skill | `oc-naming` | Improves language-neutral naming and readability |
| Skill | `oc-god-object` | Detects oversized multi-responsibility objects |
| Skill | `oc-graphify` | Queries code graphs read-only |
| Skill | `oc-interview` | Stress-tests plans through focused interviews |
| Skill | `oc-preconditions` | Detects missing or duplicated preconditions |
| Skill | `oc-java-api` | Reviews Java API boundaries |
| Skill | `oc-java-errors` | Reviews Java failure handling |
| Skill | `oc-java-immutable` | Reviews safe Java data models |
| Skill | `oc-java-naming` | Reviews Java naming and readability |
| Skill | `oc-java-security` | Reviews Java security practices |
| Skill | `oc-java-test` | Designs focused Java test coverage |
| Skill | `oc-kiss` | Prevents speculative refactor complexity |
| Skill | `oc-legacy` | Protects untested behavior during change |
| Skill | `oc-logging` | Evaluates operational logging and observability |
| Skill | `oc-null-safety` | Detects conservative null-safety hazards |
| Skill | `oc-ocp` | Detects extension pressure without speculation |
| Skill | `oc-refactor` | Supplies cross-language refactoring techniques |
| Skill | `oc-risk` | Classifies technical and functional risk |
| Skill | `oc-scope` | Delimits the target boundary |
| Skill | `oc-plan-format` | Drafts one neutral execution plan |
| Skill | `oc-routing` | Selects skills for implementation work |
| Skill | `oc-srp` | Detects multiple reasons to change |
| Skill | `oc-spaghetti` | Detects tangled flow and hidden ordering |
| Skill | `oc-tooling-audit` | Detects test-tooling gaps |
| Skill | `oc-tooling-matrix` | Selects compatible quality tooling |
| Skill | `oc-types` | Detects weak or implicit types |
