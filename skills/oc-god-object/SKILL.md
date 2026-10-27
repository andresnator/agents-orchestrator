---
name: oc-god-object
description: "Trigger: God Object, Large Class, too many collaborators. Detect oversized objects with too many responsibilities."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# God Object Lens

## Intent

- **Goal:** Recommend the smallest safe behavior-preserving refactor per material finding.
- **Limits:**
  - Look for many unrelated methods, many collaborators, broad state ownership, and mixed domain concepts.
  - Recommend incremental extraction by cohesive responsibility.
  - Require characterization tests before risky legacy extractions.
  - Preserve observable behavior; label functional changes as follow-up.
  - Require evidence for every recommendation, or mark it as a hypothesis.
- **Fails if:** any Limit is broken.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** none
- **Persona:** single-lens refactor-plan reviewer.
- **Scope:** refactor-plan reviews of: God Object, Large Class, too many collaborators.

## Expectations

- **Scenarios:**
  - WHEN concrete evidence exists THEN report file, lines, symbol, benefit, validation, and rollback.
  - WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
  - WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- **Done means:** structured findings for the calling reviewer, or `no_findings` when nothing is material.
- **Quality needs:** one finding per material issue.
