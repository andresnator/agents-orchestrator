---
name: oc-java-naming
description: "Trigger: Java naming, readability, test names. Evaluate Java naming and readability with domain language."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# oc-java-naming

## Intent

- **Goal:** Java names in domain language and repo style.
- **Limits:**
  - Class names: UpperCamelCase nouns; interfaces: UpperCamelCase; methods: lowerCamelCase verbs or verb phrases; variables: lowerCamelCase; constants: UPPER_SNAKE_CASE.
  - Prefer semantic test names such as `shouldExpectedBehaviorWhenCondition`; accept `should_expected_behavior_when_condition` when the repo consistently uses underscores.
  - Respect consistent existing repo style, especially test naming.
  - Prefer domain terms over generic technical names; avoid abbreviations unless widely understood.
  - Do not propose mass renames without clear maintainability benefit.
  - Preserve observable behavior; label functional changes as follow-up.
- **Fails if:** a finding lacks evidence and is not marked hypothesis.

## Context

- **Reads:** the target and nearby tests, as needed.
- **Never reads:** `none`.
- **Persona:** refactor reviewer.
- **Scope:** load when reviewing Java refactor plans for: Java naming, readability, test names.

## Expectations

- **Scenarios:** WHEN a name breaks convention or domain language THEN create an evidenced finding.
- **Done means:** findings in the calling contract's format (it wins); each has `file:line` evidence or is marked hypothesis; `no_findings` when nothing is material.
- **Quality needs:** note validation and rollback implications where material; the caller decides where they land.

## Method

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with `file:line` evidence and the smallest safe refactor. |
| Evidence is incomplete | Mark as hypothesis and lower confidence. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |
