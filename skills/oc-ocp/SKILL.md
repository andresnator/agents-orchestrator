---
name: oc-ocp
description: "Trigger: open closed principle, OCP, strategy, policy, polymorphism. Detect extension pressure without speculative patterns."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Open-Closed Lens

## Intent

- **Goal:** Recommend the smallest safe behavior-preserving refactor per material finding.
- **Limits:**
  - Look for repeated conditionals by type, state, operation, or strategy.
  - Suggest strategy, policy, or polymorphism only when new variants are likely or already present.
  - Block pattern use when a simple conditional is clearer.
  - Preserve observable behavior; label functional changes as follow-up.
  - Require evidence for every recommendation, or mark it as a hypothesis.
- **Fails if:** any Limit is broken.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** none
- **Persona:** single-lens refactor-plan reviewer.
- **Scope:** refactor-plan reviews of: open closed principle, OCP, strategy, policy, polymorphism.

## Expectations

- **Scenarios:**
  - WHEN concrete evidence exists THEN report file, lines, symbol, benefit, validation, and rollback.
  - WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
  - WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- **Done means:** structured findings for the calling reviewer, or `no_findings` when nothing is material.
- **Quality needs:** one finding per material issue.
