---
name: sdd-draft-light
description: "Trigger: draft light change, SDD light depth, cambio SDD ligero. Draft a single change.md (Why/What + Spec Deltas + Tasks) for bounded light-depth SDD changes."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.1.0"
---

## Activation Contract

Use when drafting the single `change.md` artifact for an SDD change whose kickoff recorded `Depth: light`. Loaded inline by the sdd `orchestraitor`; the interview and decisions already happened there. No drafting subagents are involved.

## Hard Rules

- One artifact: `.ai/orchestrator/changes/{change}/change.md`. No `proposal.md`, `design.md`, delta files, or `tasks.md` at light depth.
- The first line is the kickoff line: `Mode: … | TDD: … | Judgment: … | Depth: light | Delivery: …`.
- Keep under 800 words total: roughly 150 for Why / What, 450 for Spec Deltas, 200 for Tasks.
- Spec Deltas use the same semantics as `sdd-draft-spec` delta files: requirements use RFC 2119, scenarios use WHEN/THEN, MODIFIED restates the full replacement requirement, REMOVED and RENAMED carry Reason and Migration. Describe WHAT, not HOW. New capability behavior goes under ADDED. Omit empty ADDED/MODIFIED/REMOVED/RENAMED subsections.
- At archive, each capability block under `## Spec Deltas` merges into canonical `specs/{capability}/spec.md` exactly like a delta file; never edit canonical specs while drafting.
- Tasks are small, dependency-ordered `- [ ] X.Y` checkboxes naming real files, sized for `sdd-implement` waves; testing tasks reference a Spec Deltas scenario. A light change is normally one sequential group; only when tasks split into independent groups, give each a `### N. {group}` heading with a `Files:` scope line (directories/globs) so the orchestraitor can schedule parallel waves — groups without disjoint scopes serialize.
- Artifacts default to English; summaries and gates use the user's language.

## Decision Gates

| Situation | Action |
| --- | --- |
| Draft reveals >~400 estimated changed lines, a sprawling new capability, or cross-cutting risk | Stop and recommend upgrading to full depth; the draft becomes input to the `sdd-proposal` brief. |
| Capability has no canonical spec | Put all its behavior under ADDED Requirements. |
| Implementation detail appears in a delta | Move it to a task; keep deltas behavioral. |

## Execution Steps

1. Read `assets/change-template.md`.
2. Draft `## Why / What` from the request and kickoff decisions: problem, gap, observable outcome, scope boundaries.
3. Draft `## Spec Deltas` with one `### Delta for {capability}` block per touched capability, reading canonical specs first when they exist.
4. Draft `## Tasks` as a dependency-ordered checklist consistent with the deltas.
5. Check the upgrade gate and the word cap before presenting or writing.

## Output Contract

The drafted `change.md` content plus open questions. When loaded by the orchestraitor, the orchestraitor owns the write and the confirmation gate.

## References

- `assets/change-template.md`
- `sdd-draft-spec` skill (delta semantics)
