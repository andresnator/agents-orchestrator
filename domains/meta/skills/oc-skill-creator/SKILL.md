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
  version: "3.1.0"
  status: in-progress
---

# Skill Creator

## Intent

- **Goal:** Create or change one reusable skill with a single body, complete frontmatter, and an IDSD body.
- **Limits:**
  - Do not create a skill when documentation already exists (create a reference instead), the pattern is trivial or self-explanatory, or the task is one-off.
  - Never copy skill bodies; never keep an exclusive skill at the top level.
  - No Keywords section (agents search frontmatter), no troubleshooting sections, no lengthy explanations or duplicated docs (reference instead), no web URLs in references (use local paths).
- **Fails if:** the skill already exists (check `domains/*/skills/*/SKILL.md` and `skills/*/SKILL.md`); frontmatter `name` differs from the directory basename or is not `oc-<short-name>`; `metadata.version` is not strict SemVer or `metadata.status` misstates lifecycle; a multi-domain skill lacks a symlink from every owner; no manual coverage key was updated and no new immutable manual case was added.

## Context

- **Reads:** existing skills, `CONTRIBUTING.md` (`## IDSD format`, `## Skills`), and `references/behavioral-evaluation.md` when applicable.
- **Never reads:** none.
- **Persona:** concise skill author.
- **Scope:** the user asks to create or change a skill, add agent instructions, or document patterns for AI; create one only when a pattern is used repeatedly and AI needs guidance; project conventions differ from generic best practices; complex workflows need step-by-step guidance; decision trees help AI choose the right approach.

## Expectations

- **Scenarios:**
  - WHEN one domain uses the skill THEN its body is `domains/{domain}/skills/{skill-name}/`.
  - WHEN multiple domains use it THEN one body lives at `skills/{skill-name}/` and every owner links `domains/<domain>/skills/<skill-name> -> ../../../skills/<skill-name>`.
  - WHEN a high-impact discipline skill shows a reproducible agent failure despite being available THEN run the bounded pilot in [references/behavioral-evaluation.md](references/behavioral-evaluation.md): pre-written criteria, a no-guidance control, multiple fresh-context runs per arm, preserved raw receipts, manual scoring, reported variance and cost. Never a routine step or CI gate; `python3 scripts/lint-manual-tests.py` validates catalog metadata, links, and coverage, not model behavior.
- **Done means:** the skill exists at the right location with complete frontmatter (description includes trigger keywords), an IDSD body with every ICE field, accurate version and status, and updated manual coverage.
- **Quality needs:** most critical rules first; tables for decision trees; minimal, focused examples; a commands block only when repeatable commands are part of the contract.

## Method

### Structure

```
{skill-root}/{skill-name}/      # skill-root: domains/{domain}/skills or skills
├── SKILL.md                    # Required
├── assets/                     # Optional: generated templates, schemas, fixtures, examples
└── references/                 # Optional: longer guidance, edge cases, explanatory docs
```

Concrete generated material goes in `assets/`; explanatory material goes in `references/`.

### SKILL.md template

```markdown
---
name: oc-{short-name}
description: >
  {One-line description of what this skill does}.
  Trigger: {When the AI should load this skill}.
license: Apache-2.0
metadata:
  author: {author}
  version: "1.0.0"
  status: backlog
---

# {Title}

## Intent

- **Goal:** {one observable outcome}
- **Limits:** {boundaries, forbidden actions}
- **Fails if:** {observable failure conditions}

## Context

- **Reads:** {inputs and evidence}
- **Never reads:** {excluded sources}
- **Persona:** {role and stance}
- **Scope:** {activation and where it applies}

## Expectations

- **Scenarios:** {WHEN ... THEN ...}
- **Done means:** {completion criteria and return contract}
- **Quality needs:** {quality bar}

## Method

{Optional: decision tables, formats, commands, and resource pointers such as [assets/](assets/) and [references/](references/).}
```

### Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | `oc-<short-name>`: kebab-case, at most three short words after the prefix |
| `description` | Yes | What + Trigger in one block |
| `license` | Yes | Commonly `MIT` or `Apache-2.0` |
| `metadata.author` | Yes | Skill author or maintainer |
| `metadata.version` | Yes | Semantic version as string |
| `metadata.status` | Yes | `backlog`, `in-progress`, `testing`, or `done` |

Version bumps: patch for wording/path/template/internal contract fixes, minor for new capabilities or optional flows, major for breaking activation/output behavior.
