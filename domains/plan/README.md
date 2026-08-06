# Plan Domain

`deep-planner` turns evidence into either an executable `change.md`, a human decision plan, or a multi-session discovery map. It plans only; SDD owns implementation.

## Quick path

1. Use natural language through `sdlc-orchestrator` or `/deep-plan <goal>`.
2. Answer only unresolved product or technical decisions.
3. For an executable goal, review `.ai/deep-planner/changes/<change>/change.md`, then request implementation.

## Outputs

| Need | Output | Next step |
|---|---|---|
| Bounded executable goal | `.ai/deep-planner/changes/<change>/change.md` | SDD executes it in place |
| Oversized executable goal | `.ai/roadmaps/<goal>.md` plus the first slice's `change.md` | Plan slices just in time with `"continúa el roadmap <goal>"` |
| Decision or investigation | `.ai/deep-planner/plans/<slug>.md` | Human review; no automatic SDD handoff |
| Foggy multi-session effort | `.ai/wayfinder/<map>/` | Resolve one decision ticket per session, then Deep Plan |

## One-document handoff

A ready change starts with `Status: ready-for-sdd | Source: deep-planner`. The file holds outcome, scope, behavior deltas, approach, ordered work, verification, and non-empty risks. The planner returns its exact path; `orchestraitor` adopts that path, adds execution state, and does not redraft or copy it.

Keep each change bounded. Split large goals into roadmap slices rather than companion proposal, design, spec, and task documents. Safe work groups may run in parallel only when their `Files:` scopes are disjoint.

The domain assumes `common` for planning methods and `sdd` for the shared `sdd-draft-change` contract.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent) | `deep-planner` | Produces executable handoffs or evidence-first human plans |
| Command | `/deep-plan` | Routes executable and decision planning |
| Command | `/wayfinder` | Advances multi-session discovery maps |
| Skill | `fable-planning` | Builds evidence-first plans and validates edge cases |
| Skill | `wayfinder` | Maps unresolved decisions across sessions |
