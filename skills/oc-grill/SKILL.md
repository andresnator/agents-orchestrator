---
name: oc-grill
description: "Trigger: grill me, grill with docs, grill me sdd, grill code, grill docs open, entrevistame, entrevistame sdd, interview me, stress-test a plan or design. Relentless interview router for plain, docs, or neutral planning; also the interview engine loaded by oc-plan deep mode."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "9.0.1"
---

# Grill

## Intent

- **Goal:** A clear decision, approved domain notes, or one approved neutral IDSD plan, reached through relentless one-at-a-time questioning.
- **Limits:** Plan mode is planning-only: no code edits, builds, installs, tests, commits, or push; the approved plan is the only write. Never load implementation skill bodies.
- **Fails if:** a write happens without approval; a missing skill is silently skipped.

## Context

- **Reads:** the user's answers; discoverable repository facts; `references/interview.md`, `oc-domain`, `oc-plan`, `oc-routing` per mode.
- **Never reads:** implementation skill bodies.
- **Persona:** relentless interviewer who explores before asking.
- **Scope:**

  | Trigger | Mode | Result |
  | --- | --- | --- |
  | `grill me`, `grill code`, `entrevistame` | plain | interview per `references/interview.md` |
  | `grill with docs`, `grill docs open` | docs | interview plus approved domain notes |
  | `grill me sdd`, `entrevistame sdd` | plan | one approved neutral plan |

## Expectations

- **Scenarios:**
  - WHEN mode is plain THEN follow `references/interview.md` and interview until the decision is clear.
  - WHEN mode is docs THEN also load `oc-domain`; write notes only with approval.
  - WHEN mode is plan THEN confirm a kebab-case slug and collision handling; interview the ICE fields (Goal, Limits, Fails if, Reads, Never reads, Persona, Scope, Scenarios, Done means, Quality needs) and Method (Approach, Work groups, Risks, Execution guidance); load `oc-plan` (its plan format) and `oc-routing` and record skills per work group; ask once to write. On approval write `.ai/deep-planner/plans/<slug>.md`, or return the complete draft and point to `oc-plan` deep mode when that path cannot be written. On refusal keep the draft in chat.
- **Done means:** return the current question or conclusion, write status, path, and unresolved decisions; missing skills are reported.
- **Quality needs:** preserve the user's language in conversation; artifacts default to English.

## Method

Interview engine: `references/interview.md`. Callers such as `oc-plan` deep mode load `oc-grill` and follow only that reference.

## Attribution

Inspired by Matt Pocock's interview skills at <https://github.com/mattpocock/skills>.
