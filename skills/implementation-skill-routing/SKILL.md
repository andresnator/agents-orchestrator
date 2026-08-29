---
name: implementation-skill-routing
description: "Trigger: plan Skills field, implementation skill routing, execution skill selection. Select the smallest implementation skill set for each work group."
license: MIT
metadata:
  author: andresnator
  version: "2.0.0"
  status: testing
---

# Implementation Skill Routing

## Contract

Load when drafting or validating a plan work group's `Skills:` field. Planners select names only and never load the selected implementation skill bodies. Executors load the selected bodies within the assigned scope.

Every work group requires `Skills: <csv|none>`. Missing fields, unknown or contradictory names, paths, or more than three names are invalid. Split a group by responsibility when it needs more than three skills.

## Source

Read `.ai/atl/skill-registry.md` by its literal path when it exists. Use only the `Trigger` and `Skill` columns from the `## Skills` table; registry paths resolve discovery only and are never returned.

Use the runtime skill catalog when the registry is absent, its `## Skills` table is malformed, or a matched registry name is unavailable at runtime. Match the catalog's trigger or description in the same way. Never invent a skill name.

## Selection

For each work group:

1. Derive direct work signals from its Behavior, tasks, `Files:`, and `Verify` scope.
2. Select a skill only when its trigger directly matches an assigned work signal. Do not infer adjacent capabilities.
3. Exclude skills for planning, discovery, review, delivery, or Git even when a trigger matches.
4. Remove duplicates and preserve source order. Return at most three names.
5. Use `none` only when no eligible trigger matches.

When validating an existing `Skills:` field, an unavailable name or a trigger that contradicts the assigned work is `BLOCK skill-routing <reason>`. Do not replace, ignore, or guess around it.

## Boundaries

- Selected skills cannot expand behavior, `Files:`, validation, Git ownership, or output contracts.
- Return names, never paths. Planners never load selected bodies; executors load only the selected registered bodies within scope.

## Output

Return the ordered comma-separated names or `none` to the caller. The caller owns artifact formatting and execution scope.
