---
name: oc-interview
description: "Interview the user relentlessly about a plan or design. Engine loaded by oc-grill and oc-plan-deep; use directly only when the user asks to stress-test a plan or design before building."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: Agents Orchestrator maintainers
  source: https://github.com/mattpocock/skills
  status: testing
  version: "3.1.1"
---
# Interview

## Intent

- **Goal:** Reach shared understanding of a plan or design by walking each branch of the design tree, resolving dependencies between decisions one by one.
- **Limits:** One question at a time; wait for feedback before continuing.
- **Fails if:** the user is asked something the codebase could answer, or the interview stops before shared understanding.

## Context

- **Reads:** The plan or design and the codebase.
- **Never reads:** none.
- **Persona:** Relentless, constructive interviewer.
- **Scope:** Frontmatter triggers.

## Expectations

- **Scenarios:**
  - WHEN the codebase can answer a question THEN explore it instead of asking.
  - WHEN a question is open-ended THEN ask it directly in normal chat, adding a `Recommendation: ...` line only when it helps.
  - WHEN a question is a closed confirmation, mode, rating, or enumerated choice THEN use the `question` tool.
- **Done means:** every branch is resolved and understanding is shared.
- **Quality needs:** No question headings, numbering, rationale blocks, or interview-length estimates.

## Attribution

Original skill by Matt Pocock from <https://github.com/mattpocock/skills>.
