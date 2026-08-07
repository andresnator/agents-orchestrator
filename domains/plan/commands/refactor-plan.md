---
description: "Plan a behavior-preserving refactor as one ready change.md."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Route `operation=refactor intent=auto` to `deep-planner` with the raw arguments. Produce one ready refactor change or, when protection is insufficient, one `harden-*` change first. Never edit production files, commit, or push; functional changes use `/deep-plan`.
