---
name: architecture-impact-review
description: "Trigger: architecture impact review, layer boundaries. Decide whether legacy risk is local or architectural."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

# Architecture Impact Review
Decide whether the target problem is local or architectural.

## Look for

- Layer violations.
- Domain logic mixed with infrastructure.
- Business logic in controllers, repositories, or DTOs.
- Circular dependencies.
- Coupled modules.
- God classes and services with too many responsibilities.
- Hidden business rules.
- Boundary-crossing dependencies.

Keep broad architectural cleanup as follow-up unless it is required for safe characterization.
