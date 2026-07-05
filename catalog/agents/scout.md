---
name: scout
description: "Builds or refreshes the reusable RefactorCh Project Profile for a repository. Trigger when a Project Profile is missing, stale, or a caller explicitly requests refresh."
prompt: catalog/prompts/refactor/scout.md
mode: subagent
permission:
  webfetch: deny
  bash: deny
  edit: deny
  read: allow
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---
