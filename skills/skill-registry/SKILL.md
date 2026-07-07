---
name: skill-registry
description: >
  Create or update the skill registry for the current project. Scans user skills and project conventions, then writes .ai/atl/skill-registry.md.
  Trigger: When user says "update skills", "skill registry", "actualizar skills", "update registry", or after installing/removing skills.
license: MIT
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  status: in-progress
  version: "2.1.2"
---

## Purpose

You generate or update the **skill registry**: a lightweight discovery index of available skills and project convention files.

The registry helps orchestrators match a trigger to a skill path. Agents then read the matched skill's `SKILL.md` directly for the full contract instead of receiving pre-digested rules from the registry.

## When to Run

- After installing or removing skills
- After setting up a new project
- When the user explicitly asks to update the registry
- As part of `sdd-init` (it calls this same logic)

## What to Do

### Step 1: Scan User Skills

1. Glob for `*/SKILL.md` files across the OpenCode-compatible skill directories below. Check every path listed — scan ALL that exist, not just the first match:

   **User-level (global skills):**
   - `~/.config/opencode/skills/` — OpenCode

   **Project-level (workspace skills):**
   - `{project-root}/.opencode/skills/` — OpenCode project skills
   - `{project-root}/.agents/skills/` — supported shared project skills
   - `{project-root}/skills/` — repository skill source

2. **SKIP `skill-registry`** — that's this skill
3. **Deduplicate** — if the same skill name appears in multiple locations, keep the project-level version (more specific). If both are user-level, keep the first found.
4. For each skill found, read only the frontmatter needed to extract:
   - `name` field (from frontmatter)
   - `description` field → extract the trigger text (after "Trigger:" in the description)
5. Build a table of: Trigger | Skill Name | Full Path

### Step 2: Scan Project Conventions

1. Check the project root for convention files. Look for:
   - `agents.md` or `AGENTS.md`
   - `CLAUDE.md` (only project-level, not `~/.claude/CLAUDE.md`)
   - `.cursorrules`
   - `GEMINI.md`
   - `copilot-instructions.md`
2. **If an index file is found** (e.g., `agents.md`, `AGENTS.md`): READ its contents and extract all referenced file paths. These index files typically list project conventions with paths — extract every referenced path except generated `.ai/**` and legacy `.atl/**` state, and include the remaining paths in the registry table alongside the index file itself.
3. For non-index files (`.cursorrules`, `CLAUDE.md`, etc.): record the file directly.
4. The final table should include the index file AND all paths it references — zero extra hops for sub-agents.

### Step 3: Write the Registry

Build the registry markdown:

```markdown
# Skill Registry

Auto-generated — do not edit. Discovery index only: match a trigger, then read the skill's SKILL.md at the listed path for its full contract.

## Skills

| Trigger | Skill | Path |
|---------|-------|------|
| {trigger from frontmatter} | {skill name} | {full path to SKILL.md} |
| ... | ... | ... |

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| {index file} | {path} | Index — references files below |
| {referenced file} | {extracted path} | Referenced by {index file} |
| {standalone file} | {path} | |

Read the convention files listed above for project-specific patterns and rules. All referenced paths have been extracted — no need to read index files to discover more.
```

### Step 4: Migrate Legacy State

Before writing, if `{project-root}/.atl/` exists and `{project-root}/.ai/atl/` does not exist, create `{project-root}/.ai/` and move `.atl/` to `.ai/atl/`. If `.ai/atl/` already exists, leave `.atl/` intact and do not overwrite anything; the old directory is legacy state.

### Step 5: Persist the Registry

**This step is MANDATORY — do NOT skip it.**

Create the `.ai/atl/` directory in the project root if it doesn't exist, then write:

```
.ai/atl/skill-registry.md
```

### Step 6: Return Summary

```markdown
## Skill Registry Updated

**Project**: {project name}
**Location**: .ai/atl/skill-registry.md

### User Skills Found
| Skill | Trigger |
|-------|---------|
| {name} | {trigger} |
| ... | ... |

### Project Conventions Found
| File | Path |
|------|------|
| {file} | {path} |

### Next Steps
The orchestrator reads this registry once per session, matches relevant skills, and reads the listed SKILL.md files for their full contracts.
To update after installing/removing skills, run this again.
```

## Rules

- ALWAYS write `.ai/atl/skill-registry.md` regardless of any SDD persistence mode
- SKIP `skill-registry` directories when scanning
- Keep the registry lightweight: include discovery metadata only, not copied skill rules
- Read matched SKILL.md files lazily when applying a skill
- Include ALL convention index files found (not just the first)
- Exclude generated `.ai/**` and legacy `.atl/**` state from Project Conventions and hash inputs
- If no skills or conventions are found, write an empty registry (so sub-agents don't waste time searching)
- Add `.ai/` to the project's `.gitignore` if it exists and `.ai` is not already listed
