# Plan Domain

Planning skills separate discovery from executable planning; `orchestraitor` loads them and never implements while planning.

When a discovery is complete, ask `orchestraitor` to `convert this discovery into a plan`.

## Quick path

1. Ask `orchestraitor` for a light plan, deep plan, or to explore an idea.
2. Answer only unresolved product, acceptance, or risk questions.
3. Review one discovery or one IDSD execution plan.

## Entry points

| Request | Skill | Result |
|---|---|---|
| Small localized outcome | `oc-plan-light` | Plan in chat; saved to `.ai/deep-planner/plans/<slug>.md` on request |
| Clear large or risky outcome | `oc-plan-deep` (Deep Plan) | `.ai/deep-planner/plans/<slug>.md` |
| Open destination or decisions | `oc-plan-deep` (Wayfinder) | `.ai/deep-planner/discoveries/<slug>.md` |
| Ambiguous planning intent | Closed choice | `Create a plan` or `Explore an idea` |

Plans use the IDSD format from `oc-plan-format` (Intent, Context, Expectations, Method). Deep Plan always writes one file; large plans use work groups and dependencies, not roadmaps or slices. Missing protection places tooling, seams, tests, and revalidation before restructuring.

Every plan recommends `direct` or `SDD`, explains why, and shows `ejecuta el plan <path>`. After changing this domain, run the affected [Plan manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Skill | `oc-arch-impact` | Classifies local versus architectural risk |
| Skill | `oc-conventions` | Applies code and test conventions |
| Skill | `oc-seams` | Finds safe testability seams |
| Skill | `oc-patterns` | Applies patterns to evidenced forces |
| Skill | `oc-domain` | Builds and sharpens domain models |
| Skill | `oc-naming` | Improves naming, including Java conventions |
| Skill | `oc-graphify` | Queries code graphs read-only |
| Skill | `oc-interview` | Stress-tests plans through focused interviews |
| Skill | `oc-java-api` | Reviews Java API boundaries |
| Skill | `oc-java-errors` | Reviews Java failure handling |
| Skill | `oc-java-immutable` | Reviews safe Java data models |
| Skill | `oc-java-security` | Reviews Java security practices |
| Skill | `oc-java-test` | Designs focused Java test coverage |
| Skill | `oc-legacy` | Characterizes and protects untested behavior |
| Skill | `oc-null-safety` | Detects conservative null-safety hazards |
| Skill | `oc-refactor` | Supplies cross-language refactoring techniques |
| Skill | `oc-risk-scope` | Classifies risk and delimits target scope |
| Skill | `oc-plan-deep` | Runs Wayfinder and Deep Plan |
| Skill | `oc-plan-light` | Drafts quick plans for localized work |
| Skill | `oc-plan-format` | Drafts one neutral IDSD plan |
| Skill | `oc-refactor-lens` | Applies catalog refactor lenses read-only |
| Skill | `oc-routing` | Selects skills for implementation work |
| Skill | `oc-tooling-audit` | Detects tooling gaps with compatibility matrix |
| Skill | `oc-types` | Detects weak or implicit types |
