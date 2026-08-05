---
description: "Question-driven architecture refactor ideation producing an ADR plus a ready-for-sdd OpenSpec bundle."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[architecture concern or target]"
---
Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `architecture / ideate`. Route directly through `sdlc-orchestrator` to `architect` with `operation: ideate`, preserving the raw arguments and constraints below; do not show the optional route menu.

Hard constraints:

- Load the `architecture-ideation` skill and follow it: verified current state in, 2-3 candidate target architectures with trade-offs, question rounds via `native-question-ux`, incremental migration only.
- Outputs: an ADR under `<docfolder>/architecture/adr/` (via the `adr` skill) plus one OpenSpec bundle under `.ai/architect/changes/<change>/` conforming to the `sdd-draft-*` templates.
- `proposal.md` must start with `Status: ready-for-sdd | Source: architect`; never write the Mode/TDD/Judgment line — execution happens later through orchestraitor adoption ("ejecuta el plan <change>").
- `tasks.md` group 1 establishes fitness-function guardrails; every task is small, ordered `- [ ] X.Y`, names real files, and leaves the build green; test tasks honor `code-conventions`.
- Plan-only: no code, test, or build-file edits.
