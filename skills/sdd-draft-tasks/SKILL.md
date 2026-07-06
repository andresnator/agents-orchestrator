---
name: sdd-draft-tasks
description: "Trigger: draft tasks, borrador de tareas, SDD tasks interview. Draft ordered, verifiable tasks from spec and design; plan-only, write on approval."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "2.0.0"
---

## Activation Contract

Use when drafting an OpenSpec `tasks.md` from an approved spec and design: an ordered, dependency-aware checklist. Works standalone or delegated by `grill`.

## Hard Rules

- Follow the `grilling` skill: one question at a time, recommendation attached, stop and wait; read spec/design context instead of asking when possible.
- Follow the `native-question-ux` skill for question presentation; ask one question at a time and stop after each answer.
- Interview/summaries/gates use the user's language; artifacts default to English unless Spanish artifacts are explicitly requested.
- Plan-only: read-only codebase access; no code edits, builds, installs, tests, or state changes. Only write planning `.md` files after explicit approval.
- Every task line MUST be `- [ ] X.Y {concrete action naming real files}`: Specific, Actionable, Verifiable, Small enough for one session. Never vague ("implement feature"). Testing tasks reference specific spec scenarios.
- Order groups by dependency: a task may only depend on earlier tasks; never forward-reference a later group. Execution scheduling (batching, parallelism, worktrees) is left to the implementer.
- Preserve the four Review Workload Forecast guard lines VERBATIM (the orchestraitor gates on them before implementing): `Decision needed before apply:`, `Chained PRs recommended:`, `Chain strategy:`, `400-line budget risk:`.
- Keep the artifact under 650 words. When delegated by grill, return the approved draft and do not write files; the orchestrator owns the single write step.

## Decision Gates

| Situation | Action |
| --- | --- |
| Standalone and spec/design exist on disk | Read them; the design File Changes table seeds concrete task targets. |
| Missing spec or design | Offer to run `sdd-draft-spec` or `sdd-draft-design` first. |
| A task depends on another | Order it after its dependency; never forward-reference a later group. |
| Estimated changed lines exceed 400 | Recommend a chained-PR split in the forecast and ask. |

## Execution Steps

1. Read `assets/tasks-template.md` and `references/question-bank.md`; read the approved spec and design.
2. Interview for slicing, dependency order, and per-task verification.
3. Draft `tasks.md` inline from the template with the forecast and dependency-ordered grouped checkboxes.
4. Present for approval; revise until approved.
5. If standalone and approved, ask before writing `.orchestraitor/changes/{change-name}/tasks.md`.

## Output Contract

Return approved/unapproved status, tasks draft, dependency order, forecast values, and open questions. If a referenced skill cannot be resolved by name in the current runtime, say so instead of silently continuing.

## References

- `assets/tasks-template.md`
- `references/question-bank.md`
- `grilling` skill
- `native-question-ux` skill

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; adapted for OpenSpec task drafting.
