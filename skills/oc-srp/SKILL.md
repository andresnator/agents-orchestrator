---
name: oc-srp
description: "Trigger: single responsibility, SRP, reasons to change. Detect classes or methods with multiple reasons to change."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Single Responsibility Lens

## Intent

- **Goal:** Recommend the smallest safe behavior-preserving refactor per material finding.
- **Limits:**
  - Identify separate business rules, orchestration, IO, mapping, validation, and formatting responsibilities.
  - Recommend Extract Class or Move Method only when cohesion improves.
  - Avoid splitting code merely because it is long.
  - Preserve observable behavior; label functional changes as follow-up.
  - Require evidence for every recommendation, or mark it as a hypothesis.
- **Fails if:** any Limit is broken.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** none
- **Persona:** single-lens refactor-plan reviewer.
- **Scope:** refactor-plan reviews of: single responsibility, SRP, reasons to change.

## Expectations

- **Scenarios:**
  - WHEN concrete evidence exists THEN report file, lines, symbol, benefit, validation, and rollback.
  - WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
  - WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- **Done means:** structured findings for the calling reviewer, or `no_findings` when nothing is material.
- **Quality needs:** one finding per material issue.
