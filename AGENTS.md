# AGENTS.md

This repo stores reusable agent artifacts, not application code. Keep additions compact, contract-focused, and domain-organized.

**OpenCode is the reference runtime and the authoring format.** Components are written once in OpenCode format and installed into OpenCode, Claude Code, and Codex CLI via sibling installers (see `docs/runtime-matrix.md`). Do not add runtime-specific component variants to the repo; the installers transform at install time. The repo stores no runtime state — installers write into targets like `~/.claude` or `~/.codex`, but those directories never become repo artifacts.

## Repo Shape

- `domains/` is the source of truth for agents, commands, plugins, and domain skill usage.
- `skills/` is the source of truth for reusable skill bodies.
- `domains/{sdd,refactor,architecture,plan,docs,meta,common}/README.md` explains each domain.
- `domains/<domain>/agents/<name>.md` stores one fused OpenCode agent file: frontmatter plus prompt body.
- `domains/<domain>/commands/<name>.md` stores one fused OpenCode command file: frontmatter plus prompt body.
- `skills/<skill>/SKILL.md` stores self-contained skill contracts.
- `domains/<domain>/skills/<skill>` is a relative symlink to `skills/<skill>` that declares domain usage.
- `domains/<domain>/plugins/*.ts` stores OpenCode plugins installed with that domain.
- `global/AGENTS.md` is the installable global rules file (agent personality, skill-registry usage, documentation rules, and the context7 block); installers link it to `$TARGET/AGENTS.md` (OpenCode), `$TARGET/rules/agents-orchestrator.md` (Claude Code), or `~/.codex/AGENTS.md` (Codex).
- `docs/` stores workflow notes and migration records.
- `profiles/<name>.json` stores abstract model-tier profiles (agents grouped by tier, optional suggested variant, never concrete model ids) consumed by `scripts/configure-models.sh`.
- `scripts/configure-models.sh` is the interactive per-agent model/variant wizard; it writes user OpenCode config, never repo artifacts (see `docs/agent-models.md`).
- `installers/opencode.sh`, `installers/claude.sh`, and `installers/codex.sh` install selected domain components into their runtimes; `installers/lib/common.sh` is the shared discovery/manifest library.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or documented test command in this repo.
- `.ai/` is ignored local tool state. `.ai/atl/skill-registry.md` is the generated index produced by the meta `skill-registry` plugin; `.atl/` is legacy ignored state during migration. Top-level `skills/<skill>/SKILL.md` remains the source of truth for skills.
- Runtime state directories such as `.engram/`, `.claude/`, `.cursor/`, or tool-local memory chunks must not become managed repo artifacts unless explicitly adopted as an OpenCode component.

## Domains

- `sdd`: spec-driven development around the `orchestraitor` primary agent, SDD drafting skills, and judgment-day agents; adopts ready-for-sdd planner bundles (see `docs/plan-handoff.md`).
- `refactor`: risk-gated refactor and test-hardening (CDD) planning that produces ready-for-sdd OpenSpec change bundles adopted by the sdd `orchestraitor`, plus Java refactor skills.
- `architecture`: project-architecture mapping (C4-lite Mermaid docs), state reviews with gap analysis, reverse-engineered PRDs, security/observability audits, and ADR + ready-for-sdd ideation bundles adopted by the sdd `orchestraitor`.
- `plan`: Fable-style deep planning for features and changes (evidence-first, edge-case validation) producing single plan documents under `.ai/deep-planner/plans/`, plus `/wayfinder` multi-session discovery maps under `.ai/wayfinder/` for efforts too foggy to plan in one sitting.
- `docs`: product docs, Jira ticketing, English tutoring, summaries, and transcription skills.
- `meta`: prompt and skill maintenance utilities.
- `common`: shared engineering, quality, question UX, and output-refinement skills.

## Agents And Commands

- Component names must be unique globally within their type because installer targets are flat in every runtime.
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

## Installers

All three share the same CLI surface:

```bash
installers/<runtime>.sh install [--domain d1,d2] [--status s1,s2] [--project] [--target DIR] [--dry-run] [--force]
installers/<runtime>.sh uninstall [--project] [--target DIR] [--dry-run]
installers/<runtime>.sh status [--domain d1,d2] [--status s1,s2] [--project] [--target DIR]
```

- `opencode.sh`: default target `~/.config/opencode`, `--project` targets `./.opencode`; everything is symlinked; global rules link to `$TARGET/AGENTS.md`.
- `claude.sh`: default target `~/.claude`, `--project` targets `./.claude`; skills are symlinked, agents/commands are generated files with translated frontmatter, global rules link to `$TARGET/rules/agents-orchestrator.md` (never `CLAUDE.md` or settings files).
- `codex.sh`: default roots `~/.codex` + `~/.agents/skills`; `--target DIR` acts as a fake `$HOME`; skills are symlinked, agents are generated TOML, commands are generated custom prompts (user-level only), global rules link to `~/.codex/AGENTS.md`. `--project` installs agents and skills only.
- Default filter is `--domain all --status all`.
- Valid skill statuses are `backlog`, `in-progress`, `testing`, and `done`; agents, commands, and plugins are not status-filtered.
- Installers discover agent/command regular files and domain skill symlinks. Installed skill links point to the top-level `skills/` directory.
- `install` always installs the global rules regardless of `--domain`/`--status` filters. A pre-existing foreign destination is skipped with a warning unless `--force`.
- Each installer writes `.agents-orchestrator-manifest` in its manifest root with `link<TAB>dest`, `file<TAB>dest` (generated files), and `dir<TAB>path` lines.
- `install` is a sync: links and generated files from the previous manifest that are no longer selected are removed (type-guarded, so user-replaced files are never deleted).
- `uninstall` removes manifest-owned symlinks and generated files plus empty created directories.
- Generated files do not auto-update when the repo changes; re-run install. `status` reports them as `generated`, `stale`, `foreign`, or `not installed`.
- The OpenCode `skill-registry` plugin is not portable; Claude Code and Codex discover skills natively. See `docs/runtime-matrix.md` for the full mapping and portability caveats.

## Adding A Component

1. Pick the domain first: `sdd`, `refactor`, `architecture`, `plan`, `docs`, `meta`, or `common`.
2. Add one fused file under `domains/<domain>/agents/` or `domains/<domain>/commands/`, or add one skill directory under `skills/` plus a symlink from each using domain under `domains/<domain>/skills/`.
3. For skills, set `metadata.status` deliberately. The installer includes all statuses unless filtered.
4. For skills, bump `metadata.version` when changing an existing skill.
5. Add a plugin under `domains/<domain>/plugins/` only for real OpenCode runtime behavior.
6. Run `installers/opencode.sh install --dry-run` to confirm discovery and link behavior.

Adding a component must not require editing any installer.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly.
- For installer changes, run `bash -n` on the touched scripts; `scripts/validate-harness.sh` syntax-checks all installers plus `installers/lib/common.sh` and runs `shellcheck -x` when available.
- For install behavior, use `installers/<runtime>.sh install --target <scratch>` and inspect the manifest, symlinks, and generated files. For Codex agents, parse the generated TOML (e.g. `python3 -c "import tomllib, ..."` with Python >= 3.11).
- For structure checks, run `scripts/validate-harness.sh`: it enforces agent/command frontmatter contracts (forbidden keys, key order, mode values), skill frontmatter (name/description/license, strict SemVer `metadata.version`, valid `metadata.status`), domain skill symlink integrity, global agent/command name uniqueness, profile JSON shape (valid JSON, no agent in two tiers, agents must exist; jq-gated), and script syntax for all installers and `scripts/configure-models.sh`.
- For wizard changes, test non-destructively with `scripts/configure-models.sh --dry-run --target <scratch> --catalog <fixture>` piping numbered answers on stdin.
- Do not commit unless explicitly asked.
