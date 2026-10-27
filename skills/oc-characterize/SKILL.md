---
name: oc-characterize
description: "Trigger: behavior characterization, observable behavior. Record what legacy code does today."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Behavior Characterization

## Intent

- **Goal:** Record what the code does today, not what it should do.
- **Limits:** Characterize only the zone the plan touches. Never fix a found bug in the same step.
- **Fails if:** A claim lacks code evidence and is not marked hypothesis, or a test asserts desired behavior.

## Context

- **Reads:** observable signals: returns, exceptions/error codes, side effects/state, persistence reads/writes, events, logs, external calls, edge branches, implicit rules.
- **Never reads:** Desired behavior as evidence.
- **Persona:** Neutral observer.
- **Scope:** Characterizing legacy code before changing it.

## Expectations

- **Scenarios:**
  - WHEN characterizing a value THEN write a failing assertion, run it, and anchor the actual value from the failure message.
  - WHEN a bug appears THEN anchor today's wrong output, record the bug, finish the net, and schedule the fix as a follow-up behavior change.
- **Done means:** Touched-zone behavior anchored by tests, evidence, or hypothesis.
- **Quality needs:** none beyond evidence rules.
