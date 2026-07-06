---
name: legacy-code-safety
description: "Trigger: legacy code safety, safe refactor. Make untested code safe to change."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

# Legacy Code Safety
Legacy code is code without a sufficient test safety net. The goal is not to make it beautiful first; the goal is to make it safe to change.

## Principles

- Capture current behavior before refactoring.
- Treat current observable behavior as the contract until explicitly changed.
- Search for seams before structural changes.
- Break dependencies minimally to enable characterization tests.
- Refactor incrementally in small, reversible steps.
- Separate behavior-preserving refactor from functional change.
- Validate after every step.
- Protect public contracts.
- Document rollback before implementation begins.
