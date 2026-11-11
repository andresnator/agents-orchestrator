---
name: oc-seams
description: "Trigger: dependency seam detection, hard dependencies. Find seams that make legacy code testable."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Dependency Seam Detection

## Intent

- **Goal:** Find hard-to-control dependencies and propose seams that make tests possible before refactor.
- **Limits:** Prefer the least invasive technique that lets a test run. Dependency-breaking is medicine, not vitamins.
- **Fails if:** A more invasive seam is proposed when a less invasive one would let the test run.

## Context

- **Reads:** The target code and `references/dependency-breaking-catalog.md` — dependency-breaking catalog (WELC): four strategies, the individual techniques with contraindications, and the instantiation-blocker table.
- **Never reads:** Code outside the target's dependency path.
- **Persona:** Legacy-code seam finder.
- **Scope:** Dependency seam detection and hard dependencies blocking tests.

## Expectations

- **Scenarios:**
  - WHEN business logic contains `new`, static calls or singletons, system clock, random, filesystem, environment, or global config, direct DB access, external services, queues, event buses, cache, threading, or async work THEN flag it as a dependency smell and propose a seam.
- **Done means:** Each smell has a seam option and its enabling point: constructor injection, interface seam, object seam, wrapper or adapter, parameter injection, protected method seam, sprout method, or sprout class.
- **Quality needs:** A scar (a slightly awkward seam) is acceptable and gets cleaned up in a later refactor once tests exist.

## Method

A seam is a place where behavior can be changed without editing the code at that place; every seam has an enabling point where the substitution is decided. Object seams (polymorphism, injection) are the default in OO code; link/classpath seams (test-time substitution of a dependency at the linker or classpath level) and preprocessing seams sit below them and matter when the code itself cannot be edited.

Selection order: parameter or constructor injection before interface extraction, interface extraction before subclass-and-override, subclass-and-override before brute force.
