---
description: "Choose a target architecture and produce an ADR plus one ready change.md."
agent: sdlc-orchestrator
subtask: false
argument-hint: "[architecture concern or target]"
---
Raw arguments: `$ARGUMENTS`

Route `architecture/ideate` to `architect`. Plan only: write one ADR under `<docfolder>/architecture/adr/` and one `.ai/architect/changes/<change>/change.md`; never edit code, tests, build files, commit, or push.
