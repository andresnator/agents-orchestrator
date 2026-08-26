---
description: "Capture a foggy multi-session effort in one durable discovery plan."
agent: deep-planner
subtask: false
argument-hint: "[loose idea, or exact discovery plan path]"
---
Raw arguments: `$ARGUMENTS`

Run `operation=deep-plan intent=discovery` with the raw arguments. Create or update one exact `.ai/deep-planner/plans/<slug>.md`; never implement or create a ready handoff. Ask open discovery questions directly in normal chat; reserve the `question` tool for closed choices. When clear, recommend `/deep-plan` as the next step.
