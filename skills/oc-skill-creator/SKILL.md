---
name: oc-skill-creator
description: "Create or change an oc-* skill that follows the repository skill contract. Trigger: create a new skill, add agent instructions, document a pattern for AI."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "4.2.1"
  status: in-progress
---

# Skill Creator

## Intent

- **Goal:** Create or change one skill that follows the repository skill contract below.
- **Limits:**
  - Do not create a skill for a one-off task, a trivial pattern, or knowledge that already has a document. Add a reference instead.
  - Never copy skill bodies. No symlinks.
  - No Keywords section, no troubleshooting section, no web URLs in references.
- **Fails if:** the skill already exists in `skills/*/SKILL.md`. `SKILL.md` exceeds its line cap (80 lines; 120 for the coordinator skills `oc-plan` and `oc-build`) or `description` exceeds 160 characters. A frontmatter rule below is broken or a required IDSD field is missing.

## Context

- **Reads:** existing skills; `CONTRIBUTING.md` (`## IDSD format`, `## Skills`); `standards/writing-conventions.md`.
- **Scope:** create or change a skill, add agent instructions, or record a repeated pattern for AI.

## Expectations

- **Scenarios:** WHEN a high-impact discipline skill fails reproducibly while available THEN run the pilot in [references/behavioral-evaluation.md](references/behavioral-evaluation.md). It is never a routine step or CI gate.
- **Done means:** `skills/<name>/SKILL.md` exists with complete frontmatter, an IDSD body with every required field, and no more lines than its cap. Its version and status are correct.
- **Quality needs:** ASD-STE100 text; critical rules first; tables for decisions; literal triggers and return lines kept exactly.

## Method

Layout: `skills/<name>/SKILL.md` (required); `assets/` for templates, schemas, and examples; `references/` for longer guidance that the agent cannot infer. A reference adds only its own procedure; it never copies the parent `Limits` or `Fails if`.

Body: the IDSD headings and bold field labels from `CONTRIBUTING.md` `## IDSD format`, kept terse. State intent first.

| Field | Rule |
|---|---|
| `Goal`, `Limits`, `Fails if`, `Reads`, `Scope`, `Done means`, `Method` | Required. A reference can omit `Method` if it adds no method. |
| `Never reads`, `Persona`, `Quality needs` | Optional. Omit if `none`, empty, or a restatement of the title or `Goal`. Put each rule in one field only. |
| `Scenarios` | Optional. Only real branches and edge cases; never repeat `Method`. |

Write for a small model:

1. Use short positive sentences.
2. Give concrete numbered steps for the main path.
3. Give one small example where a format matters. Use an exact format only when a program parses it.
4. Keep `Fails if` to three items maximum. Do not write long lists of prohibitions.
5. Keep owner conventions and project contracts. Delete general practice that a model can infer, and legacy notes ("formerly ...").

| Frontmatter | Rule |
|---|---|
| `name` | `oc-<short-name>`, kebab-case, at most three short words after the prefix, equal to the directory |
| `description` | one line, 160 characters maximum: what it does plus its most useful `Trigger:` keywords |
| `license` | usually `MIT` or `Apache-2.0` |
| `metadata.author` | author or maintainer |
| `metadata.version` | SemVer string, `1.0.0` for a new skill. Patch for wording or path fixes, minor for new capabilities, major for changed or reduced activation or output contract |
| `metadata.status` | `backlog`, `in-progress`, `testing`, or `done`; `testing` for a new skill |
