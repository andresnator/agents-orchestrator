# Single-Primary Profile

The profile installs one primary agent, `orchestraitor`. The script keeps the historical `multi-primary` name. The profile keeps your default agent and foreign configuration.

## Quick path

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/project
scripts/multi-primary-profile.sh status --project-root /absolute/project
```

Select `orchestraitor` in OpenCode for all routes.

## Routes

| Need | Skills (loaded by orchestraitor or a `general` brief) | Entry |
|---|---|---|
| Quick plan for localized work | `oc-plan-light` | Natural request (light plan, plan rápido) |
| Discover or plan in depth | `oc-plan-deep` | Natural request (deep plan, plan profundo, wayfinder) |
| Change, execute plan, or resume | direct, `oc-sdd`, `oc-sdd-*` | Natural request, `ejecuta el plan <path>`, `continúa <run>` |
| Review or defend | `oc-review`, `oc-judge`, `oc-judge-fix` | Natural request or `/review` |
| Map or decide architecture | `oc-arch` | Natural request or `/arch` |

Orchestraitor selects light or deep planning from your words, else by size and risk. It never implements while it plans. The profile domains are `plan,orchestration,architecture,review,common`.

## Execution

Give `orchestraitor` the exact plan path with `ejecuta el plan <path>`.

Localized work runs directly, without `.ai/` state or approval. For a new SDD contract, Orchestraitor shows these items and waits for approval:

- Intent
- Context scope
- Each WHEN/THEN scenario
- Done means
- Approach

A Direct → SDD change and a revised draft need the same approval. An existing plan runs without another confirmation, but structural validation and the plan checksum still apply.

SDD runs are in `.ai/orchestration/runs/` and record `Approval: explicit | plan-execution` plus `Approval evidence:`. `continúa <run>` resumes an approved run without a new confirmation. A run without approval is blocked.

## Remove

```bash
scripts/multi-primary-profile.sh uninstall --project-root /absolute/project
```

Uninstall removes only manifest-owned content and restores the prior `subagent_depth`.
