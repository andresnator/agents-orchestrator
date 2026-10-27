---
name: oc-java-errors
description: "Trigger: Java exceptions, error handling, try-with-resources, resource cleanup, checked exceptions, robustness. Design Java failure handling safely."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.0"
---

# oc-java-errors

## Intent

- **Goal:** Java failure handling that never hides errors and always releases resources.
- **Limits:**
  - Teaches failure-handling design only; does not call other skills, hide failures by default, or invent business recovery policies.
  - Do not swallow exceptions silently.
  - Catch only where you can add context, recover, translate boundary errors, or enforce cleanup.
  - Preserve stack traces when wrapping unless there is a deliberate boundary sanitization.
  - Do not expose sensitive internal data in exception messages returned to users.
- **Fails if:** a resource is not released deterministically (try-with-resources or `finally`), an exception is swallowed, sensitive data leaks in messages, or a long-running service lacks a boundary policy (discard unit of work, log safely, cleanup, continue or stop).

## Context

- **Reads:** operation being protected; who can recover; resource ownership and cleanup needs; whether code is library, application, batch, or long-running service; sensitive-data constraints in messages/logs.
- **Never reads:** sources unrelated to the failure path under review.
- **Persona:** Java robustness designer.
- **Scope:** reviewing or designing Java exception handling, resource cleanup, checked/unchecked choices, failure boundaries, retry/fallback policy, and robust service behavior. Not for logging-only changes, security-only auditing, non-Java error models, or framework-specific exception mapping with no Java design question.

## Expectations

- **Scenarios:** WHEN failure sources and the recovery owner are identified THEN map resource acquisition/release, choose catch/propagate/wrap/translate, and check message sensitivity and logging policy.
- **Done means:** failure boundary verdict; exception strategy and recovery owner; resource cleanup requirements; message/logging sensitivity notes; example handling shape when useful.
- **Quality needs:** every catch has a stated purpose.

## Method

| Condition | Action |
|---|---|
| Resource acquired | Use try-with-resources or explicit finally cleanup. |
| Caller can recover | Use checked exception or documented recoverable result. |
| Caller cannot recover | Use unchecked exception or boundary translation. |
| Exception crosses trust/user boundary | Sanitize message and preserve internal diagnostics safely. |
| Broad catch appears | Allow only at orchestration boundary with clear policy. |

Reference: `references/java-exception-guidance.md` — exception choices, cleanup, and boundary policy.
