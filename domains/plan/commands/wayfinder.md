---
description: "Chart or advance a multi-session map for an effort too foggy to plan now."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[loose idea, or existing map plus optional ticket]"
---
Raw arguments: `$ARGUMENTS`

Route `plan/wayfinder` to `deep-planner` with the raw arguments. Write only `.ai/wayfinder/**`; resolve at most one human decision this session and never implement. When clear, route to `/deep-plan`.
