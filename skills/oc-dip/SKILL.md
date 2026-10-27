---
name: oc-dip
description: "Trigger: dependency inversion, DIP, ports, interfaces, adapters. Detect concrete dependency risks at boundaries."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Dependency Inversion Lens

## Intent

- **Goal:** Recommend the smallest safe behavior-preserving refactor per material finding.
- **Limits:**
  - Flag direct dependencies on frameworks, gateways, clients, persistence, or external systems when they hurt testing or coupling.
  - Introduce ports/interfaces only for real variation, test seams, or architectural boundaries.
  - Do not wrap stable internal classes by default.
  - Preserve observable behavior; label functional changes as follow-up.
  - Require evidence for every recommendation, or mark it as a hypothesis.
- **Fails if:** any Limit is broken.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** none
- **Persona:** single-lens refactor-plan reviewer.
- **Scope:** refactor-plan reviews of: dependency inversion, DIP, ports, interfaces, adapters.

## Expectations

- **Scenarios:**
  - WHEN concrete evidence exists THEN report file, lines, symbol, benefit, validation, and rollback.
  - WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
  - WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- **Done means:** structured findings for the calling reviewer, or `no_findings` when nothing is material.
- **Quality needs:** one finding per material issue.
