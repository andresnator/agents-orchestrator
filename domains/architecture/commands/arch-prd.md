---
description: "Reverse-engineer an evidence-backed PRD from the codebase."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[optional product/feature scope]"
---
Raw arguments: `$ARGUMENTS`

Route `architecture/prd` to `architect`. Infer behavior from code and ask about unknown intent; write only `<docfolder>/architecture/**`. Never edit code, tests, build files, commit, or push.
