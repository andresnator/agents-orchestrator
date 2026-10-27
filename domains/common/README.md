# Common Domain

Shared engineering, quality, question, and output skills used across domains. It also owns Graphify consent and background refresh integration.

## Quick path

1. Include `common` with every domain that uses its shared skills.
2. Start with `/caveman`, `/graphify-index`, or `/grill`.
3. Review the routed result or generated Graphify state.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/caveman` | Select response compression | Globally saved level for all primaries and subagents |
| `/graphify-index` | Approve first indexing | Recorded mode and repository graph |
| `/grill` | Stress-test an idea or artifact | Focused questions and revised outcome |

Shared skills have one body under top-level `skills/`; each consuming domain declares it with a relative symlink. `/graphify-index` owns first-run consent, while the pinned `opencode-graphify-init` package only refreshes previously approved indexes. See the [Graphify guide](../../docs/graphify.md).

After changing this domain, run the affected [Common manual tests](manual-tests.md).

### Caveman scope and persistence

With no saved selection, Caveman uses `lite`. `/caveman lite|full|ultra|wenyan` saves a global level; bare `/caveman` selects `lite`. Send `normal mode` or `stop caveman` as a standalone message to save `off` for normal prose. All levels, including `off`, persist across restarts until explicitly replaced.

The selection applies on the next response of every existing and new primary and subagent session sharing the same global OpenCode configuration directory, including other processes. It does not affect earlier responses, other machines, or independent configuration directories. Invalid arguments preserve the saved level and show valid syntax; state errors are reported rather than silently reset.

Quit and restart OpenCode after installing or changing plugin code or configuration-time files. Once loaded, mode changes need no restart. See [Caveman guidance](skills/oc-caveman/SKILL.md) for levels and storage details and [the manual test](manual-tests.md#mt-common-caveman) for real-process verification.

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/caveman` | Saves global response compression |
| Command | `/graphify-index` | Indexes Graphify after explicit consent |
| Command | `/grill` | Routes focused interview modes |
| Skill | `oc-caveman` | Preserves meaning during response compression |
| Skill | `oc-chained-pr` | Splits oversized work into reviewable slices |
| Skill | `oc-conventions` | Applies code and test conventions |
| Skill | `oc-refine-output` | Condenses output without losing meaning |
| Skill | `oc-patterns` | Applies patterns to evidenced forces |
| Skill | `oc-domain` | Builds and sharpens domain models |
| Skill | `oc-naming` | Improves naming, including Java conventions |
| Skill | `oc-graphify` | Queries Graphify code graphs read-only |
| Skill | `oc-grill` | Selects focused interview modes |
| Skill | `oc-interview` | Stress-tests plans through focused interviews |
| Skill | `oc-practices` | Evaluates language-neutral code quality |
| Skill | `oc-risk-scope` | Classifies risk and delimits target scope |
| Skill | `oc-refactor-lens` | Applies catalog refactor lenses read-only |
| Skill | `oc-plan-format` | Drafts one neutral execution plan |
| Skill | `oc-routing` | Selects skills for implementation work |
| Skill | `oc-debug` | Finds root causes before fixes |
| Skill | `oc-tcr` | Runs test-commit-revert micro-cycles |
| Skill | `oc-commits` | Plans reviewable and cohesive commits |
| Plugin | `caveman-mode` | Persists global mode and reads it before every primary/subagent response |
| External npm server plugin | `opencode-graphify-init` | Refreshes approved Graphify indexes |
