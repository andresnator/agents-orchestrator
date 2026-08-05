---
name: sdd-draft-light
description: "Trigger: draft light change, SDD light depth, cambio SDD ligero. Draft a single change.md (Why/What + Spec Deltas + Tasks) for bounded light-depth SDD changes."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.0.1"
---

## Activation Contract

Use when drafting the single `change.md` artifact for an SDD change whose kickoff recorded `Depth: light`. Loaded by the sdd `sdd-proposal` agent in light mode; the interview and decisions already happened in the `orchestraitor` and arrive in the brief as binding.

## Hard Rules

- One artifact: `.ai/orchestrator/changes/{change}/change.md`. No `proposal.md`, `design.md`, delta files, or `tasks.md` at light depth.
- The first line is the kickoff line: `Mode: … | TDD: … | Judgment: … | Depth: light | Delivery: …`.
- Keep under 800 words total: roughly 150 for Why / What, 450 for Spec Deltas, 200 for Tasks.
- Spec Deltas use the same semantics as `sdd-draft-spec` delta files: requirements use RFC 2119, scenarios use WHEN/THEN, MODIFIED restates the full replacement requirement, REMOVED and RENAMED carry Reason and Migration. Describe WHAT, not HOW. New capability behavior goes under ADDED. Omit empty ADDED/MODIFIED/REMOVED/RENAMED subsections.
- At archive, each capability block under `## Spec Deltas` merges into canonical `specs/{capability}/spec.md` exactly like a delta file; never edit canonical specs while drafting.
- Tasks are small, dependency-ordered `- [ ] X.Y` checkboxes naming real files; testing tasks reference a Spec Deltas scenario. Light depth always executes as one sequential implementation wave. Put one aggregate `Files:` scope line immediately under `## Tasks`; do not create task-group headings or parallel scheduling metadata.
- Artifacts default to English; summaries and gates use the user's language.

## Decision Gates

| Situation | Action |
| --- | --- |
| Draft reveals >~400 estimated changed lines, a sprawling new capability, or cross-cutting risk | Write the draft anyway and report the oversized scope as an open question; upgrading to full depth is the orchestraitor's call, not the drafting agent's. |
| Capability has no canonical spec | Put all its behavior under ADDED Requirements. |
| Implementation detail appears in a delta | Move it to a task; keep deltas behavioral. |

## Execution Steps

1. Read `assets/change-template.md`.
2. Draft `## Why / What` from the request and kickoff decisions: problem, gap, observable outcome, scope boundaries.
3. Draft `## Spec Deltas` with one `### Delta for {capability}` block per touched capability, reading canonical specs first when they exist.
4. Draft `## Tasks` as one dependency-ordered checklist consistent with the deltas, preceded by its aggregate `Files:` scope.
5. Check the upgrade gate and the word cap, then write the file.

## Output Contract

The `change.md` file written at its target path, plus open questions. The loading agent owns the write; the orchestraitor owns the confirmation gate and never receives the artifact body — only the drafting agent's receipt.

## References

- `assets/change-template.md`
- `sdd-draft-spec` skill (delta semantics)
