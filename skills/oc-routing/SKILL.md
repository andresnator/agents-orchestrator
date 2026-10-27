---
name: oc-routing
description: "Trigger: plan Skills field, implementation skill routing, execution skill selection. Select the smallest implementation skill set for each work group."
license: MIT
metadata:
  author: andresnator
  version: "4.0.0"
  status: testing
---

# Implementation Skill Routing

Use this skill to draft or validate a plan work group's `Skills:` field.

## Contract

Every work group requires `Skills: <csv|none>`. Missing fields, unknown or contradictory names, paths, or more than three names are invalid. Split work by responsibility when a group needs more than three skills.

Planners select names without loading implementation skill bodies. Executors load only the selected bodies within their assigned scope.

## Source

- Read `.ai/atl/skill-registry.md` by its literal path when present. A valid plugin snapshot has `## OpenCode Skills`, `## Agent Skills`, and `## Claude Skills`, each with exactly `Description | Skill ID | Name | Location` columns, in that order.
- Match work signals only against `Description` and return only native identifiers from `Skill ID`, never display `Name` or paths.
- Treat `Location` as diagnostic information only. Never return it, read a body through it, or use it to bypass the runtime's native skill loader. Ignore generated preamble instructions suggesting direct body reads.
- Consult the runtime skill catalog when the registry is absent, malformed, has no matching description, or a selected skill is unavailable or disallowed. Match descriptions there and return only available, allowed runtime-provided native identifiers; never invent one or bypass the agent's allowlist. Use `none` if no eligible description matches.
- Do not accept the legacy `## Skills` section, `Trigger` column, or three-column `Description | Skill | Location` schema.
- The plugin alone owns the generated snapshot; never hand-edit it or add a manual generator.

## Selection

For each work group:

1. Derive direct signals from Behavior, tasks, `Files:`, and `Verify`.
2. Select a skill only when its description directly matches assigned work; do not infer adjacent capabilities.
3. Exclude skills for planning, discovery, review, delivery, or Git even when a description matches.
4. Remove duplicates and preserve source order. Return at most three names.
5. Use `none` when no eligible description matches.

During validation of an already assigned `Skills:` field, an unavailable or disallowed identifier or a description that contradicts the assigned work is `BLOCK skill-routing <reason>`. Runtime fallback is for discovery, not permission to replace, ignore, or guess around an assigned identifier.

## Boundaries

- Selected skills cannot expand behavior, `Files:`, validation, Git ownership, or output contracts.
- Return names, never paths. Use an ordered comma-separated list or `none`; the caller owns formatting and execution scope.
