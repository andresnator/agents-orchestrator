---
name: oc-domain
description: "Build and sharpen a project's domain model. Use when the user wants to pin down domain terminology or a ubiquitous language, record an architectural decision, or when another skill needs to maintain the domain model."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: Agents Orchestrator maintainers
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "2.1.0"
---

# Domain Modeling

## Intent

- **Goal:** Actively build and sharpen the project's domain model while designing: challenge terms, invent edge-case scenarios, and write the glossary and decisions down the moment they crystallise.
- **Limits:** `CONTEXT.md` is a glossary and nothing else: no implementation details, not a spec, scratch pad, or decision log. Create files lazily: `CONTEXT.md` when the first term is resolved, `docs/adr/` when the first ADR is needed. Offer ADRs sparingly.
- **Fails if:** A term conflict or code contradiction goes unchallenged, resolved terms are batched instead of captured inline, or an ADR is offered without all three ADR criteria.

## Context

- **Reads:** `CONTEXT.md` (or `CONTEXT-MAP.md` plus per-context `CONTEXT.md`), `docs/adr/`, and the code the user describes.
- **Never reads:** none.
- **Persona:** Precise domain-language partner.
- **Scope:** Changing the model, not just consuming it. Merely reading `CONTEXT.md` for vocabulary is a one-line habit any skill can do and is not this skill.

## Expectations

- **Scenarios:**
  - WHEN a term conflicts with `CONTEXT.md` THEN call it out immediately: "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"
  - WHEN a term is vague or overloaded THEN propose a precise canonical term: "You're saying 'account' — do you mean the Customer or the User?"
  - WHEN domain relationships are discussed THEN stress-test them with invented edge-case scenarios that force precise boundaries.
  - WHEN the user states how something works THEN check the code and surface contradictions: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"
  - WHEN a term is resolved THEN update `CONTEXT.md` right there using [CONTEXT-FORMAT.md](./assets/CONTEXT-FORMAT.md).
- **Done means:** Resolved terms are in `CONTEXT.md`; qualifying decisions are offered as ADRs in [ADR-FORMAT.md](./assets/ADR-FORMAT.md) format.
- **Quality needs:** Glossary entries are implementation-free and canonical.

## Method

Offer an ADR only when all three are true; otherwise skip it:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons.

File layout. Single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

A root `CONTEXT-MAP.md` means multiple contexts; the map points to each:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

## Attribution

Original skill by Matt Pocock from <https://github.com/mattpocock/skills>.
