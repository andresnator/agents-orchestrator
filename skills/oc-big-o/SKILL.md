---
name: oc-big-o
description: "Trigger: complexity, Big O, cyclomatic, nested loops, queries in loops. Evaluate control and algorithmic complexity where it matters."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Algorithmic Complexity Lens

## Intent

- **Goal:** Recommend the smallest safe behavior-preserving refactor per material finding.
- **Limits:**
  - Flag high cyclomatic complexity, nested branches, loops, repeated scans, O(n²), and queries in loops.
  - Discuss Big O only when collections, algorithms, or repeated queries exist.
  - Avoid micro-optimizations without evidence; prioritize readability unless performance risk is real.
  - Preserve observable behavior; label functional changes as follow-up.
  - Require evidence for every recommendation, or mark it as a hypothesis.
- **Fails if:** any Limit is broken.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** none
- **Persona:** single-lens refactor-plan reviewer.
- **Scope:** refactor-plan reviews of: complexity, Big O, cyclomatic, nested loops, queries in loops.

## Expectations

- **Scenarios:**
  - WHEN concrete evidence exists THEN report file, lines, symbol, benefit, validation, and rollback.
  - WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
  - WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- **Done means:** structured findings for the calling reviewer, or `no_findings` when nothing is material.
- **Quality needs:** one finding per material issue.
