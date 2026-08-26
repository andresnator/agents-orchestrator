---
description: "Run one bounded low-risk implementation through SDD Lite."
agent: orchestralite
subtask: false
argument-hint: "[bounded implementation request or active Lite change]"
---
Raw arguments: `$ARGUMENTS`

Run `operation=sdd-lite` with the raw arguments. Keep the change low risk and around five files or fewer; ask directly to switch to `/sdd` when scope, risk, or repeated failure exceeds the Lite gate. Never merge canonical specs, commit, or push.
