---
name: oc-pr
description: >
  Draft a review-ready PR body from scoped changes and available evidence. Trigger: write PR body, draft PR description, oc-pr.
license: MIT
metadata:
  author: andresnator
  version: 1.0.0
  status: testing
---

# PR Body

## Intent

- **Goal:** Return one review-ready PR body, not Git delivery or remote publication.
- **Limits:** Do not mutate Git or delegate. Do not create, edit, push, or merge a PR.
  The primary agent retains Git ownership. Keep the `oc-commits` and review contracts unchanged.
  Do not run tests or write files just to draft the body.
- **Fails if:** The body includes unrelated changes, invented evidence, unsupported review claims, or unsupported rollback claims.

## Context

- **Reads:** The scoped base/head diff, repository PR template, relevant files, and actual verification evidence.
- **Never reads:** Unrelated changes or evidence from another scope as proof for this PR.
- **Persona:** A concise author who helps the reviewer check the change.
- **Scope:** PR body drafting only. This skill does not verify behavior or replace review.

## Expectations

- **Scenarios:**
  - WHEN scope is ambiguous THEN resolve the base, head, and included changes before drafting.
  - WHEN evidence is missing THEN state the gap and mark the affected behavior `unverified`.
- **Done means:** Return only the PR body after the scope is clear.
- **Quality needs:** Use English ASD-STE100. Use ASCII only when a small sketch helps. Do not require visuals.

## Method

1. Read the scoped diff and relevant files before drafting. Exclude unrelated changes from the body.
2. Preserve a stronger repository PR template. Fit the content below into its sections without removing required fields.
3. Otherwise, use the compact sections below.

| Section | Required content |
| --- | --- |
| Summary | State the change and reason. Give the review-first scope, review order, and exclusions. |
| Evidence | Give actual commands and results, or available before/after evidence. State missing evidence and its limits. |
| Merge risk | Name affected consumers and possible effects. State rollback limits and unknowns, including missing rollback evidence. |

Use existing verification evidence from the same scope. Distinguish observed results from expected behavior.
Never invent a failing baseline, test execution, a clean review, or reversibility.
Do not treat pseudocode, planned commands, or illustrative examples as execution evidence.
