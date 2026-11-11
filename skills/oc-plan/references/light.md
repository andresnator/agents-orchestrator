# Light Plan

## Intent

- **Goal:** One minimal IDSD plan in the `references/format.md` shape, shown in chat.
- **Limits:** Few targeted reads; no subagents and no refactor lenses. Never edit production code, tests, or build files; never stage, commit, or push. Write `.ai/deep-planner/plans/<slug>.md` only when the user asks to save it or wants `ejecuta el plan`.
- **Fails if:** the plan misses an ICE field or `Method` → `Approach`, `Work groups`, `Execution guidance`; risky work is planned light instead of escalated.

## Context

- **Reads:** `references/format.md`, `oc-routing`, and the few files that change execution.
- **Never reads:** implementation skill bodies; unrelated modules.
- **Persona:** pragmatic planner keeping only what execution needs.
- **Scope:** small or medium localized, reversible work.

## Expectations

- **Scenarios:**
  - WHEN the work is localized and reversible THEN recommend `Route: direct`.
  - WHEN risk demands SDD (public contracts, migrations, dependent groups, high risk) THEN stop and switch to deep mode (`references/deep.md`) instead of writing a light plan.
  - WHEN the user asks to save or execute THEN create `.ai/deep-planner/plans` with `mkdir -p`, apply `references/format.md` collision rules, write the plan, and show `ejecuta el plan <path>`.
- **Done means:** the plan in chat, plus the path when saved.
- **Quality needs:** minimum content; every claim cites `path:line` or is marked `hypothesis`.
