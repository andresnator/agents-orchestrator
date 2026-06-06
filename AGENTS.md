# AGENTS.md

This repo stores reusable agent artifacts, not application code. Keep additions compact and contract-focused.

## Repo Shape

- Work areas are staged under `agents/`, `commands/`, and `skills/` with `backlog/`, `in-progress/`, and `done/` subdirectories.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or documented test command in this repo.
- `.atl/` is ignored local tool state; if `.atl/skill-registry.md` exists, treat it as a generated index. `SKILL.md` remains the source of truth.

## Skill Files

- Skills live as one directory per skill with the runtime contract in `SKILL.md`.
- Skill frontmatter uses `name`, `description`, `license`, and `metadata` with `author` plus strict SemVer `version` such as `1.0.0`.
- Keep `SKILL.md` concise; move long examples/templates to `references/` or `assets/`.
- To refresh the generated skill registry when needed, use `gentle-ai skill-registry refresh --force`.

## Agent And Command Files

- Subagents are Markdown files with frontmatter like `description`, `mode: subagent`, and explicit `permission` entries for `edit`, `bash`, and `webfetch`.
- Commands are Markdown files with frontmatter `description` and `argument-hint`; the H1 names the slash command, for example `# /english`.
- Commands should hand off to the relevant subagent/skill instead of duplicating the full skill contract.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly; there is no repo-level automated validation command.
- Do not commit unless explicitly asked.
