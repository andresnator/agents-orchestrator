---
name: grill
description: "Trigger: grill me, grill with docs, grill me sdd, grill code, grill docs open, entrevistame, entrevistame sdd. Router for relentless interview modes: plain, docs, or SDD planning."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "1.0.3"
---

## Activation Contract

Use when the user wants a relentless interview for a plan, design, code approach, docs-backed exploration, or SDD planning set.

Select exactly one mode:

| Trigger shape | Mode | Behavior |
| --- | --- | --- |
| `grill me`, `grill code`, `entrevistame` | `plain` | Run `grilling` with native question UX. |
| `grill with docs`, `grill docs open` | `docs` | Run `grilling` plus `domain-modeling` with native question UX. |
| `grill me sdd`, `entrevistame sdd`, SDD planning interview | `sdd` | Interview, then draft OpenSpec `proposal.md`, specs, `design.md`, and `tasks.md`. |

## Hard Rules

- Every user-facing question MUST go through the `native-question-ux` skill. Use its fallback if the runtime has no native question tool.
- Follow the `grilling` skill in every mode: one question at a time, attach a recommendation, stop and wait, and explore the codebase instead of asking when possible.
- Preserve open-ended interview semantics; do not turn the flow into generic code review.
- `docs` mode also follows `domain-modeling` to capture terms, decisions, and context as they emerge.
- Interview/summaries/gates use the user's language; artifacts default to English unless the user explicitly requests Spanish artifacts.
- `sdd` mode is plan-only: read-only codebase access; no code edits, builds, installs, tests, commits, or state-changing commands. The only side effect is writing approved planning `.md` files.
- In `sdd` mode, subskills return approved drafts only; this orchestrator owns the single write step.

## Plain Mode

1. Load `grilling`.
2. Ask each interview question through `native-question-ux`.
3. Stop after each question and wait for the answer.
4. Return the next question, recommendation, or conclusion from the active grilling flow.

## Docs Mode

1. Load `grilling` and `domain-modeling`.
2. Ask each interview question through `native-question-ux`.
3. Capture useful terminology, decisions, and context through the `domain-modeling` flow when the user approves documentation.
4. Stop after each question and wait for the answer.
5. Return the next question, recommendation, captured-doc status, or conclusion from the active flow.

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

Use these steps only in `sdd` mode:

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
- `domain-modeling` skill
- `sdd-draft-proposal` skill
- `sdd-draft-spec` skill
- `sdd-draft-design` skill
- `sdd-draft-tasks` skill

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; adapted for SDD planning orchestration.
