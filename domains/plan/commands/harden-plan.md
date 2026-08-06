---
description: "Plan characterization, coverage, and mutation safety as one ready change.md."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Route `plan/hardening` to `deep-planner` with the raw arguments. Plan only; write one `harden-*` `change.md` under `.ai/deep-planner/changes/`. Never edit code, tests, build files, commit, or push; production refactors stay out of scope.
