---
name: risk-assessment
description: "Trigger: risk assessment, refactor risk. Classify technical and functional legacy risk."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

# Risk Assessment
Assess risk from technical and functional evidence.

## Signals

- Complexity and large methods/classes.
- Missing tests or low coverage.
- CRAP score when available.
- Fan-in/fan-out and number of consumers.
- External dependencies.
- Public contracts.
- Async behavior, transactions, persistence, and critical domain rules.
- Git churn when history is available.

Classify overall risk as low, medium, high, or critical and explain why.
