---
name: oc-routing
description: "Trigger: plan Skills field, implementation skill routing, execution skill selection. Select the smallest implementation skill set for each work group."
license: MIT
metadata:
  author: andresnator
  version: "4.2.1"
  status: testing
---

# Implementation Skill Routing

## Intent

- **Goal:** Draft or validate a work group's `Skills:` field with the smallest skill set.
- **Limits:**
  - Planners select names without loading skill bodies. Executors load only the selected bodies within their assigned scope.
  - Selected skills cannot expand behavior, `Files:`, validation, Git ownership, or output contracts.
- **Fails if:** A work group lacks `Skills: <csv|none>` or holds unknown or contradictory names or paths. Split work by responsibility when a group needs more than three skills.

## Context

- **Reads:** `.ai/atl/skill-registry.md` by the "Skill Registry" rules in the global `AGENTS.md`.
- **Scope:** Planning and execution skill selection.

## Expectations

- **Scenarios:**
  - WHEN selecting skills THEN Use the registry, or the runtime catalog fallback, as the global `AGENTS.md` says. Use `none` if no eligible description matches.
  - WHEN validating an already assigned `Skills:` field THEN an unavailable or disallowed identifier or a description that contradicts the assigned work is `BLOCK skill-routing <reason>`. Runtime fallback is for discovery, not permission to replace, ignore, or guess around an assigned identifier.
- **Done means:** An ordered comma-separated list of native identifiers, or `none`; the caller owns formatting and execution scope.
- **Quality needs:** Direct matches only; never infer adjacent capabilities.

## Method

1. Derive direct signals from Scenarios, tasks, `Files:`, and Done means.
2. Exclude skills for planning, discovery, review, delivery, or Git.
3. Deduplicate in source order. Return at most three names.
