---
name: evidence-first-planning
description: "Trigger: deep plan, evidence-first plan, planificar a fondo, planificacion basada en evidencia, discovery plan. Plan executable changes, decisions, discovery, and roadmap slices from repository evidence."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "4.0.0"
---

## Contract

Plan before implementation. Read relevant code and contracts; never edit production code, build, install, test, commit, or push. Planning artifacts are the only writes.

## Method

1. **Evidence first.** Verify implementations, callers, tests, tool versions, and reusable `path:symbol` elements. Cite `path:line` or mark `hypothesis`.
2. **Ask only decisions.** Explore repository facts. Ask each unresolved open-ended scope, product, acceptance, or risk choice directly in normal chat and wait. Add `Recommendation: ...` only when useful; reserve the `question` tool for closed choices.
3. **Validate edges.** Every edge is handled, out of scope, or an open question. Use `references/edge-validation.md`.
4. **Stay proportional.** Keep only information that changes execution; record meaningful rejected alternatives briefly.
5. **Prove the flow.** End with executable commands or an observable end-to-end check and its expected result.

## Durable plans

Use `assets/plan-template.md` for decisions and multi-session discovery. `Status: discovery` permits unresolved user decisions; `Status: final` does not. Create a new slug only when absent. Update a plan only when its exact path comes from the same resumed task or the user; otherwise return `ASK` instead of guessing or overwriting.

## Roadmaps

Use `assets/roadmap-template.md` when one bounded `change.md` cannot deliver the goal. Plan only the next unblocked slice. Its change starts with the normal ready-for-SDD marker and then `Roadmap: <goal> | Slice: <n>/<total>` on line two. Slice states are `pending`, `planned`, `adopted`, `done`, or user-approved `dropped`. `"continúa el roadmap <goal>"` maps only to `.ai/roadmaps/<goal>.md`; advance the first `pending` row whose dependencies are `done` only when no row is already `planned|adopted`, create its one change, and stop. Never guess through missing, malformed, or blocked state; a completed roadmap has no next slice.

## Outputs

- Decision or discovery: one `.ai/deep-planner/plans/<slug>.md`.
- Bounded executable change: one ready `change.md` using `sdd-draft-change`.
- Oversized executable change: one roadmap plus one ready `change.md` for the next slice.

Before returning, check evidence, edges, proportionality, exact paths, and end-to-end verification. Report only the artifact path and next route.

## Resources

- `assets/plan-template.md`
- `assets/roadmap-template.md`
- `references/edge-validation.md`
- `references/question-economy.md`
