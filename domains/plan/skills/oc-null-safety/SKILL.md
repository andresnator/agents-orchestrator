---
name: oc-null-safety
description: "Trigger: null safety, nullability, Optional, NPE. Detect null hazards and conservative Java null-safety refactors."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# oc-null-safety

## Intent

- **Goal:** Null hazards found and fixed with conservative Java null-safety refactors.
- **Limits:**
  - Prefer boundary checks, NonNull annotations where used, clear defaults, or Null Object only when justified.
  - Do not introduce Optional in fields, parameters, or DTOs without explicit reason.
  - Preserve observable behavior; label functional changes as follow-up.
- **Fails if:** a finding lacks evidence and is not marked hypothesis.

## Context

- **Reads:** the target and nearby tests, as needed.
- **Never reads:** `none`.
- **Persona:** Java refactor reviewer.
- **Scope:** load when reviewing refactor plans for: null safety, nullability, Optional, NPE.

## Expectations

- **Scenarios:**
  - WHEN a dereference lacks a clear guarantee, a return is nullable, or null semantics are ambiguous THEN flag it with evidence.
- **Done means:** findings in the calling contract's format (it wins); each has `file:line` evidence or is marked hypothesis; `no_findings` when nothing is material.
- **Quality needs:** note validation and rollback implications where material; the caller decides where they land.

## Method

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with `file:line` evidence and the smallest safe refactor. |
| Evidence is incomplete | Mark as hypothesis and lower confidence. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |
