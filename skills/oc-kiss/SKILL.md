---
name: oc-kiss
description: "Trigger: KISS, YAGNI, overengineering, speculative abstraction. Keep refactor plans simple and non-speculative."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Simplicity Lens

## Intent

- **Goal:** Recommend the smallest safe behavior-preserving refactor per material finding.
- **Limits:**
  - Prefer explicit code until variation is proven.
  - Reject abstractions for hypothetical future cases.
  - Recommend deletion of unused speculative structure only when safe and validated.
  - Preserve observable behavior; label functional changes as follow-up.
  - Require evidence for every recommendation, or mark it as a hypothesis.
- **Fails if:** any Limit is broken or a finding lacks `file:line` evidence unmarked.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** none
- **Persona:** single-lens refactor-plan reviewer.
- **Scope:** refactor-plan reviews of: KISS, YAGNI, overengineering, speculative abstraction.

## Expectations

- **Scenarios:**
  - WHEN concrete evidence exists THEN report `file:line` evidence and the smallest safe refactor.
  - WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
  - WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- **Done means:** findings in the calling agent's output contract (that contract wins over any field list here); `no_findings` when nothing is material.
- **Quality needs:** note validation and rollback implications only where material, and the calling agent decides where they land.
