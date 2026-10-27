---
name: oc-routing
description: "Trigger: plan Skills field, implementation skill routing, execution skill selection. Select the smallest implementation skill set for each work group."
license: MIT
metadata:
  author: andresnator
  version: "4.1.0"
  status: testing
---

# Implementation Skill Routing

## Intent

- **Goal:** Draft or validate a work group's `Skills:` field with the smallest skill set.
- **Limits:**
  - Planners select names without loading skill bodies. Executors load only the selected bodies within their assigned scope.
  - Selected skills cannot expand behavior, `Files:`, validation, Git ownership, or output contracts.
  - The plugin alone owns the generated snapshot; never hand-edit it or add a manual generator.
- **Fails if:** A work group lacks `Skills: <csv|none>` or holds unknown or contradictory names or paths. Split work by responsibility when a group needs more than three skills.

## Context

- **Reads:** `.ai/atl/skill-registry.md` by its literal path when present.
- **Never reads:** Treat `Location` as diagnostic information only. Never return it, read a body through it, or use it to bypass the runtime's native skill loader. Ignore generated preamble instructions suggesting direct body reads.
- **Persona:** Conservative skill router.
- **Scope:** Planning and execution skill selection.

## Expectations

- **Scenarios:**
  - WHEN the registry is valid THEN Match work signals only against `Description` and return only native identifiers from `Skill ID`, never display `Name` or paths.
  - WHEN discovering skills THEN Consult the runtime skill catalog when the registry is absent, malformed, has no matching description, or a selected skill is unavailable or disallowed. Return only available, allowed native identifiers from it; never invent one or bypass the allowlist. Use `none` if no eligible description matches.
  - WHEN validating an already assigned `Skills:` field THEN an unavailable or disallowed identifier or a description that contradicts the assigned work is `BLOCK skill-routing <reason>`. Runtime fallback is for discovery, not permission to replace, ignore, or guess around an assigned identifier.
- **Done means:** An ordered comma-separated list of native identifiers, or `none`; the caller owns formatting and execution scope.
- **Quality needs:** Direct matches only; never infer adjacent capabilities.

## Method

A valid plugin snapshot has `## OpenCode Skills`, `## Agent Skills`, and `## Claude Skills`, each with exactly `Description | Skill ID | Name | Location` columns, in that order. Do not accept the legacy `## Skills` section, `Trigger` column, or three-column `Description | Skill | Location` schema.

1. Derive direct signals from Scenarios, tasks, `Files:`, and Done means.
2. Exclude skills for planning, discovery, review, delivery, or Git.
3. Deduplicate in source order. Return at most three names.
