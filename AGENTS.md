# AGENTS.md

This repo stores reusable OpenCode agent artifacts, not application code. Keep additions compact, contract-focused, and domain-organized.

**This repo targets OpenCode only.** Do not add Claude Code (or other runtime) artifacts, and do not manage `~/.claude/**` state from this repo.

## Repo Shape

- `domains/` is the source of truth for agents, commands, plugins, and domain skill usage.
- `skills/` is the source of truth for reusable skill bodies.
- `domains/{sdd,refactor,architecture,docs,meta,common}/README.md` explains each domain.
- `domains/<domain>/agents/<name>.md` stores one fused OpenCode agent file: frontmatter plus prompt body.
- `domains/<domain>/commands/<name>.md` stores one fused OpenCode command file: frontmatter plus prompt body.
- `skills/<skill>/SKILL.md` stores self-contained skill contracts.
- `domains/<domain>/skills/<skill>` is a relative symlink to `skills/<skill>` that declares domain usage.
- `domains/<domain>/plugins/*.ts` stores OpenCode plugins installed with that domain.
- `global/AGENTS.md` is the installable global OpenCode rules file (agent personality, skill-registry usage, documentation rules, and the context7 block); the installer links it to `$TARGET/AGENTS.md`.
- `docs/` stores workflow notes and migration records.
- `installers/opencode.sh` symlinks selected domain components into OpenCode.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or documented test command in this repo.
- `.ai/` is ignored local tool state. `.ai/atl/skill-registry.md` is the generated index produced by the meta `skill-registry` plugin; `.atl/` is legacy ignored state during migration. Top-level `skills/<skill>/SKILL.md` remains the source of truth for skills.

## Domains

- `sdd`: spec-driven development around the `orchestraitor` primary agent, SDD drafting skills, and judgment-day agents; adopts ready-for-sdd planner bundles (see `docs/plan-handoff.md`).
- `refactor`: risk-gated refactor and test-hardening (CDD) planning that produces ready-for-sdd OpenSpec change bundles adopted by the sdd `orchestraitor`, plus Java refactor skills.
- `architecture`: project-architecture mapping (C4-lite Mermaid docs), state reviews with gap analysis, reverse-engineered PRDs, security/observability audits, and ADR + ready-for-sdd ideation bundles adopted by the sdd `orchestraitor`.
- `plan`: Fable-style deep planning for features and changes (evidence-first, edge-case validation) producing single plan documents under `.ai/plan-architect/plans/`.
- `docs`: product docs, Jira ticketing, English tutoring, summaries, and transcription skills.
- `meta`: prompt and skill maintenance utilities.
- `common`: shared engineering, quality, question UX, and output-refinement skills.

## Agents And Commands

- Component names must be unique globally within their type because OpenCode targets are flat.
- Do not use `name:` or `prompt:` in agent or command frontmatter; OpenCode derives the name from the filename and the prompt is the file body.
- Agent frontmatter order: `description`, `mode`, `temperature?`, `permission`, `tools?`, `disable?`.
- Command frontmatter order: `description`, `agent?`, `model?`, `subtask?`, `argument-hint?`.
- Do not add `license` or `metadata` to agent or command frontmatter; OpenCode routes unrecognized agent fields into model options and providers can reject them.
- `argument-hint` may remain inline; OpenCode tolerates extra frontmatter keys.
- Agent `mode` is `primary` or `subagent`.
- Do not hardcode `model:` (or provider/variant options) in agent frontmatter; agents stay provider-agnostic and per-agent model assignment is user-side via `opencode.json`, documented in `docs/agent-models.md`.
- Stub/prompt/override splitting is gone. Do not add separate prompt files for new components.
- Track fork attribution for agents or commands outside OpenCode frontmatter; do not put attribution fields in executable agent or command metadata.

## Skill Files

- Skills live as one top-level directory per skill under `skills/`, with the runtime contract in `SKILL.md`.
- Domain skill folders contain only symlinks to top-level skills. Add, remove, or move a domain symlink to change which domain uses a skill.
- Skill frontmatter uses `name`, `description`, `license`, and `metadata` with `author`, strict SemVer `version` such as `"1.0.0"`, and `status`.
- `metadata.status` is the lifecycle mechanism: `backlog`, `in-progress`, `testing`, or `done`. Changing state means editing that field and applying a patch version bump, not moving the skill directory.
- When a skill changes, bump `metadata.version` in the same change: patch for wording/path/template/internal contract fixes, minor for new capabilities or optional flows, and major for breaking activation/output behavior.
- Keep `SKILL.md` concise; move long examples/templates to `references/` or `assets/`.
- Put concrete generated templates, schemas, fixtures, and generated examples in `assets/`; keep `references/` for conceptual guidance, edge cases, and longer explanatory docs.
- Agent-agnostic rule: do not add runtime tool allowlists; runtime-specific tool names may appear only as examples with a generic fallback. Use `skills/native-question-ux` for portable question presentation.
- Forked skills keep their original author and license, and record `metadata.adapted_by` plus `metadata.source`.

## OpenCode Installer

Use:

```bash
installers/opencode.sh install [--domain d1,d2] [--status s1,s2] [--project] [--target DIR] [--dry-run] [--force]
installers/opencode.sh uninstall [--project] [--target DIR] [--dry-run]
installers/opencode.sh status [--domain d1,d2] [--status s1,s2] [--project] [--target DIR]
```

- Default target is `~/.config/opencode`.
- `--project` targets `./.opencode` from the current working directory.
- Default filter is `--domain all --status all`.
- Valid skill statuses are `backlog`, `in-progress`, `testing`, and `done`; agents, commands, and plugins are not status-filtered.
- The installer discovers agent/command regular files and domain skill symlinks. Installed skill links point to the top-level `skills/` directory.
- `install` always links `global/AGENTS.md` to `$TARGET/AGENTS.md` regardless of `--domain`/`--status` filters. A pre-existing foreign `AGENTS.md` in the target is skipped with a warning unless `--force`.
- The installer writes `$TARGET/.agents-orchestrator-manifest` with `link<TAB>dest` and `dir<TAB>path` lines.
- `install` is a sync: links from the previous manifest that are no longer selected are removed.
- `uninstall` removes manifest-owned symlinks and empty created directories.

## Adding A Component

1. Pick the domain first: `sdd`, `refactor`, `architecture`, `docs`, `meta`, or `common`.
2. Add one fused file under `domains/<domain>/agents/` or `domains/<domain>/commands/`, or add one skill directory under `skills/` plus a symlink from each using domain under `domains/<domain>/skills/`.
3. For skills, set `metadata.status` deliberately. The installer includes all statuses unless filtered.
4. For skills, bump `metadata.version` when changing an existing skill.
5. Add a plugin under `domains/<domain>/plugins/` only for real OpenCode runtime behavior.
6. Run `installers/opencode.sh install --dry-run` to confirm discovery and link behavior.

Adding a component must not require editing `installers/opencode.sh`.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly.
- For OpenCode installer changes, run `bash -n installers/opencode.sh`; run `shellcheck installers/opencode.sh` if available.
- For install behavior, use `installers/opencode.sh install --target <scratch>` and inspect the manifest plus symlinks.
- For structure checks, count `domains/*/agents/*.md`, `domains/*/commands/*.md`, `skills/*/SKILL.md`, and `domains/*/skills/*` symlinks.
- Do not commit unless explicitly asked.
