---
name: behavior-characterization
description: "Trigger: behavior characterization, observable behavior. Record what legacy code does today."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

# Behavior Characterization
Detect what the system does today without judging whether it is ideal.

## Observable signals

- Return values.
- Exceptions and error codes.
- Side effects and state changes.
- Persistence writes/reads.
- Published events.
- Relevant logs.
- External calls.
- Edge conditions and branch behavior.
- Implicit business rules.

Every behavior claim needs code evidence or must be marked as a hypothesis.
