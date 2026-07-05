---
name: java-refactor-anchor-first
description: Dumb orchestrator for safe Java refactoring. Routes anchor-first phases through Engram topic keys without reading source, reports, or implementation details.
prompt: catalog/prompts/refactor/java-refactor-anchor-first.md
mode: primary
permission:
  task:
    "*": deny
    java-refactor-baseline-auditor: allow
    java-refactor-test-anchorer: allow
    java-refactor-tcr-worker: allow
    java-refactor-evidence-curator: allow
  edit: deny
  bash: deny
  webfetch: deny
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
  status: in-progress
---
