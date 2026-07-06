---
description: "Generate one risk-gated OpenSpec-style refactor plan for a code class, package, or module."
agent: refactor-planner
subtask: false
argument-hint: "[target class, package, or module path]"
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.0.0"
  status: in-progress
---
You are running `/refactor-plan` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `refactor-planner` using the exact raw arguments above.

Hard constraints:

- This is a plan-only workflow: do not modify production code.
- The first non-flag argument is the refactor target.
- Allowed runtime write path: `.ia-refactor/plan/YYYYMMDD/<target-name>.md` only.
- Produce one Markdown document with the 17-section refactor-plan template.
- Run risk-gated depth selection: low -> light, medium -> standard, high/critical -> deep.
- Include the frozen `plan_target` lock, `Risk:`, `Depth:`, `## 15. Execution Contract`, and approved safety YAML before reporting completion.
- Every finding must have file/line/symbol evidence, or be explicitly marked as a hypothesis.
- Keep refactoring separate from functional behavior changes.
- Tasks must be small, ordered, verifiable, reversible, and safe for incremental execution.
- Do not propose speculative abstractions or cosmetic-only changes without maintainability value.
