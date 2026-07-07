---
description: "Generate ready-for-sdd OpenSpec refactor change bundle(s) for a class, package, or module."
agent: refactor-planner
subtask: false
argument-hint: "[target class, package, or module path]"
---
You are running `/refactor-plan` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `refactor-planner` using the exact raw arguments above.

Hard constraints:

- This is a plan-only workflow: do not modify production code, tests, or build files.
- The first non-flag argument is the refactor target.
- Allowed runtime write path: `.ai/refactor-planner/changes/**` only.
- Output: one or more OpenSpec change bundles (`proposal.md`, `design.md`, `specs/<capability>/spec.md`, `tasks.md`) conforming to the `sdd-draft-*` templates.
- `proposal.md` must start with `Status: ready-for-sdd | Source: refactor-planner`; execution happens later through orchestraitor adoption ("ejecuta el plan <change>").
- Run risk-gated analysis depth with parallel `refactor-analyzer` fan-out.
- Every finding must have `file:line` evidence, or be explicitly marked as a hypothesis.
- Tasks must be small, ordered, verifiable, behavior-preserving, and sized for sdd implementation waves; behavior changes go to Scope Out, never to `tasks.md`.
