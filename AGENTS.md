# AGENTS.md

This repo stores reusable agent artifacts, not application code. Keep additions compact, contract-focused, and runtime-agnostic by default.

## Repo Shape

- `catalog/` is the source of truth.
- `catalog/skills/{domain}/{skill}/SKILL.md` stores self-contained cross-tool skill contracts.
- `catalog/prompts/{domain}/<name>.md` stores clean Markdown prompts with no frontmatter.
- `catalog/agents/<name>.md` and `catalog/commands/<name>.md` are stubs: frontmatter plus a root-relative `prompt:` path, with no body.
- `harnesses/<tool>/` stores tool-specific installation/build rules and optional metadata overrides.
- `installers/opencode.sh` builds and symlinks catalog components into OpenCode.
- `build/` is generated and ignored. Do not edit it by hand.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or documented test command in this repo.
- `.atl/` is ignored local tool state; if `.atl/skill-registry.md` exists, treat it as a generated index. `SKILL.md` remains the source of truth.

## Skill Files

- Skills live as one directory per skill with the runtime contract in `SKILL.md`.
- Skill frontmatter uses `name`, `description`, `license`, and `metadata` with `author`, strict SemVer `version` such as `"1.0.0"`, and `status`.
- `metadata.status` is the lifecycle mechanism: `backlog`, `in-progress`, `testing`, or `done`. Changing state means editing that field and applying a patch version bump, not moving the skill directory.
- When a skill changes, bump `metadata.version` in the same change: patch for wording/path/template/internal contract fixes, minor for new capabilities or optional flows, and major for breaking activation/output behavior.
- Keep `SKILL.md` concise; move long examples/templates to `references/` or `assets/`.
- Put concrete generated templates, schemas, fixtures, and generated examples in `assets/`; keep `references/` for conceptual guidance, edge cases, and longer explanatory docs.
- To refresh the generated skill registry when needed, run the `skill-registry` skill.
- Agent-agnostic rule: do not add runtime tool allowlists; runtime-specific tool names may appear only as examples with a generic fallback. Use `catalog/skills/meta/native-question-ux` for portable question presentation.
- Forked skills keep their original author and license, and record `metadata.adapted_by` plus `metadata.source`.

## Agent And Command Stubs

- Stubs are flat files under `catalog/agents/` and `catalog/commands/`.
- Stub `name` must equal the filename without `.md`.
- Stub `prompt` must be a path relative to the repo root, for example `catalog/prompts/refactor/refactorch.md`.
- Prompt files must be Markdown-only and must not start with frontmatter.
- Stub `description` must be a single line.
- Agent stubs include `mode: primary | subagent` and a `permission` block copied from the portable contract.
- Command stubs include `argument-hint` for catalog readability; OpenCode builds remove it.
- Optional command `agent:` may identify the target agent for harnesses that support it.
- Stub frontmatter includes `license` and `metadata.author`, `metadata.version`, and `metadata.status`.
- Forked agent or command stubs keep their original author and license, and record `metadata.adapted_by` plus `metadata.source`.
- Components that share a natural name across agent and command prompts must disambiguate prompt filenames, for example `boundary-inspector-agent.md` and `boundary-inspector-command.md`.

## Harness Overrides

- Harnesses express only runtime differences. Do not fork prompt bodies for routine metadata differences.
- OpenCode overrides live under `harnesses/opencode/overrides/{agents,commands}/<name>.md`.
- Override files are frontmatter-only.
- Override merge is shallow by top-level key, and the override wins.
- If no override exists, the catalog stub builds directly through the OpenCode whitelist.
- Skills are linked as directories and are not rewritten by harness assembly.

## OpenCode Installer

Use:

```bash
installers/opencode.sh install [--project] [--all] [--status s1,s2] [--force] [--dry-run] [--target DIR]
installers/opencode.sh uninstall [--project] [--target DIR] [--dry-run]
installers/opencode.sh status [--project] [--target DIR]
```

- Default target is `~/.config/opencode`.
- `--project` targets `./.opencode` from the current working directory.
- `--target DIR` is intended for tests and explicit alternate installs.
- Default filter is `done,testing`; `--all` installs every lifecycle state.
- The installer writes `$TARGET/.agents-orchestrator-manifest` with `link<TAB>source<TAB>destination` entries and `dir<TAB>created<TAB>path` entries for directories it creates, and uninstalls only entries whose current filesystem state still matches manifest ownership.
- `build/opencode/` is regenerated on each install. Agent and command symlinks point to built files; skill symlinks point directly to catalog skill directories.

## Adding A Component

1. Add or update the prompt under `catalog/prompts/{domain}/`.
2. Add a stub under `catalog/agents/` or `catalog/commands/`, or add a skill directory under `catalog/skills/{domain}/`.
3. Set `metadata.status` deliberately. The default installer only includes `done` and `testing`.
4. Bump `metadata.version` when changing an existing component.
5. Add a harness override only for real runtime-specific metadata differences.
6. Run `installers/opencode.sh install --dry-run` to confirm discovery and build behavior.

Adding a component must not require editing `installers/opencode.sh`.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly.
- For OpenCode installer changes, run `bash -n installers/opencode.sh`; run `shellcheck installers/opencode.sh` if available.
- For install behavior, use `installers/opencode.sh install --target <scratch> --all` and inspect the manifest plus symlinks.
- Do not commit unless explicitly asked.
