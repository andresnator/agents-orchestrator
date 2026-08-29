# Multi-Primary Profile

The profile installs four direct primaries while preserving the user's default agent and foreign configuration.

## Quick path

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/project
scripts/multi-primary-profile.sh status --project-root /absolute/project
```

Select `deep-planner`, `architect`, `orchestraitor`, or `review-coordinator` in OpenCode.

## Routes

| Need | Primary | Entry |
|---|---|---|
| Discover or plan | `deep-planner` | Natural request |
| Map or decide architecture | `architect` | Natural request or `/arch-*` |
| Change, execute plan, or resume | `orchestraitor` | Natural request |
| Review or defend | `review-coordinator` | Natural request or `/judgment`, `/defend` |

The profile domains are `plan,orchestration,architecture,review,common`. The six primary commands belong to Architecture and Review. Planning and orchestration have no public commands.

## Execution

Plans are neutral Markdown files. Give `orchestraitor` the exact path with `ejecuta el plan <path>`.

Localized work runs directly without `.ai/` state. SDD state starts only after explicit intent or a closed confirmation and lives under `.ai/orchestration/runs/`.

## Remove

```bash
scripts/multi-primary-profile.sh uninstall --project-root /absolute/project
```

Uninstall removes only manifest-owned content. It restores the prior `subagent_depth` and preserves foreign files and configuration.

## Verify

```bash
scripts/test-multi-primary-profile.sh
scripts/test-plan-orchestration-contracts.sh
```
