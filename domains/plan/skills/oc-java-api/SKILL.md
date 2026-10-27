---
name: oc-java-api
description: "Trigger: Java API design, public API, encapsulation, modules, visibility, contracts, binary compatibility. Design Java APIs with clear boundaries."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.0"
---

# oc-java-api

## Intent

- **Goal:** Java APIs with minimal, documented, compatible boundaries.
- **Limits:**
  - Teaches API boundary design only; does not call other skills, generate full libraries, or decide product behavior.
  - Minimize public surface (public means support burden); prefer package-private/internal implementation until a stable consumer need exists.
  - Avoid leaking mutable internals; make invalid states hard to represent where practical.
  - Avoid breaking compatibility unless the user explicitly accepts it.
- **Fails if:** unneeded members stay public, mutable internals leak, contracts (preconditions, postconditions, exceptions, thread-safety when relevant) are undocumented, or compatibility breaks go unflagged.

## Context

- **Reads:** API consumers and expected usage; public vs internal surface; Java version and module usage when known; compatibility expectations; error and validation contract expectations.
- **Never reads:** `none`.
- **Persona:** Java API designer.
- **Scope:** designing or reviewing Java APIs, public classes, interfaces, modules, package boundaries, visibility, method contracts, and compatibility risks. Not for private implementation cleanup, general Clean Code review, REST API product design, or non-Java API design.

## Expectations

- **Scenarios:** WHEN consumers and stability expectations are known THEN separate API from implementation, review visibility, mutability, construction, errors, docs, and module/package implications.
- **Done means:** API boundary verdict; recommended public surface changes; contract documentation needed; compatibility risks; minimal API design proposal.
- **Quality needs:** every recommendation ties to a consumer need or compatibility concern.

## Method

| Condition | Action |
|---|---|
| Member need not be public | Reduce visibility. |
| API exposes mutable collection/object | Return defensive copy, immutable view, or documented ownership transfer. |
| Constructor has many parameters | Consider named factory, parameter object, or builder based on complexity. |
| Module boundary exists | Export only published API packages; keep implementation unexported. |
| Reflection access is requested | Prefer narrow `opens`/qualified access and document the reason. |

Reference: `references/java-api-boundaries.md` — visibility, modules, mutability, and compatibility guidance.
