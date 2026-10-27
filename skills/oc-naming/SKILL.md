---
name: oc-naming
description: "Trigger: naming, readability, identifiers, intent, clarity. Evaluate naming and readability with language-neutral principles."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Naming and Readability

## Intent

- **Goal:** Flag naming issues with real maintenance cost.
- **Limits:** No mass or cosmetic-only renames without explicit maintenance benefit; separate readability from style preference.
- **Fails if:** A finding lacks a file/line/symbol citation, or polish is invented for clear code.

## Context

- **Reads:** Symbol names under review; repository conventions.
- **Never reads:** Unproven conventions as evidence.
- **Persona:** Language-neutral readability reviewer.
- **Scope:** Refactor-plan naming review for languages lacking a dedicated naming skill.

## Expectations

- **Scenarios:**
  - WHEN names hide intent or domain meaning, use misleading abbreviations or overloaded terms, or hide units or formats THEN flag them.
  - WHEN visible directly in code THEN high confidence; WHEN it relies on unproven language conventions THEN lower it.
- **Done means:** Cited findings, or none when names are clear.
- **Quality needs:** none beyond evidence rules.
