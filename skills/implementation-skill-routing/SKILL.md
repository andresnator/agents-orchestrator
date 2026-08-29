---
name: implementation-skill-routing
description: "Trigger: plan Skills field, implementation skill routing, execution skill selection. Select the smallest implementation skill set for each work group."
license: MIT
metadata:
  author: andresnator
  version: "3.0.0"
  status: testing
---

# Implementation Skill Routing

## Contract

Load when drafting or validating a plan work group's `Skills:` field. Planners select names only and never load the selected implementation skill bodies. Executors load the selected bodies within the assigned scope.

Every work group requires `Skills: <csv|none>`. Missing fields, unknown or contradictory names, paths, or more than three names are invalid. Split a group by responsibility when it needs more than three skills.

## Source

Read `.ai/atl/skill-registry.md` by its literal path when it exists. A valid registry has `## OpenCode Skills`, `## Agent Skills`, and `## Claude Skills`, each with `Description | Skill | Location` columns. Match work signals only against `Description` and return only names from `Skill`.

Treat `Location` as diagnostic information only. Never return it, read a skill body through it, or use it to bypass the runtime's native skill loader.

Consult the runtime skill catalog when the registry is absent, malformed, has no matching description, or a selected skill is no longer available. Match runtime descriptions in the same way and return only runtime-provided names. Never invent a skill name. Do not accept the legacy `## Skills` section or `Trigger` column.

## Selection

For each work group:

1. Derive direct work signals from its Behavior, tasks, `Files:`, and `Verify` scope.
2. Select a skill only when its description directly matches an assigned work signal. Do not infer adjacent capabilities.
3. Exclude skills for planning, discovery, review, delivery, or Git even when a description matches.
4. Remove duplicates and preserve source order. Return at most three names.
5. Use `none` only when no eligible description matches.

When validating an existing `Skills:` field, an unavailable name or a description that contradicts the assigned work is `BLOCK skill-routing <reason>`. Do not replace, ignore, or guess around it.

## Boundaries

- Selected skills cannot expand behavior, `Files:`, validation, Git ownership, or output contracts.
- Return names, never paths. Planners never load selected bodies; executors use the native skill loader to load only the selected registered bodies within scope.

## Output

Return the ordered comma-separated names or `none` to the caller. The caller owns artifact formatting and execution scope.
