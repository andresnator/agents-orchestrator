---
description: "Plan a behavior-preserving refactor as one ready change.md."
agent: deep-planner
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Run `operation=refactor intent=auto` with the raw arguments. Produce one ready refactor change or, when protection is insufficient, one `harden-*` change first. Never edit production files, commit, or push; functional changes use `/deep-plan`.
