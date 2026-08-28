---
description: Run the grill interview in plain, docs, or plan mode
argument-hint: "[me|docs|sdd] [topic]"
---
Raw arguments: `$ARGUMENTS`

Load `grill`. First argument selects `docs`, `sdd`, or plain (`me` or default). The literal `sdd` trigger selects neutral plan mode and may write one approved `.ai/deep-planner/plans/<slug>.md`; never edit code, build, test, commit, or push.
