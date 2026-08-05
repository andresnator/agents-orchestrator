---
description: "Generate ready-for-sdd OpenSpec refactor change bundle(s) for a class, package, or module."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Explicit SDLC route: `refactor / refactor`. Route directly through `sdlc-orchestrator` to `refactor-planner` with `operation: refactor`, preserving the raw arguments and constraints below; do not show the optional route menu.

Hard constraints:

- This is a plan-only workflow: do not modify production code, tests, or build files.
- The first non-flag argument is the refactor target.
- Allowed runtime write path: `.ai/refactor-planner/changes/**` only.
- Output: one or more OpenSpec change bundles (`proposal.md`, `design.md`, `specs/<capability>/spec.md`, `tasks.md`) conforming to the `sdd-draft-*` templates.
- `proposal.md` must start with `Status: ready-for-sdd | Source: refactor-planner`; execution happens later through orchestraitor adoption ("ejecuta el plan <change>").
- Run risk-gated analysis depth with parallel `refactor-analyzer` fan-out.
- Every finding must have `file:line` evidence, or be explicitly marked as a hypothesis.
- Tasks must be small, ordered, verifiable, behavior-preserving, and sized for sdd implementation waves; behavior changes go to Scope Out, never to `tasks.md`.
