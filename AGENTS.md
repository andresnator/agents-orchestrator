# AGENTS.md

This repo stores reusable agent artifacts, not application code. Keep additions compact and contract-focused.

## Repo Shape

- Skills are organized by domain under `skills/{engineering,java,knowledge,meta,product-docs,sdd}/<skill>/`.
- Commands are flat Markdown files under `commands/`.
- `agents/` still uses lifecycle staging with `backlog/`, `in-progress/`, `testing/`, and `done/`; that area is intentionally left for a later phase.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or documented test command in this repo.
- `.atl/` is ignored local tool state; if `.atl/skill-registry.md` exists, treat it as a generated index. `SKILL.md` remains the source of truth.

## Skill Files

- Skills live as one directory per skill with the runtime contract in `SKILL.md`.
- Skill frontmatter uses `name`, `description`, `license`, and `metadata` with `author`, strict SemVer `version` such as `1.0.0`, and `status`.
- `metadata.status` is the lifecycle mechanism: `backlog`, `in-progress`, `testing`, or `done`. Changing state means editing that field and applying a patch version bump, not moving the skill directory.
- When a skill changes, bump `metadata.version` in the same change: patch for wording/path/template/internal contract fixes, minor for new capabilities or optional flows, and major for breaking activation/output behavior.
- Keep `SKILL.md` concise; move long examples/templates to `references/` or `assets/`.
- Put concrete generated templates, schemas, fixtures, and generated examples in `assets/`; keep `references/` for conceptual guidance, edge cases, and longer explanatory docs.
- To refresh the generated skill registry when needed, run the `skill-registry` skill.
- Agent-agnostic rule: do not add runtime tool allowlists; runtime-specific tool names may appear only as examples with a generic fallback. Use `skills/meta/native-question-ux` for portable question presentation.
- Forked skills keep their original author and license, and record `metadata.adapted_by` plus `metadata.source`.

## Agent And Command Files

- Subagents are Markdown files with frontmatter like `description`, `mode: subagent`, and explicit `permission` entries for `edit`, `bash`, and `webfetch`.
- Commands are Markdown files with frontmatter `description` and `argument-hint`; the H1 names the slash command, for example `# /english`.
- Commands should hand off to the relevant subagent/skill instead of duplicating the full skill contract.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly; there is no repo-level automated validation command.
- Do not commit unless explicitly asked.
