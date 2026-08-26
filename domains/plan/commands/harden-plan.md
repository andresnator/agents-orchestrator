---
description: "Plan only the safety net required before behavior-preserving restructuring."
agent: deep-planner
subtask: false
argument-hint: "[target class, package, or module path]"
---
Raw arguments: `$ARGUMENTS`

Run `operation=refactor intent=hardening` with the raw arguments. Write one ready `harden-*` `change.md`; exclude production restructuring. Never edit production files, commit, or push.
