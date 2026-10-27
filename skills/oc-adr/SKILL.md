---
name: oc-adr
description: "Trigger: ADR, architecture decision record, technical decision. Create ADRs that document context, options, rationale, consequences, and trade-offs."
license: MIT
metadata:
  author: andresnator
  status: done
  version: "3.1.0"
---
# ADR Creator

## Intent

- **Goal:** Produce a concise Architecture Decision Record that explains a decision, the context that forced it, the options considered, and the consequences accepted.
- **Limits:** Write or modify files only when the user explicitly asks for a file/path. Do not invent alternatives, pros, cons, or rationale; ask when alternatives are missing.
- **Fails if:** the final ADR contains placeholder instructions, invented content, a wrong status, or `TBD` for anything other than a detail the user intentionally skipped.

## Context

- **Reads:** User answers; `assets/template-markdown.md` before drafting.
- **Never reads:** none.
- **Persona:** Constructive interviewer and decision recorder.
- **Scope:** Frontmatter triggers, or any formal record of why a technical or architectural choice was made.

## Expectations

- **Scenarios:**
  - WHEN the user has not supplied enough to draft a complete ADR THEN default to interview mode, asking questions in the user's language, one at a time, and stating once at the start that the user may skip questions or stop at any time.
  - WHEN a question is open-ended THEN ask it directly in normal chat, adding a short `Recommendation: ...` only when it helps; use the `question` tool only for a closed confirmation or enumerated choice.
  - WHEN an answer is vague, contradictory, or rationale-free THEN constructively challenge it before drafting; proceed if the user explicitly says to continue anyway.
  - WHEN the decision is already made THEN status is `Accepted`; for proposals, evaluations, or unclear status use `Proposed`.
  - WHEN the user explicitly requested a file/path THEN save the ADR there and summarize the saved path in chat.
- **Done means:** by default, the final ADR is returned as exactly one Markdown code block filling the template structure, with no files created. Use `TBD` sparingly, only for an intentionally skipped detail.
- **Quality needs:** ADR artifact language is English unless the user explicitly asks for another. No question headings, numbering, rationale blocks, or interview-length estimates.

## Method

Gather only what is needed, dependency-first:

1. Decision title and status.
2. Context: problem, constraints, forces, and why the decision matters now.
3. Chosen option or proposal.
4. Options considered, with pros and cons for each.
5. Consequences: benefits, drawbacks, risks, and trade-offs.
6. Follow-up only when there are useful open actions or unresolved questions.

Question format (example):

```markdown
What decision should this ADR capture?

Recommendation: "Adopt PostgreSQL for billing data."
```
