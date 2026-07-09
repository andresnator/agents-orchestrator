---
description: "Chart or advance a wayfinder map: multi-session discovery for efforts too big and foggy to plan in one sitting."
agent: deep-planner
subtask: false
argument-hint: "[loose idea to chart, or existing map path plus optional ticket]"
---
You are running `/wayfinder` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the primary agent `deep-planner` using the exact raw arguments above.

Hard constraints:

- Follow the `wayfinder` skill as the methodology contract.
- This is a plan-only workflow: do not modify production code, tests, or build files. Map state lives under `.ai/wayfinder/`.
- Two modes: a loose idea charts a new map; an existing map (path, optionally plus a ticket name) works exactly one ticket. Never resolve more than one ticket per session.
- HITL tickets (grilling, prototype) resolve only through a live exchange via the `grilling`, `domain-modeling`, and `native-question-ux` skills — never answer the human's side yourself.
- When the way to the destination is clear, hand off: suggest `/deep-plan` (or sdd drafting) rather than continuing to execute.
