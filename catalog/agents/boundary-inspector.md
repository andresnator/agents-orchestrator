---
name: boundary-inspector
description: Inspects backend service inputs and outputs with evidence and confidence. Read-only static analysis; no edits, runtime execution, shell, or web access.
prompt: catalog/prompts/engineering/boundary-inspector-agent.md
mode: subagent
permission:
  edit: deny
  bash: deny
  webfetch: deny
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---
