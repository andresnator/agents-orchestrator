---
description: "Plan only the safety net required before behavior-preserving restructuring."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Route `operation=refactor intent=hardening` to `deep-planner` with the raw arguments. Write one ready `harden-*` `change.md`; exclude production restructuring. Never edit production files, commit, or push.
