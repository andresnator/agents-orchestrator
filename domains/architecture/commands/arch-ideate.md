---
description: "Question-driven architecture refactor ideation producing an ADR plus a ready-for-sdd OpenSpec bundle."
agent: architect
subtask: false
argument-hint: "[architecture concern or target]"
---
You are running `/arch-ideate` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `architect` in `ideate` mode using the exact raw arguments above.

Hard constraints:

- Load the `architecture-ideation` skill and follow it: verified current state in, 2-3 candidate target architectures with trade-offs, question rounds via `native-question-ux`, incremental migration only.
- Outputs: an ADR under `<docfolder>/architecture/adr/` (via the `adr` skill) plus one OpenSpec bundle under `.ai/architect/changes/<change>/` conforming to the `sdd-draft-*` templates.
- `proposal.md` must start with `Status: ready-for-sdd | Source: architect`; never write the Mode/TDD/Judgment line — execution happens later through orchestraitor adoption ("ejecuta el plan <change>").
- `tasks.md` group 1 establishes fitness-function guardrails; every task is small, ordered `- [ ] X.Y`, names real files, and leaves the build green; test tasks honor `code-conventions`.
- Plan-only: no code, test, or build-file edits.
