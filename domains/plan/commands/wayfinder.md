---
description: "Capture a foggy multi-session effort in one durable discovery plan."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[loose idea, or exact discovery plan path]"
---
Raw arguments: `$ARGUMENTS`

Route `operation=deep-plan intent=discovery` to `deep-planner` with the raw arguments. Create or update one exact `.ai/deep-planner/plans/<slug>.md`; never implement or create a ready handoff. When clear, return `next=plan`.
