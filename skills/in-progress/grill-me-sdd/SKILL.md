---
name: grill-me-sdd
description: "Trigger: grill me sdd, entrevistame sdd, SDD planning interview. Interview relentlessly, then draft proposal, specs, design, and ordered tasks."
license: MIT
metadata:
  author: Agents Orchestrator maintainers
  inspired_by: Matt Pocock
  source_url: https://github.com/mattpocock/skills
  version: "1.0.0"
---

## Activation Contract

Use when the user wants a relentless SDD planning interview that produces an OpenSpec planning set: `proposal.md`, capability specs, `design.md`, and `tasks.md`.

## Hard Rules

- Follow the `grilling` skill: one question at a time, attach a recommendation, stop and wait, and explore the codebase instead of asking when possible.
- Follow the `native-question-ux` skill for question presentation; ask one question at a time and stop after each answer.
- Interview/summaries/gates use the user's language; artifacts default to English unless the user explicitly requests Spanish artifacts.
- Plan-only: read-only codebase access; no code edits, builds, installs, tests, commits, or state-changing commands. The only side effect is writing approved planning `.md` files.
- Subskills return approved drafts only; this orchestrator owns the single write step.

## Decision Gates

| Situation | Action |
| --- | --- |
| Missing change name | Propose a kebab-case, verb-led name and confirm. |
| `openspec/changes/{change-name}/` exists | Ask resume vs rename. |
| Product/business uncertainty | Route to `sdd-draft-proposal`. |
| Observable behavior uncertainty | Route to `sdd-draft-spec`. |
| Technical/architecture uncertainty | Route to `sdd-draft-design`. |
| Slicing or task-ordering uncertainty | Route to `sdd-draft-tasks`. |
| User stops early | Offer to write approved artifacts only. |

## Execution Steps

1. Set language and confirm the change name.
2. If an existing change folder exists, ask whether to resume or rename.
3. Run `sdd-draft-proposal`; loop inline until the proposal draft is approved.
4. Build the capability work list from proposal Capabilities.
5. Ask once whether spec approval should be per-file or batched.
6. Run `sdd-draft-spec` for each capability or batch; loop until approved.
7. Run `sdd-draft-design`; it must silently explore the real codebase read-only before technical questions or draft.
8. Run `sdd-draft-tasks` with the approved spec and design; loop inline until the tasks draft is approved.
9. Ask once to write N files under `openspec/changes/{change-name}/`.
10. On yes, write exactly `proposal.md`, `specs/{capability}/spec.md`, `design.md`, and `tasks.md`; on no, leave drafts inline.

## Output Contract

Return approved drafts, write status, paths written or pending, and unresolved questions. If a referenced skill cannot be resolved by name in the current runtime, say so instead of silently continuing.

## References

- `grilling` skill
- `native-question-ux` skill
- `sdd-draft-proposal` skill
- `sdd-draft-spec` skill
- `sdd-draft-design` skill
- `sdd-draft-tasks` skill

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; adapted for SDD planning orchestration.
