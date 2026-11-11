# Common Domain

Shared engineering, quality, question, and output skills for all domains. Shared bodies are in [`skills/`](../../skills/README.md).

## Quick path

1. Include `common` with each domain that uses its skills.
2. Start with `/caveman` or `/grill`.
3. Review the routed result.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/caveman` | Select response compression | Saved global level |
| `/grill` | Stress-test an idea or artifact | Focused questions, revised outcome |

- `/caveman lite|full|ultra|wenyan` saves a global level; `/caveman` alone or no saved level means `lite`. `normal mode` or `stop caveman` saves `off`.
- The level persists across restarts and applies to the next response of every session on the same OpenCode configuration directory.
- An invalid argument keeps the level. State errors are reported, never silently reset.

See [Caveman guidance](skills/oc-caveman/SKILL.md).

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `/caveman` | Saves global response compression |
| `/grill` | Routes focused interview modes |
| `oc-caveman` | Compresses responses, preserving meaning |
| `oc-chained-pr` | Splits oversized work into slices |
| `oc-conventions` | Applies code and test conventions |
| `oc-refine-output` | Condenses output without losing meaning |
| `oc-patterns` | Applies patterns to evidenced forces |
| `oc-domain` | Builds and sharpens domain models |
| `oc-naming` | Improves names, including Java |
| `oc-grill` | Selects focused interview modes |
| `oc-interview` | Stress-tests plans by interview |
| `oc-practices` | Evaluates language-neutral code quality |
| `oc-risk-scope` | Classifies risk and scope |
| `oc-refactor-lens` | Applies refactor lenses read-only |
| `oc-plan-format` | Drafts one neutral execution plan |
| `oc-routing` | Selects implementation skills |
| `oc-debug` | Finds root causes before fixes |
| `oc-tcr` | Runs test-commit-revert micro-cycles |
| `oc-commits` | Plans cohesive commits |
| `caveman-mode` (plugin) | Persists the global mode |
