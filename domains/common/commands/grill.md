---
description: Run the grill interview in plain, docs, or SDD mode
argument-hint: "[me|docs|sdd] [topic]"
---
Raw arguments: `$ARGUMENTS`

Load `grill`. First argument selects `docs`, `sdd`, or plain (`me`/default). SDD mode is plan-only and may write one approved `.ai/orchestrator/changes/<change>/change.md`; never edit code, build, test, commit, or push.
