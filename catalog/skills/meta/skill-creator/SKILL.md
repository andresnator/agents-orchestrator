---
name: skill-creator
description: >
  Creates new AI agent skills following the Agent Skills spec.
  Trigger: When user asks to create a new skill, add agent instructions, or document patterns for AI.
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "1.1.1"
  status: in-progress
---

## When to Create a Skill

Create a skill when:
- A pattern is used repeatedly and AI needs guidance
- Project-specific conventions differ from generic best practices
- Complex workflows need step-by-step instructions
- Decision trees help AI choose the right approach

**Don't create a skill when:**
- Documentation already exists (create a reference instead)
- Pattern is trivial or self-explanatory
- It's a one-off task

---

## Skill Structure

```
catalog/skills/{domain}/{skill-name}/
├── SKILL.md              # Required - main skill file
├── assets/               # Optional - generated templates, schemas, fixtures, examples
│   ├── template.py
│   └── schema.json
└── references/           # Optional - longer guidance, edge cases, explanatory docs
    └── guidance.md
```

---

## SKILL.md Template

```markdown
---
name: {skill-name}
description: >
  {One-line description of what this skill does}.
  Trigger: {When the AI should load this skill}.
license: Apache-2.0
metadata:
  author: {author}
  version: "1.0.0"
  status: backlog
---

## When to Use

{Bullet points of when to use this skill}

## Critical Patterns

{The most important rules - what AI MUST know}

## Code Examples

{Minimal, focused examples}

## Commands

```bash
{Common commands}
```

## Resources

- **Templates**: See [assets/](assets/) for {description}
- **Documentation**: See [references/](references/) for local docs
```

---

## Naming Conventions

| Type | Pattern | Examples |
|------|---------|----------|
| Generic skill | `catalog/skills/{domain}/{technology}` | `catalog/skills/java/java-testing` |
| Project-specific | `catalog/skills/{domain}/{project}-{component}` | `catalog/skills/engineering/myapp-api` |
| Testing skill | `catalog/skills/{domain}/{project}-test-{component}` | `catalog/skills/java/myapp-test-api` |
| Workflow skill | `catalog/skills/{domain}/{action}-{target}` | `catalog/skills/meta/skill-creator` |

---

## Decision: assets/ vs references/

```
Need generated templates?   → assets/
Need JSON schemas?          → assets/
Need fixtures/examples?     → assets/
Need conceptual guidance?   → references/
Need edge cases?            → references/
```

**Key Rule**: concrete generated material goes in `assets/`; explanatory material goes in `references/`.

---

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (lowercase, hyphens) |
| `description` | Yes | What + Trigger in one block |
| `license` | Yes | Skill license, commonly `MIT` or `Apache-2.0` |
| `metadata.author` | Yes | Skill author or maintainer |
| `metadata.version` | Yes | Semantic version as string |
| `metadata.status` | Yes | `backlog`, `in-progress`, `testing`, or `done` |

---

## Content Guidelines

### DO
- Start with the most critical patterns
- Use tables for decision trees
- Keep code examples minimal and focused
- Include Commands only when repeatable commands are part of the contract

### DON'T
- Add Keywords section (agent searches frontmatter, not body)
- Duplicate content from existing docs (reference instead)
- Include lengthy explanations (link to docs)
- Add troubleshooting sections (keep focused)
- Use web URLs in references (use local paths)

---

## Registering the Skill

After creating or changing a skill, keep `metadata.version` and `metadata.status` accurate. Use a patch bump for wording/path/template/internal contract fixes, a minor bump for new capabilities or optional flows, and a major bump for breaking activation/output behavior.

---

## Checklist Before Creating

- [ ] Skill doesn't already exist (check `catalog/skills/*/*/SKILL.md`)
- [ ] Directory is `catalog/skills/{domain}/{skill-name}/`
- [ ] Frontmatter `name` equals the skill directory basename
- [ ] Pattern is reusable (not one-off)
- [ ] Name follows conventions
- [ ] Frontmatter is complete (description includes trigger keywords)
- [ ] `metadata.version` is strict SemVer
- [ ] `metadata.status` reflects the lifecycle state
- [ ] Critical patterns are clear
- [ ] Code examples are minimal
- [ ] Commands section exists only when useful

## Resources

- **Templates**: See [assets/](assets/) for SKILL.md template
