---
description: "Execute an approved refactor plan task-by-task with TCR commits and deviation logging."
agent: refactor-executor
subtask: false
argument-hint: "[plan path | empty = latest]"
license: Apache-2.0
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---
You are running `/refactor-execute` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `refactor-executor` using the exact raw arguments above.

Hard constraints:

- Execute only an approved 17-section `/refactor-plan` artifact.
- If no plan path is provided, resolve the most recent `.ia-refactor/plan/*/*.md`.
- Reject smoke plans and plans whose Section 17 safety YAML is not approved.
- Treat Section 15 Execution Contract and Section 12 `tasks.md` as the execution boundary.
- Never improvise work outside the plan. Record drift or impossible tasks as deviations.
- Use TCR: green validation commits the task, red validation reverts the task.
- Write an execution report under `.ia-refactor/execute/YYYYMMDD/<target>-execution.md`.
