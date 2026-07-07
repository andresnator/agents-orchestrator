---
name: repo-issues
description: >
  Trigger: repo issues, project problems, what is wrong with this repo,
  architecture issue shortlist. Absorb-style evidence audit of a product
  repository: verified vs aspirational, adversarial filter, ranked issue
  shortlist.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Repo Issues

## Activation Contract

Use this skill to identify and rank real problems in a product repository: architectural drift, structural risks, broken or missing guardrails, operational hazards.

Do not use it for AI-harness analysis — that is the `absorb` skill's charter (this skill is its inverse: same discipline, product target). Do not use it for code-style review; that belongs to the refactor harness.

## Required Input

- The repo root or a subpath to audit.
- The project-state summary when available (from `architecture-state`); otherwise establish language/toolchain evidence first.
- Optional focus themes from the user.

## Hard Rules

- Verify every issue from source files, configs, or wiring; never promote README or comment claims as proven behavior.
- Contrast the project's stated intent (docs, ADRs, module READMEs) against reality; a mismatch is a drift finding, with both sides cited.
- Report problems, not preferences: an issue must have a consequence (risk, cost, blocked change), not just a style opinion.
- Never auto-fix, commit, or edit the audited repo as part of the audit.

## Workflow

### 1. Scope

Confirm the audit target and focus themes. Resolve paths before deep analysis.

### 2. Map issues with evidence

For every candidate issue, capture:

| Field | What to record |
| --- | --- |
| Issue | Clear name |
| Mechanism | File path and concrete evidence |
| Status | Verified / partial / aspirational |
| Impact | What it breaks, risks, or blocks |
| Effort | Rough cost to address |

### 3. Contrast with stated intent

Check docs, ADRs, and module boundaries the project claims to have. Record drift findings (`claims X, does Y`) and also at least one **Holding Up** item — something the repo does well — to avoid a purely negative audit.

### 4. Adversarial filter

Challenge each surviving issue:

- Is it truly verified, or inferred?
- Is it a problem with a consequence, or a preference?
- Is fixing it proportional to its impact?
- Is it architecture-level, or should it route to `/refactor-plan`?

Keep only `FIX` or `CONDITIONAL` items in the shortlist; route code-level items out explicitly.

### 5. Deliver

Write the ranked shortlist to the caller-supplied report path; when no path is supplied, return the same structure as a concise chat summary. Rank by impact descending, effort ascending.

## Red Flags

- The path does not exist or is not a product repo.
- The user actually wants harness analysis (`absorb`) or code review (refactor harness).
- Findings rest only on documentation claims.

Surface these explicitly; do not fabricate findings.

## Verification

- Every shortlist item has file-level evidence and a stated consequence.
- At least one Holding Up item recorded.
- Preferences and code-level items were filtered out or rerouted.
- No edits were made to the audited repo.

## Output Contract

Return: audited target, evidence table, drift findings, Holding Up items, ranked `FIX`/`CONDITIONAL` shortlist, rerouted items, and the report path when a file was written.
