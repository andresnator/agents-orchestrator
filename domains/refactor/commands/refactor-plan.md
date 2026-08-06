---
description: "Plan a behavior-preserving refactor as one ready change.md."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Route `refactor/refactor` to `refactor-planner` with the raw arguments. Plan only; write one `.ai/refactor-planner/changes/<change>/change.md`. Never edit code, tests, build files, commit, or push; functional changes stay out of scope.
