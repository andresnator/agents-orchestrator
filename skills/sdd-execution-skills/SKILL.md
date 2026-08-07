---
name: sdd-execution-skills
description: "Trigger: SDD Skills field, implementation skill routing, execution skill selection. Select the smallest implementation-skill set for each change.md Work group."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# SDD Execution Skills

## Contract

Load when drafting or validating a `change.md` Work group's `Skills:` field. Select names only; producers never load the selected implementation skill bodies. Requests to follow a convention select its name but do not authorize loading it.

Every Work group requires `Skills: <csv|none>`. Missing fields, unknown names, paths, or more than three names are invalid. Split a group by responsibility when it needs more than three skills.

## Selection

Combine matching rows, remove duplicates, and preserve table order:

| Work signal | Skill name |
|---|---|
| Production or test code changes | `code-conventions` |
| Java test changes | `java-testing` |
| Tests capture current behavior before change | `behavior-characterization` |
| Untested legacy code or behavior-preserving refactor | `legacy-code-safety` |
| Reproducible defect or root-cause fix | `systematic-debugging` |
| Human-facing documentation or guides | `cognitive-doc-design` |

Use `none` only when no row matches, including canonical-spec merge or non-code configuration work. A code/test group without `code-conventions` is invalid.

## Boundaries

- Do not pass planning, analysis, review, delivery, Git, or broad refactoring-catalog skills. Write their decisions into Behavior, Approach, or Work instead.
- Selected skills cannot expand behavior, `Files:`, validation, Git ownership, or output contracts.
- Registry paths resolve availability only; never persist them in `change.md` or worker briefs.

## Output

Return the ordered comma-separated names or `none` to the caller. The caller owns artifact and A2A formatting.

## Resource

Selection examples: [assets/routing-cases.tsv](assets/routing-cases.tsv).
