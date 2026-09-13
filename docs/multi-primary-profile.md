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

Localized work runs directly without `.ai/` state or an approval gate. For newly generated SDD contracts, Orchestraitor presents Outcome, Scope, every WHEN/THEN scenario, Approach, and Verify and waits for approval before creating state or implementing. Direct → SDD uses the same approval for contract and route; adjustments require approval of the revised draft.

Executing an exact existing plan uses Direct or SDD without another contract or route confirmation; structural validation, delivery controls, and the external plan checksum remain required. SDD runs live under `.ai/orchestration/runs/` and record `Approval: explicit | plan-execution` plus the actual `Approval evidence:`. `continúa <run>` resumes an approved run without reconfirmation, preserving its contract, progress, and Git controls. Missing approval blocks as an incomplete execution contract; no migration is performed.

## Remove

```bash
scripts/multi-primary-profile.sh uninstall --project-root /absolute/project
```

Uninstall removes only manifest-owned content. It restores the prior `subagent_depth` and preserves foreign files and configuration.

## Manual regression

Follow [`MT-REPOSITORY-MULTI-PRIMARY-PROFILE`](manual-testing.md#mt-repository-multi-primary-profile) in a disposable Git project. Unsafe project roots and symlinked targets are covered separately by [`MT-REPOSITORY-UNSAFE-TARGETS`](manual-testing.md#mt-repository-unsafe-targets).
