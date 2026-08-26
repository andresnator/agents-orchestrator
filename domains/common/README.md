# Common Domain

Shared engineering, quality, question, and output skills used across domains. It also owns Graphify consent and background refresh integration.

## Quick path

1. Include `common` with every domain that uses its shared skills.
2. Start with `/graphify-index` or `/grill`.
3. Review the routed result or generated Graphify state.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/graphify-index` | Approve first indexing | Recorded mode and repository graph |
| `/grill` | Stress-test an idea or artifact | Focused questions and revised outcome |

Shared skills have one body under top-level `skills/`; each consuming domain declares it with a relative symlink. `/graphify-index` owns first-run consent, while the pinned `graphify-init` plugin only refreshes previously approved indexes. See the [Graphify guide](../../docs/graphify.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/graphify-index` | Indexes Graphify after explicit consent |
| Command | `/grill` | Routes focused interview modes |
| Skill | `chained-pr` | Splits oversized work into reviewable slices |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `cognitive-output-refiner` | Condenses output without losing meaning |
| Skill | `cohesion-coupling` | Detects cohesion and coupling problems |
| Skill | `complexity-big-o` | Evaluates algorithmic and control complexity |
| Skill | `dependency-inversion` | Detects concrete dependency boundary risks |
| Skill | `design-patterns-pragmatic` | Applies patterns to evidenced forces |
| Skill | `domain-modeling` | Builds and sharpens domain models |
| Skill | `dry-business-knowledge` | Distinguishes knowledge duplication from similarity |
| Skill | `general-naming-readability` | Improves language-neutral naming and readability |
| Skill | `god-object-detection` | Detects oversized multi-responsibility objects |
| Skill | `graphify-cli` | Queries Graphify code graphs read-only |
| Skill | `grill` | Selects focused interview modes |
| Skill | `grilling` | Stress-tests plans through focused interviews |
| Skill | `input-validation-preconditions` | Detects missing or duplicated preconditions |
| Skill | `judgment-day` | Runs dual blind adversarial reviews |
| Skill | `kiss-yagni` | Prevents speculative refactor complexity |
| Skill | `logging-observability` | Evaluates operational logging and observability |
| Skill | `native-question-ux` | Presents questions through portable native UX |
| Skill | `open-closed-principle` | Detects extension pressure without speculation |
| Skill | `programming-practices-core` | Evaluates language-neutral code quality |
| Skill | `risk-assessment` | Classifies technical and functional risk |
| Skill | `sdd-draft-change` | Drafts one pre-implementation change document |
| Skill | `sdd-execution-skills` | Selects skills for implementation work |
| Skill | `single-responsibility` | Detects multiple reasons to change |
| Skill | `small-functions` | Detects oversized and extractable functions |
| Skill | `spaghetti-code-detection` | Detects tangled flow and hidden ordering |
| Skill | `systematic-debugging` | Finds root causes before fixes |
| Skill | `tcr` | Runs test-commit-revert micro-cycles |
| Skill | `work-unit-commits` | Plans reviewable and cohesive commits |
| External server plugin | `graphify-init` | Refreshes previously approved Graphify indexes |
