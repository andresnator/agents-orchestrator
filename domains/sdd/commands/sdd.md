---
description: "Run full SDD for a new request, ready handoff, or active change."
agent: orchestraitor
subtask: false
argument-hint: "[request | ready change.md path | active change root]"
---
Raw arguments: `$ARGUMENTS`

Choose exactly one operation from the raw arguments: `direct-sdd` for a new implementation request, `execute-handoff` for an exact ready `.ai/<producer>/changes/<change>/change.md`, or `resume` for an exact active change root. Ask directly when the operation or path is ambiguous. `Judgment: light|full` requires the Review domain; establish that `/judgment` is available before accepting it. Never copy a producer handoff, commit without `Delivery: commit-per-wave`, or push.
