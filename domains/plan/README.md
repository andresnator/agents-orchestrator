# Plan Domain

Planning skills keep discovery separate from executable planning. `orchestraitor` never implements while it plans.

## Quick path

1. Ask `orchestraitor` for a light plan, a deep plan, or an idea exploration.
2. Answer open product, acceptance, or risk questions.
3. Review one discovery or one IDSD plan. To turn a discovery into a plan, ask `convert this discovery into a plan`.

## Entry points

| Request | Skill | Result |
|---|---|---|
| Small localized outcome | `oc-plan-light` | Plan in chat; saved to `.ai/deep-planner/plans/<slug>.md` on request |
| Clear large or risky outcome | `oc-plan-deep` (Deep Plan) | `.ai/deep-planner/plans/<slug>.md` |
| Open destination or decisions | `oc-plan-deep` (Wayfinder) | `.ai/deep-planner/discoveries/<slug>.md` |
| Ambiguous planning intent | Closed choice | `Create a plan` or `Explore an idea` |

Plans use the IDSD format of `oc-plan-format`. Each plan recommends `direct` or `SDD` and shows `ejecuta el plan <path>`.

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `oc-arch-impact` | Classifies local versus architectural risk |
| `oc-conventions` | Applies code and test conventions |
| `oc-seams` | Finds safe testability seams |
| `oc-patterns` | Applies patterns to evidenced forces |
| `oc-domain` | Builds and sharpens domain models |
| `oc-naming` | Improves names, including Java |
| `oc-interview` | Stress-tests plans by interview |
| `oc-java-api` | Reviews Java API boundaries |
| `oc-java-errors` | Reviews Java failure handling |
| `oc-java-immutable` | Reviews safe Java data models |
| `oc-java-security` | Reviews Java security practices |
| `oc-java-test` | Designs focused Java test coverage |
| `oc-legacy` | Protects untested behavior |
| `oc-null-safety` | Detects conservative null-safety hazards |
| `oc-refactor` | Supplies refactoring techniques |
| `oc-risk-scope` | Classifies risk and scope |
| `oc-plan-deep` | Runs Wayfinder and Deep Plan |
| `oc-plan-light` | Drafts quick plans for localized work |
| `oc-plan-format` | Drafts one neutral IDSD plan |
| `oc-refactor-lens` | Applies refactor lenses read-only |
| `oc-routing` | Selects implementation skills |
| `oc-tooling-audit` | Detects tooling gaps |
| `oc-types` | Detects weak or implicit types |
