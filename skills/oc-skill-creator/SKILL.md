---
name: oc-skill-creator
description: >
  Creates new AI agent skills following the Agent Skills spec.
  Trigger: When user asks to create a new skill, add agent instructions, or document patterns for AI.
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "4.0.0"
  status: in-progress
---

# Skill Creator

## Intent

- **Goal:** Create or change one skill that follows the repository skill contract below.
- **Limits:**
  - Do not create a skill for a one-off task, a trivial pattern, or knowledge that already has a document. Add a reference instead.
  - Never copy skill bodies. No symlinks.
  - No Keywords section, no troubleshooting section, no web URLs in references.
- **Fails if:** the skill already exists in `skills/*/SKILL.md`; `name` differs from the directory basename or is not `oc-<short-name>`; `SKILL.md` has more than 80 lines; `metadata.version` is not strict SemVer; `metadata.status` misstates the lifecycle.

## Context

- **Reads:** existing skills; `CONTRIBUTING.md` (`## IDSD format`, `## Skills`); `standards/writing-conventions.md`.
- **Never reads:** none.
- **Persona:** concise skill author.
- **Scope:** create or change a skill, add agent instructions, or record a repeated pattern for AI.

## Expectations

- **Scenarios:**
  - WHEN you write a skill THEN state intent first: goal, limits, fails-if, and expected output.
  - WHEN content is general practice or procedure that a capable agent can infer THEN delete it.
  - WHEN content is an owner convention, an exact format, or a project contract THEN keep it.
  - WHEN a high-impact discipline skill fails reproducibly while available THEN run the pilot in [references/behavioral-evaluation.md](references/behavioral-evaluation.md). It is never a routine step or CI gate.
- **Done means:** `skills/<name>/SKILL.md` exists with complete frontmatter, an IDSD body with every field, at most 80 lines, and a correct version and status.
- **Quality needs:** ASD-STE100 text; critical rules first; tables for decisions; literal triggers and return lines kept exactly.

## Method

Layout: `skills/<name>/SKILL.md` (required); `assets/` for templates, schemas, and examples; `references/` for longer guidance that the agent cannot infer.

Body: the IDSD headings and bold field labels from `CONTRIBUTING.md` `## IDSD format`, kept terse.

| Frontmatter | Rule |
|---|---|
| `name` | `oc-<short-name>`, kebab-case, at most three short words after the prefix, equal to the directory |
| `description` | what it does plus `Trigger:` keywords, in one block |
| `license` | usually `MIT` or `Apache-2.0` |
| `metadata.author` | author or maintainer |
| `metadata.version` | SemVer string: patch for wording or path fixes, minor for new capabilities, major for changed or reduced activation or output contract |
| `metadata.status` | `backlog`, `in-progress`, `testing`, or `done` |
