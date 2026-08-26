---
name: grill
description: "Trigger: grill me, grill with docs, grill me sdd, grill code, grill docs open, entrevistame, entrevistame sdd. Relentless interview router for plain, docs, or SDD planning."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "5.0.0"
---

## Modes

| Trigger | Mode | Result |
| --- | --- | --- |
| `grill me`, `grill code`, `entrevistame` | plain | `grilling` interview |
| `grill with docs`, `grill docs open` | docs | interview plus approved domain notes |
| `grill me sdd`, `entrevistame sdd` | sdd | one approved `change.md` |

## Rules

- Ask each open-ended question directly in normal chat, one at a time, then stop. Add `Recommendation: ...` only when useful.
- Use the `question` tool only for closed confirmations, modes, ratings, or enumerated choices.
- Explore discoverable answers instead of asking. Preserve the user's language; artifacts default to English.
- SDD mode is plan-only: no code edits, builds, installs, tests, commits, or push. The approved planning file is the only write.

## Flow

- Plain: load `grilling`; interview until the decision is clear.
- Docs: also load `domain-modeling`; write notes only with approval.
- SDD: confirm a kebab-case change name and collision handling; interview outcome, scope, behavior, approach, work, verification, Mode, TDD, Judgment, and Delivery. Load `sdd-execution-skills`, never load or read implementation skill bodies, record its result for every Work group, then draft with `sdd-draft-change`. Ask once to write `.ai/orchestrator/changes/<change>/change.md`; on approval write only that file with `Status: active`. On refusal, keep the draft in chat.

Return the current question or conclusion, write status, path, and unresolved decisions. Missing skills are reported, never silently skipped.

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>.
