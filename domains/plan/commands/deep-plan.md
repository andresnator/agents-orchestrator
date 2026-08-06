---
description: "Plan a feature, change, or decision with evidence, producing one ready change.md, a roadmap slice, or a decision plan."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[goal to plan, or: continúa el roadmap <goal>]"
---
Raw arguments: `$ARGUMENTS`

Route `plan/deep-plan` to `deep-planner` with the raw arguments. Plan only: writes stay under `.ai/deep-planner/{changes,plans}/` or `.ai/roadmaps/`; never edit code, tests, build files, commit, or push. Executable output is one ready `change.md`; oversized work plans only the next unblocked slice.
