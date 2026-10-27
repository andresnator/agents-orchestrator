# Single-Primary Profile

The profile (script and contract id keep the historical `multi-primary` name) installs one direct primary, `orchestraitor`, while preserving the user's default agent and foreign configuration. Every other capability is an `oc-*` skill.

## Quick path

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/project
scripts/multi-primary-profile.sh status --project-root /absolute/project
```

Select `orchestraitor` in OpenCode for every route.

## Routes

| Need | Skills (loaded by orchestraitor or a `general` brief) | Entry |
|---|---|---|
| Quick plan for localized work | `oc-plan-light` | Natural request (light plan, plan rápido) |
| Discover or plan in depth | `oc-plan-deep` | Natural request (deep plan, plan profundo, wayfinder) |
| Change, execute plan, or resume | direct, `oc-sdd`, `oc-sdd-*` | Natural request, `ejecuta el plan <path>`, `continúa <run>` |
| Review or defend | `oc-review`, `oc-judge`, `oc-judge-fix` | Natural request or `/review` |
| Map or decide architecture | `oc-arch` | Natural request or `/arch` |

Orchestraitor picks light versus deep planning from explicit user words, then by size and risk, and never implements while planning. For specialized work, orchestraitor loads the skill itself or briefs the built-in `general` subagent with the exact skill to load (one delegation level). Planning and orchestration have no public commands.

The profile domains are `plan,orchestration,architecture,review,common`. The six public commands belong to Architecture and Review and all run on `orchestraitor`.

## Execution

Plans are IDSD Markdown files (Intent, Context, Expectations, Method). Give `orchestraitor` the exact path with `ejecuta el plan <path>`.

Localized work runs directly without `.ai/` state or an approval gate. For newly generated SDD contracts, Orchestraitor presents Intent, Context scope, every WHEN/THEN scenario, Done means, and Approach and waits for approval before creating state or implementing. Direct → SDD uses the same approval for contract and route; adjustments require approval of the revised draft.

Executing an exact existing plan uses Direct or SDD without another contract or route confirmation; structural validation, delivery controls, and the external plan checksum remain required. SDD runs live under `.ai/orchestration/runs/` and record `Approval: explicit | plan-execution` plus the actual `Approval evidence:`. `continúa <run>` resumes an approved run without reconfirmation, preserving its contract, progress, and Git controls. Missing approval blocks as an incomplete execution contract; no migration is performed.

## Remove

```bash
scripts/multi-primary-profile.sh uninstall --project-root /absolute/project
```

Uninstall removes only manifest-owned content. It restores the prior `subagent_depth` and preserves foreign files and configuration.

## Manual regression

Follow [`MT-REPOSITORY-MULTI-PRIMARY-PROFILE`](manual-testing.md#mt-repository-multi-primary-profile) in a disposable Git project. Unsafe project roots and symlinked targets are covered separately by [`MT-REPOSITORY-UNSAFE-TARGETS`](manual-testing.md#mt-repository-unsafe-targets).
