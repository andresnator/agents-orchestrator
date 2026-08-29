---
name: execution-plan
description: "Trigger: execution plan, executable plan, deep plan. Draft one neutral plan for direct or SDD execution."
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
  status: testing
---

## Contract

Create exactly one plan for the requested outcome. The plan may be small or large. Use `assets/plan-template.md`.

## Rules

- Use short complete sentences. Keep paths, symbols, commands, URLs, technical terms, numbers, and Markdown exact.
- Omit empty sections and filler. Keep the artifact clear to a human; do not use cryptic A2A fragments inside it.
- Before writing, check the exact destination. Update an existing plan only when the user supplied its exact path or the active conversation already created or selected it. On any other slug collision, ask one closed choice: reuse the existing plan or generate a new slug. Never overwrite implicitly.
- Qualify behavior identifiers as `<capability>/<requirement>` when canonical specs matter. Use observable `WHEN` and `THEN` scenarios.
- Use ordered work groups with explicit dependencies. Keep one file even when groups span sessions.
- Every work group requires `Files:` and `Skills:`. Select names with `implementation-skill-routing`; use names, never paths.
- Include one `Execution guidance` recommendation: `direct` or `SDD`. State the reason and show `ejecuta el plan <path>`.
- Artifacts default to English. Planning is read-only except for the plan file. Never edit production code, commit, or push.

## Self-check

- One file contains every required section from the template.
- Every claim is evidenced or explicitly marked as an open question.
- Every task is actionable and verifiable; behavior changes do not hide in tasks.
- Every work group names its implementation skills or `none`.
- Dependencies are explicit and acyclic.
- Risks contain only real rollback conditions or execution hazards.

## Resource

- `assets/plan-template.md`
