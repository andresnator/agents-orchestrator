---
description: "Plan a behavior-preserving refactor as one ready change.md."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Route `plan/refactor` to `deep-planner` with the raw arguments. Plan only; write one `.ai/deep-planner/changes/<change>/change.md`. If behavioral protection is insufficient, produce the hardening handoff first. Never edit code, tests, build files, commit, or push; functional changes stay out of scope.
