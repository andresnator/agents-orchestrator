---
name: refactor-java
description: >
  Java-specific refactor quality gate and compatibility contract for anchor-first refactor workers.
  Trigger: Java refactor workers need behavior-preserving refactor guidance or a Java Refactor Quality Gate.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

## Contract

Use this skill before Java refactor edits. It is a compact Java-specific compatibility contract for workers that need a named `refactor-java` skill. It may be combined with broader refactor, Java clean-code, testing, API, exception, immutability, and design skills, but this skill owns the consolidated Java Refactor Quality Gate verdict.

## Hard Rules

- Preserve observable behavior; do not mix bug fixes with refactoring.
- Keep each slice small enough to review and revert.
- Prefer existing project idioms, Java version constraints, build tools, and test frameworks.
- Protect public APIs, serialization contracts, visibility, exception behavior, and mutability expectations unless an explicit approved migration says otherwise.
- Add or keep JavaDoc only for non-obvious intent, contracts, invariants, edge cases, or public API expectations.
- Reject mechanical abstractions, pattern shopping, formatting-only churn, and broad cleanup outside the selected slice.

## Java Refactor Quality Gate

Every attempted or completed slice records one verdict:

```yaml
quality_gate:
  behavior_preservation: pass | fail | waived
  readability: pass | fail | waived
  cohesion: pass | fail | waived
  solid_restraint: pass | fail | waived
  pragmatic_patterns: pass | fail | waived
  api_compatibility: pass | fail | waived
  exception_robustness: pass | fail | waived
  immutability_modeling: pass | fail | waived
  javadoc_usefulness: pass | fail | waived
```

`waived` requires an explicit human or caller decision and a reason. A review-size exception never waives behavior preservation, verification, or this quality gate.

## Evidence

Record the technique used, files changed, verification command status, API or behavior risks, JavaDoc decision, rollback instruction, and one next action. Keep evidence compact and refer to artifacts by path or topic key instead of copying diffs or logs.
