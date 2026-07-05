---
name: sdd-draft-spec
description: "Trigger: draft spec, borrador de spec, SDD delta spec interview. Interview, then draft delta specs with scenarios; plan-only, write on approval."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "1.0.3"
---

## Activation Contract

Use when drafting OpenSpec capability specs from an approved proposal or direct SDD behavior interview.

## Hard Rules

- Follow the `grilling` skill: one question at a time, recommendation attached, stop and wait; read discoverable proposal/spec context first.
- Follow the `native-question-ux` skill for question presentation; ask one question at a time and stop after each answer.
- Artifacts default to English; interview/summaries/gates use the user's language.
- Plan-only: read-only codebase access; no code edits, builds, installs, tests, or state changes. Only write planning `.md` files after explicit approval.
- One file per capability: `specs/{capability}/spec.md`. In `openspec/changes/`, new and modified capabilities both use delta sections; new behavior goes under ADDED Requirements.
- Requirements use RFC 2119; scenarios use WHEN/THEN. Describe WHAT, not HOW. Keep under 650 words per domain.
- When delegated by grill, return the approved draft and do not write files; the orchestrator owns the single write step.

## Decision Gates

| Situation | Action |
| --- | --- |
| Standalone and proposal exists on disk | Read it first. |
| No proposal | Interview directly or offer to run proposal drafting first. |
| Implementation detail appears | Park it as a design note; keep spec behavioral. |
| Existing requirement changes | Use MODIFIED and restate the whole requirement. |
| Requirement removed or renamed | Include Reason and Migration. |

## Execution Steps

1. Read `assets/delta-spec-template.md`, `assets/capability-spec-template.md`, `references/question-bank.md`, and `references/delta-semantics.md` as needed.
2. Build the capability list from proposal Capabilities or interview.
3. For each capability, draft an OpenSpec change delta; use ADDED for new capability behavior and MODIFIED only for replacement behavior.
4. Interview for observable requirements, scenarios, edge cases, removals, and renames.
5. Present each spec or batch for approval; revise until approved.
6. If standalone and approved, ask before writing `openspec/changes/{change-name}/specs/{capability}/spec.md`.

## Output Contract

Return approved/unapproved status, capability files, spec drafts, parked design notes, and open questions. If a referenced skill cannot be resolved by name in the current runtime, say so instead of silently continuing.

## References

- `assets/delta-spec-template.md`
- `assets/capability-spec-template.md`
- `references/question-bank.md`
- `references/delta-semantics.md`
- `grilling` skill
- `native-question-ux` skill

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; adapted for OpenSpec spec drafting.
