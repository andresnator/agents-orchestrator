---
name: oc-types
description: "Trigger: type contracts, Object, Map<String,Object>, primitive obsession. Detect weak or implicit Java type contracts."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# oc-types

## Intent

- **Goal:** Weak or implicit Java type contracts made explicit.
- **Limits:**
  - Prefer value objects, enums, records, or typed DTOs when they clarify contracts.
  - Keep public API changes as follow-up unless approved.
  - Preserve observable behavior; label functional changes as follow-up.
- **Fails if:** a finding lacks evidence and is not marked hypothesis, or a public API change is proposed as in-scope without approval.

## Context

- **Reads:** target and nearby tests, as needed.
- **Never reads:** `none`.
- **Persona:** refactor reviewer.
- **Scope:** load when reviewing refactor plans for: type contracts, Object, Map<String,Object>, primitive obsession.

## Expectations

- **Scenarios:**
  - WHEN Object, raw types, Map<String,Object>, stringly typed values, magic strings, casts, or primitive obsession appear THEN flag them.
- **Done means:** findings in the calling contract's format (it wins); each has `file:line` evidence or is marked hypothesis; `no_findings` when nothing is material.
- **Quality needs:** note validation and rollback implications where material; the caller decides where they land.

## Method

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with `file:line` evidence and the smallest safe refactor. |
| Evidence is incomplete | Mark as hypothesis and lower confidence. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |
