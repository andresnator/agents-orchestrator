---
name: oc-domain
description: "Build and sharpen the domain model in CONTEXT.md. Trigger: domain model, domain terminology, ubiquitous language, glossary. Formal ADRs belong to oc-adr."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: Agents Orchestrator maintainers
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "3.0.0"
---

# Domain Modeling

## Intent

- **Goal:** Actively build and sharpen the project's domain model while designing: challenge terms, invent edge-case scenarios, and write the glossary and decisions down the moment they crystallise.
- **Limits:** `CONTEXT.md` is a glossary and nothing else: no implementation details, not a spec, scratch pad, or decision log. Create files lazily: `CONTEXT.md` when the first term is resolved, `docs/adr/` (`doc/adr/` when the repository uses `doc/`) when the first ADR is needed. Offer ADRs sparingly.
- **Fails if:** A term conflict or code contradiction goes unchallenged, resolved terms are batched instead of captured inline, or an ADR is offered without all three ADR criteria.

## Context

- **Reads:** `CONTEXT.md` (or `CONTEXT-MAP.md` plus per-context `CONTEXT.md`), `docs/adr/`, and the code the user describes.
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

Offer an ADR only when all three criteria in [ADR-FORMAT.md](./assets/ADR-FORMAT.md) are true; otherwise skip it.

All ADRs are in one folder: `docs/adr/NNNN-slug.md`. A small decision uses the lightweight format of ADR-FORMAT.md. A formal ADR with options uses the `oc-adr` template in the same folder.

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
│   └── adr/                          ← all decisions
├── src/
│   ├── ordering/
│   │   └── CONTEXT.md
│   └── billing/
│       └── CONTEXT.md
```

## Attribution

Original skill by Matt Pocock from <https://github.com/mattpocock/skills>.
