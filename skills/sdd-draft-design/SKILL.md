---
name: sdd-draft-design
description: "Trigger: draft design, borrador de diseño, SDD design interview. Explore the codebase, interview, then draft design.md; plan-only, write on approval."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "2.1.2"
---

## Activation Contract

Use when drafting an OpenSpec `design.md` after proposal/spec context exists or when technical uncertainty must be resolved for SDD planning.

## Hard Rules

- MUST explore the real codebase read-only before technical questions or drafting; never guess architecture.
- Follow the `grilling` skill: one question at a time, recommendation attached, stop and wait; read code for technical answers when possible.
- Follow the `native-question-ux` skill for question presentation; ask one question at a time and stop after each answer.
- Artifacts default to English; interview/summaries/gates use the user's language.
- Plan-only: no code edits, builds, installs, tests, or state changes. Only write planning `.md` files after explicit approval.
- Standalone writes default to `.ai/orchestrator/changes/{change}/design.md`. A phase agent may receive a validated `.ai/{owner}/changes/{change}/design.md` target and writes only there.
- File Changes entries must name a real file path or `Create`. No code bodies. Enough precision for the implementer to execute without re-deciding. Keep under 800 words.
- When delegated by grill, return the approved draft and do not write files; the orchestrator owns the single write step.

## Decision Gates

| Situation | Action |
| --- | --- |
| Technical answer is in code | Read code, then answer; do not ask. |
| Multiple viable approaches | Present both with tradeoffs, recommend one, and record a Decision. |
| Design conflicts with proposal/spec | Surface the conflict and resolve before drafting. |
| Unknown remains after exploration | Put it in Open Questions; do not guess. |
| File path not found | Use `Create` only for new files; otherwise re-check. |

## Execution Steps

1. Read `assets/design-template.md` and `references/question-bank.md`.
2. Read proposal/specs if present.
3. Silently explore affected code, patterns, interfaces, and tests read-only.
4. Interview only for non-discoverable technical decisions.
5. Draft design with stack & conventions (language/tool versions with evidence, `code-conventions` deviations), approach, decisions, data flow, file changes, contracts, tests, rollout, and open questions.
6. Present for approval; revise until approved.
7. If standalone and approved, ask before writing `.ai/orchestrator/changes/{change-name}/design.md`. When loaded by a phase agent, use its validated owner-specific target.

## Output Contract

When the caller owns the write (standalone or delegated by grill): return approved/unapproved status, design draft, explored evidence, decisions, unresolved questions, and write recommendation. When loaded by a phase agent that writes the artifact itself: the drafting rules and template above apply, and the return is the caller's own output contract — never the full artifact. If a referenced skill cannot be resolved by name in the current runtime, say so instead of silently continuing.

## References

- `assets/design-template.md`
- `references/question-bank.md`
- `grilling` skill
- `native-question-ux` skill

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; adapted for OpenSpec design drafting.
