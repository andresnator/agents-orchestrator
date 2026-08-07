---
description: "Plan an executable change, decision, or roadmap from repository evidence."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[goal to plan, or: continúa el roadmap <goal>]"
---
Raw arguments: `$ARGUMENTS`

Route `operation=deep-plan intent=auto` to `deep-planner` with the raw arguments. Plan only; output one decision plan, one ready `change.md`, or one roadmap plus its next slice. Never edit production files, commit, or push.
