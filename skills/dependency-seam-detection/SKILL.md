---
name: dependency-seam-detection
description: "Trigger: dependency seam detection, hard dependencies. Find seams that make legacy code testable."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

# Dependency Seam Detection
Find hard-to-control dependencies and propose seams that make tests possible before refactor.

## Dependency smells

- `new` inside business logic.
- Static calls and singletons.
- System clock, random, filesystem, environment, or global config.
- Direct DB access, external services, queues, event buses, cache, threading, or async work.

## Seam options

- Constructor injection.
- Interface seam.
- Object seam.
- Wrapper or adapter.
- Parameter injection.
- Protected method seam.
- Sprout method.
- Sprout class.
