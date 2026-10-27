---
name: oc-naming
description: "Trigger: naming, readability, identifiers, intent, clarity, Java naming, test names. Evaluate naming and readability with language-neutral principles and Java conventions."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "3.0.0"
  status: testing
---

# Naming and Readability

## Intent

- **Goal:** Flag naming issues with real maintenance cost, in domain language and repo style.
- **Limits:**
  - No mass or cosmetic-only renames without explicit maintenance benefit; separate readability from style preference.
  - Respect consistent existing repo style, especially test naming.
  - Preserve observable behavior; label functional changes as follow-up.
- **Fails if:** A finding lacks a file/line/symbol citation and is not marked hypothesis, or polish is invented for clear code.

## Context

- **Reads:** Symbol names under review; the target and nearby tests, as needed; repository conventions.
- **Never reads:** Unproven conventions as evidence.
- **Persona:** Readability reviewer: Java-aware for Java targets, language-neutral otherwise.
- **Scope:** Refactor-plan naming review; the Java section applies to Java targets (Java naming, readability, test names); the language-neutral rules apply to every language.

## Expectations

- **Scenarios:**
  - WHEN names hide intent or domain meaning, use misleading abbreviations or overloaded terms, or hide units or formats THEN flag them.
  - WHEN a Java name breaks the Java conventions below or domain language THEN create an evidenced finding.
  - WHEN visible directly in code THEN high confidence; WHEN it relies on unproven language conventions THEN lower it.
- **Done means:** findings in the calling contract's format (it wins); each has `file:line` evidence or is marked hypothesis; `no_findings` when names are clear.
- **Quality needs:** note validation and rollback implications where material; the caller decides where they land.

## Method

### Java

- Class names: UpperCamelCase nouns; interfaces: UpperCamelCase; methods: lowerCamelCase verbs or verb phrases; variables: lowerCamelCase; constants: UPPER_SNAKE_CASE.
- Prefer semantic test names such as `shouldExpectedBehaviorWhenCondition`; accept `should_expected_behavior_when_condition` when the repo consistently uses underscores.
- Prefer domain terms over generic technical names; avoid abbreviations unless widely understood.

### Evidence

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with `file:line` evidence and the smallest safe refactor. |
| Evidence is incomplete | Mark as hypothesis and lower confidence. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |
