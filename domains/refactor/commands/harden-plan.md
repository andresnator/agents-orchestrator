---
description: "Generate ready-for-sdd OpenSpec hardening bundle(s) — characterization, coverage, and mutation safety net — for a class, package, or module."
agent: refactor-planner
subtask: false
argument-hint: "[target class, package, or module path]"
---
You are running `/harden-plan` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `refactor-planner` using the exact raw arguments above, with plan kind `hardening`.

Hard constraints:

- This is a plan-only workflow: do not modify production code, tests, or build files.
- The first non-flag argument is the hardening target.
- Allowed runtime write path: `.ai/refactor-planner/changes/**` only.
- Output: one or more OpenSpec change bundles (`proposal.md`, `design.md`, `specs/<capability>/spec.md`, `tasks.md`) conforming to the `sdd-draft-*` templates, with a `harden-` prefixed change name.
- `proposal.md` must start with `Status: ready-for-sdd | Source: refactor-planner`; execution happens later through orchestraitor adoption ("ejecuta el plan <change>").
- Always run the `behavior-safety`, `test-safety-net`, and `tooling` lenses; never run the other lenses.
- Inspect test readiness: verify in the build files that a test framework, coverage reporter (e.g. JaCoCo), and mutation tool (e.g. PIT) are configured; each missing piece becomes an explicit group-1 enablement task with its verify command.
- Coverage and mutation thresholds come from the kickoff round and are recorded in `design.md` and on the group-4 baseline tasks.
- Every finding must have `file:line` evidence, or be explicitly marked as a hypothesis.
- Tasks build the safety net only — tooling enablement, minimal behavior-preserving seams, characterization and unit tests, baseline runs — and never restructure; refactors go to Scope Out with the hint to run `/refactor-plan` after archive.
