---
name: sdd-draft-proposal
description: "Trigger: draft proposal, borrador de propuesta, SDD proposal interview. Interview, then draft an OpenSpec proposal.md; plan-only, write on approval."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "2.0.0"
---

## Activation Contract

Use when drafting an OpenSpec `proposal.md` through interview-first SDD planning, either standalone or delegated by `grill`.

## Hard Rules

- Follow the `grilling` skill: one question at a time, recommendation attached, stop and wait; explore discoverable answers instead of asking.
- Follow the `native-question-ux` skill for question presentation; ask one question at a time and stop after each answer.
- Interview/summaries/gates use the user's language; artifacts default to English unless Spanish artifacts are explicitly requested.
- Plan-only: read-only codebase access; no code edits, builds, installs, tests, or state-changing commands. Only write planning `.md` files after explicit approval.
- When delegated by grill, return the approved draft and do not write files; the orchestrator owns the single write step.

## Decision Gates

| Situation | Action |
| --- | --- |
| Standalone and no change name | Propose a kebab-case, verb-led name and confirm. |
| Answer is discoverable from repo/docs | Explore read-only instead of asking. |
| Scope or capability list changes | Restate the new scope/capability binding and reconfirm. |
| Proposal exceeds 450 words | Compress before approval. |

## Execution Steps

1. Load the template in `assets/proposal-template.md` and relevant prompts from `references/question-bank.md`.
2. Interview for problem, users, business rules, scope, risks, success, and capability binding.
3. Draft `proposal.md` with New/Modified Capabilities as the spec contract.
4. Present the draft for approval; revise until approved.
5. If standalone and approved, ask before writing under `.orchestraitor/changes/{change-name}/proposal.md`.

## Output Contract

Return change name, approved/unapproved status, proposal draft, capability binding, write recommendation, and open questions. If a referenced skill cannot be resolved by name in the current runtime, say so instead of silently continuing.

## References

- `assets/proposal-template.md`
- `references/question-bank.md`
- `grilling` skill
- `native-question-ux` skill

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; adapted for OpenSpec proposal drafting.
