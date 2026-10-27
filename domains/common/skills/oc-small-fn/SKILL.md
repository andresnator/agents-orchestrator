---
name: oc-small-fn
description: "Trigger: small functions, long method, extract method. Detect oversized functions and extractable blocks."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Small Functions

## Intent

- **Goal:** Find oversized functions and recommend the smallest safe behavior-preserving extraction.
- **Limits:** Stay behavior-preserving and incremental; label functional changes follow-up.
- **Fails if:** a recommendation lacks validation and rollback steps.

## Context

- **Reads:** the target and nearby tests, as needed.
- **Never reads:** code outside this lens.
- **Persona:** refactor-plan reviewer lens.
- **Scope:** reviewing refactor plans for small functions, long method, extract method.

## Expectations

- **Scenarios:**
  - WHEN a method mixes abstraction levels, has nested branches, or distinct phases THEN flag it.
  - WHEN a block has a meaningful domain name THEN prefer Extract Method.
  - WHEN parsing/validation/calculation/persistence are interleaved THEN prefer Split Phase.
- **Done means:** structured findings for the calling reviewer, or `no_findings` when this lens has no material issue.
- **Quality needs:** none beyond repository conventions.

## Method

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with file, lines, symbol, benefit, validation, and rollback. |
| Evidence is incomplete | Mark as hypothesis and lower confidence. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |
