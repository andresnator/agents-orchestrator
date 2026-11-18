---
name: oc-adr
description: "Create an ADR with context, options, rationale, and consequences. Trigger: ADR, architecture decision record, technical decision."
license: MIT
metadata:
  author: andresnator
  status: done
  version: "3.3.0"
---
# ADR Creator

## Intent

- **Goal:** Produce a concise Architecture Decision Record that explains a decision, the context that forced it, the options considered, and the consequences accepted.
- **Limits:** Write or modify files only when the user asks for a file. The location is `docs/adr/NNNN-slug.md` (`doc/adr/` when the repository uses `doc/`): use the next free number unless the user gives a path. In a multi-context repository (root `CONTEXT-MAP.md`), a decision of one context goes in that context's own `docs/adr/`. Do not invent alternatives, pros, cons, or rationale; ask when alternatives are missing. Resolve discoverable repository facts before asking the user; if the decision itself is missing, ask for it first.
- **Fails if:** the final ADR contains placeholder instructions, invented content, a wrong status, or `TBD` for anything other than a detail the user intentionally skipped.

## Context

- **Reads:** User answers; `assets/template-markdown.md` before drafting.
- **Scope:** Frontmatter triggers, or any formal record of why a technical or architectural choice was made.

## Expectations

- **Scenarios:**
  - WHEN the user has not supplied enough to draft a complete ADR THEN default to interview mode in the user's language. State once at the start that the user may skip questions or stop at any time.
  - WHEN an answer is vague, contradictory, or rationale-free THEN constructively challenge it before drafting; proceed if the user explicitly says to continue anyway.
  - WHEN the decision is already made THEN status is `Accepted`; for proposals, evaluations, or unclear status use `Proposed`.
  - WHEN the user asked for a file THEN save the ADR at the location in `Limits` and give the saved path in chat.
- **Done means:** by default, the final ADR is returned as exactly one Markdown code block filling the template structure, with no files created. Use `TBD` sparingly, only for an intentionally skipped detail.
- **Quality needs:** ADR artifact language is English unless the user explicitly asks for another.

## Method

Gather only what is needed, dependency-first:

1. Decision title and status.
2. Context: problem, constraints, forces, and why the decision matters now.
3. Chosen option or proposal.
4. Options considered, with pros and cons for each.
5. Consequences: benefits, drawbacks, risks, and trade-offs.
6. Follow-up only when there are useful open actions or unresolved questions.
