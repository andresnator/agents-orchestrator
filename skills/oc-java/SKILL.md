---
name: oc-java
description: "Trigger: Java tests, JUnit, Mockito, AssertJ, Java legacy tests, Java characterization tests, Java seams, Java API design, public API, encapsulation, modules, visibility, contracts, binary compatibility, Java exceptions, error handling, try-with-resources, resource cleanup, checked exceptions, robustness, Java immutability, records, value objects, defensive copies, mutable collections, DTO modeling, Java secure coding, Oracle Secure Coding Guidelines, input validation, trust boundaries, deserialization, least privilege, sensitive data, null safety, nullability, Optional, NPE, type contracts, Object, Map<String,Object>, primitive obsession. Java router: tests, API boundaries, failure handling, immutability, secure coding, null safety, and type contracts; planning the scope and protection of a legacy change belongs to oc-refactor."
license: MIT
metadata:
  author: andresnator
  version: "5.0.0"
  status: testing
  attribution: "null-safety and types references adapted from gentle-ai/plan-refactor (Apache-2.0)"
---

# Java

## Intent

- **Goal:** Apply the one Java topic the request needs, following its reference exactly.
- **Limits:** Load only the topic references the request matches; each reference's own Limits and output contract win. Preserve observable behavior; label functional changes as follow-up.
- **Fails if:** a topic is answered without its reference, or a finding lacks `file:line` evidence or a `hypothesis` mark.

## Context

- **Reads:** the matching `references/<topic>.md` and the files it names; Java version, build tool, and project conventions (`oc-conventions`).
- **Never reads:** references for topics the request does not touch.
- **Persona:** Java engineer.
- **Scope:** Java code only; non-Java work belongs elsewhere.

## Expectations

- **Scenarios:**
  - WHEN the request matches a topic below THEN follow that reference; WHEN several match THEN apply each, tests last.
  - WHEN a caller supplies its own findings format THEN that format wins.
- **Done means:** the matching reference's `Done means`.
- **Quality needs:** every recommendation ties to evidence, a consumer need, or a compatibility concern.

## Method

| Topic | Signals | Follow |
|---|---|---|
| test | JUnit, Mockito, AssertJ, characterization, seams, legacy tests | `references/test.md` (+ its references and `assets/examples/`) |
| api | public API, visibility, modules, contracts, binary compatibility | `references/api.md`, `references/java-api-boundaries.md` |
| errors | exceptions, try-with-resources, cleanup, robustness | `references/errors.md`, `references/java-exception-guidance.md` |
| immutable | records, value objects, defensive copies, DTOs | `references/immutable.md`, `references/java-immutability.md` |
| security | trust boundaries, input validation, deserialization, sensitive data | `references/security.md`, `references/java-secure-coding-guidance.md` |
| null-safety | nullability, Optional, NPE | `references/null-safety.md` |
| types | Object, raw types, `Map<String,Object>`, primitive obsession | `references/types.md` |
