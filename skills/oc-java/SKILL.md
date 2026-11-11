---
name: oc-java
description: "Trigger: Java tests, JUnit, Mockito, AssertJ, Java legacy tests, Java characterization tests, Java seams, Java API design, public API, encapsulation, modules, visibility, contracts, binary compatibility, Java exceptions, error handling, try-with-resources, resource cleanup, checked exceptions, robustness, Java immutability, records, value objects, defensive copies, mutable collections, DTO modeling, Java secure coding, Oracle Secure Coding Guidelines, input validation, trust boundaries, deserialization, least privilege, sensitive data, null safety, nullability, Optional, NPE, type contracts, Object, Map<String,Object>, primitive obsession. Java router: tests, API boundaries, failure handling, immutability, secure coding, null safety, and type contracts; planning the scope and protection of a legacy change belongs to oc-refactor."
license: MIT
metadata:
  author: andresnator
  version: "6.0.0"
  status: testing
---

# Java

## Intent

- **Goal:** Write or review Java code and tests that follow the owner's rules below and the project stack.
- **Limits:** Preserve observable behavior. Label functional changes as follow-up. Do not add or upgrade JUnit, Mockito, AssertJ, PowerMock, or ApprovalTests unless the current stack cannot support the test. State the tradeoff.
- **Fails if:** a finding has no `file:line` evidence and no `hypothesis` mark; legacy code changes before a safety test exists; a dependency-breaking seam is not named as Sensing (to observe effects) or Separation (to run code in a test).

## Context

- **Reads:** the code under change; Java version, build tool, and test stack (detect each one independently); `oc-conventions`.
- **Never reads:** non-Java code.
- **Persona:** Java engineer who follows *Working Effectively with Legacy Code*.
- **Scope:** Java code only. Planning a legacy change belongs to `oc-refactor`.

## Expectations

- **Scenarios:**
  - WHEN a caller supplies its own findings format THEN that format wins.
  - WHEN legacy code has no tests THEN use Cover, then Modify, then Refactor.
  - WHEN a recommendation changes a public API THEN flag the compatibility risk.
- **Done means:** the route used; the detected stack; files changed or proposed; behaviors and edge cases covered; seam tradeoffs; the validation command.
- **Quality needs:** each recommendation ties to evidence, a consumer need, or a compatibility concern.

## Method

Owner rules (`oc-conventions` owns the general test style):

- Put tests under `src/test/java/` in the same package as the source.
- Name test classes `{ClassName}Test`.
- Put characterization tests in a permanent `{ClassName}CharacterizationTest` class.
- Use Mockito only across real boundaries. Use Spring context tests only when framework behavior is the subject.
- Use `@InjectMocks` only when constructor setup adds noise.
- Use `ArgumentCaptor` only when the passed object is the behavior under test.
- Make DTOs and helper types top-level classes, never nested.
- Review an ApprovalTests baseline before you approve it. A bad baseline freezes bugs.
- Keep a stack trace when you wrap an exception, except at a deliberate sanitization boundary.
