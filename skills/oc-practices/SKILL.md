---
name: oc-practices
description: "Trigger: programming best practices, clean code, DRY, KISS, YAGNI, maintainability, general code quality. Evaluate general code quality without depending on language-specific skills."
license: MIT
metadata:
  author: andresnator
  status: backlog
  version: "2.1.1"
---
# Programming practices

## Intent

- **Goal:** Return a bounded, prioritized code-quality review or improvement plan across languages: readability, maintainability, duplication, cohesion, coupling, naming, simplicity, and safe evolution.
- **Limits:** Do not choose tools, call other skills, rewrite whole systems, or replace domain requirements supplied by the user. Preserve observable behavior unless the user explicitly asks for behavior change. Do not recommend abstractions before identifying a stable concept or repeated reason to change.
- **Fails if:** advice treats DRY as removing every repeated line instead of duplicated knowledge, adds unjustified indirection, favors cleverness over clarity, omits tradeoffs, or prescribes changes for "best practices" with no code.

## Context

- **Reads:** Target language and code snippet/files if available; intended behavior and current pain point; constraints (legacy-code safety, public API compatibility, deadline, team conventions); whether the user wants diagnosis only or an improvement plan. `references/principles.md` only when the request needs deeper tradeoff language.
- **Never reads:** language-specific skills; this skill must not depend on them.
- **Persona:** Pragmatic reviewer who prefers the smallest behavior-preserving improvement.
- **Scope:** Triggered by programming best practices, clean code, DRY, KISS, YAGNI, readability, maintainability. Not for requests that are only formatting, framework setup, performance tuning, security auditing, testing, or language-specific API usage with no broader design-quality question.

## Expectations

- **Scenarios:**
  - WHEN code is hard to read but behavior is clear THEN recommend naming, extraction, structure, and intent-revealing changes.
  - WHEN duplication exists THEN classify it as duplicated knowledge, coincidental repetition, or premature abstraction risk.
  - WHEN the user asks for "best practices" with no code THEN give a principle map and ask for code/context before prescribing changes.
  - WHEN a proposed improvement adds indirection THEN justify it with a real change scenario or reject it.
  - WHEN missing context could change the recommendation materially THEN ask one clarifying question; otherwise do not ask.
- **Done means:** return a summary verdict (`healthy`, `needs_cleanup`, or `design_risk`), top issues ordered by impact, recommended changes with reasoning, tradeoffs and risks, and one next step.
- **Quality needs:** Name tradeoffs explicitly: simplicity, coupling, cohesion, testability, discoverability, and change cost.

## Method

Identify the code's purpose and change pressure; separate readability issues from design issues; classify duplication and abstraction opportunities; recommend the smallest behavior-preserving improvement first; explain the tradeoff and what not to change yet.
