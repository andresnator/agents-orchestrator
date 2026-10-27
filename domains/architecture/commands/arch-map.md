---
description: "Generate or refresh evidence-backed C4-lite architecture docs."
agent: orchestraitor
subtask: false
argument-hint: "[optional subpath or focus]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-arch` and run `operation=map`. Write only `<docfolder>/architecture/**`; refresh in place. No source edits, commit, push.
