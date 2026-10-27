---
name: oc-java-immutable
description: "Trigger: Java immutability, records, value objects, defensive copies, mutable collections, DTO modeling. Model Java data safely and clearly."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.0"
---

# oc-java-immutable

## Intent

- **Goal:** Java data modeled safely: invariants enforced at construction and no accidental mutable exposure.
- **Limits:**
  - Teaches state modeling only; does not call other skills, impose immutability everywhere, or choose framework annotations unless context requires them.
  - Prefer immutable data for values, messages, events, and DTOs unless mutation is required.
  - Use records for transparent immutable aggregates when they match the domain and Java version; avoid them for entities that require identity, lazy mutation, or framework lifecycle constraints unless explicitly supported.
- **Fails if:** invariants are not validated at construction, mutable inputs/outputs are not defensively copied when ownership is not transferred, or mutable internals are exposed.

## Context

- **Reads:** Java version; type role (domain model, value object, DTO, event, command, or persistence entity); mutability requirements and collection ownership; equality/hashCode expectations.
- **Never reads:** sources unrelated to the type under review.
- **Persona:** Java data modeler.
- **Scope:** modeling Java data with records, value objects, immutable classes, defensive copies, collection ownership, equality, and state validation. Not for persistence mapping only, serialization-only configuration, generic DTO naming, or non-Java data modeling.

## Expectations

- **Scenarios:** WHEN the data role and mutability needs are known THEN choose record vs class by invariants, identity, and framework constraints, define construction validation, protect mutable components, and clarify equality and serialization implications when relevant.
- **Done means:** modeling choice (record, immutable class, mutable class, or other); invariants and validation point; mutability/ownership policy; equality/hashCode implications; example shape when useful.
- **Quality needs:** the choice fits the Java version and framework constraints.

## Method

| Condition | Action |
|---|---|
| Data is a transparent immutable carrier | Prefer record if Java version supports it. |
| Mutable component is stored | Copy on construction and access, or document ownership transfer. |
| Domain invariant exists | Enforce in constructor/canonical constructor. |
| Type has identity/lifecycle mutation | Prefer class over record. |
| Collection is returned | Return immutable copy/view based on ownership contract. |

Reference: `references/java-immutability.md` — records, defensive copies, and modeling choices.
