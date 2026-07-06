---
name: safe-refactor-planning
description: "Trigger: safe refactor planning, behavior-preserving refactor. Plan reversible refactor steps."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

# Safe Refactor Planning
Plan behavior-preserving changes in small, reversible steps.

## Prefer

- Dependency breaking before extraction when tests require it.
- Characterization tests before extract method/class.
- Extract method, extract class, introduce interface, move method, parameter object, wrappers/adapters, sprout method, and sprout class.
- Separate phases and small commits.

## Prohibit

- Big-bang refactors.
- Mixed functional and refactor changes.
- Public API changes without explicit approval.
- Database schema changes inside the same refactor.
- Full rewrites without a prior safety plan.
