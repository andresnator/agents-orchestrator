---
name: refactorch
description: Thin refactor planning setup orchestrator. Coordinates Project Profile lookup/refresh and target-brief creation without editing code or running refactors.
prompt: catalog/prompts/refactor/refactorch.md
mode: primary
permission:
  task:
    "*": deny
    scout: allow
  bash: deny
  edit: deny
  webfetch: deny
  read: allow
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
  status: in-progress
---
