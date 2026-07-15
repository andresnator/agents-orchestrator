# AGENTS.md

This repo stores reusable agent artifacts, not application code. Keep additions compact, contract-focused, and domain-organized.

**OpenCode is the runtime and the authoring format.** Components are written in OpenCode format and installed into OpenCode via `installers/opencode.sh`. The repo stores no runtime state — the installer writes into targets like `~/.config/opencode`, but those directories never become repo artifacts.

## Repo Shape

- All documentation and descriptive text in this repo — including READMEs, `docs/`, skill contracts, frontmatter descriptions, and comments — is written in English. Preserve literal runtime trigger phrases (for example, `"ejecuta el plan <change>"` and Spanish skill triggers) because they are activation contracts, not documentation; translating existing legacy Spanish prose is out of scope for this forward-looking rule.
- `domains/` is the source of truth for agents, commands, plugins, and domain skill usage.
- `skills/` is the source of truth for reusable skill bodies.
- `domains/{sdd,refactor,architecture,plan,learning,docs,meta,common}/README.md` explains each domain.
- `domains/<domain>/agents/<name>.md` stores one fused OpenCode agent file: frontmatter plus prompt body.
- `domains/<domain>/commands/<name>.md` stores one fused OpenCode command file: frontmatter plus prompt body.
- `skills/<skill>/SKILL.md` stores self-contained skill contracts.
- `domains/<domain>/skills/<skill>` is a relative symlink to `skills/<skill>` that declares domain usage.
- `domains/<domain>/plugins/*.ts` stores OpenCode plugins installed with that domain.
- `domains/common/plugins/codegraph-init.ts` is the opt-in, non-blocking CodeGraph initializer; setup and recovery live in `docs/codegraph.md`.
- `domains/<domain>/tui-plugins/<name>.tsx` stores OpenCode TUI plugin entrypoints; each has a same-named companion directory with its sources. OpenCode-only; the installer generates copies (not symlinks) and registers the exact entry in the target's `tui.json`.
- `global/AGENTS.md` is the installable global rules file (agent personality, skill-registry usage, documentation rules, and the context7 block); the installer links it to `$TARGET/AGENTS.md`.
- `docs/` stores reference docs for live mechanisms.
- `profiles/<name>.json` stores abstract model-tier profiles (never concrete model ids) consumed by the meta `model-configurator` TUI plugin; see `docs/agent-models.md`.
- The meta `model-configurator` TUI plugin is the interactive per-agent model/variant assistant; it writes user OpenCode config, never repo artifacts (see `docs/agent-models.md` and `docs/hot-reload.md`).
- `scripts/sdd-automode.sh` toggles SDD auto-mode: per-agent `permission` blocks in user OpenCode config, never repo artifacts (see `docs/sdd-automode.md`).
- `installers/opencode.sh` installs selected domain components into OpenCode; `installers/lib/common.sh` is the discovery/manifest library.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or documented test command in this repo.
- `.ai/` is ignored local tool state. `.ai/atl/skill-registry.md` is the generated index produced by the meta `skill-registry` plugin; `.atl/` is legacy ignored state during migration. Top-level `skills/<skill>/SKILL.md` remains the source of truth for skills.
- Runtime state directories such as `.engram/`, `.claude/`, `.cursor/`, or tool-local memory chunks must not become managed repo artifacts unless explicitly adopted as an OpenCode component.

## Domains

Each `domains/<domain>/README.md` is the authoritative description; one-liners:

- `sdd`: spec-driven development around the `orchestraitor` primary agent; adopts ready-for-sdd planner bundles (see `docs/plan-handoff.md`).
- `refactor`: risk-gated refactor and test-hardening (CDD) planning producing ready-for-sdd bundles, plus Java refactor skills.
- `architecture`: architecture mapping, state reviews, reverse-engineered PRDs, audits, and ADR + ideation bundles.
- `plan`: Fable-style deep planning (`/deep-plan`) and `/wayfinder` multi-session discovery maps under `.ai/`.
- `learning`: interactive multi-session learning via `/learn` (see `docs/learning-domain.md`).
- `docs`: product docs, Jira ticketing, English tutoring, summaries, and transcription skills.
- `meta`: prompt and skill maintenance utilities.
- `common`: shared engineering, quality, question UX, and output-refinement skills.

## Agents And Commands

- Component names must be unique globally within their type because installer targets are flat.
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
- Transversal skills (used by 3+ domains) keep a single symlink in `common` — or in their owner domain, like `sdd-draft-*` in sdd; consuming domains declare the dependency in their README ("assumes the `common` domain is installed"), not with duplicate symlinks. Two-domain overlaps do keep both symlinks as real usage declarations.
- Skill frontmatter uses `name`, `description`, `license`, and `metadata` with `author`, strict SemVer `version` such as `"1.0.0"`, and `status`.
- `metadata.status` is the lifecycle mechanism: `backlog`, `in-progress`, `testing`, or `done`. Changing state means editing that field and applying a patch version bump, not moving the skill directory.
- When a skill changes, bump `metadata.version` in the same change: patch for wording/path/template/internal contract fixes, minor for new capabilities or optional flows, and major for breaking activation/output behavior.
- Keep `SKILL.md` concise; move long examples/templates to `references/` or `assets/`.
- Put concrete generated templates, schemas, fixtures, and generated examples in `assets/`; keep `references/` for conceptual guidance, edge cases, and longer explanatory docs.
- Agent-agnostic rule: do not add runtime tool allowlists; runtime-specific tool names may appear only as examples with a generic fallback. Use `skills/native-question-ux` for portable question presentation.
- Forked skills keep their original author and license, and record `metadata.adapted_by` plus `metadata.source`.

## Installers

CLI surface:

```bash
installers/opencode.sh install [--domain d1,d2] [--status s1,s2] [--project] [--target DIR] [--dry-run] [--force] [--reload]
installers/opencode.sh uninstall [--project] [--target DIR] [--dry-run]
installers/opencode.sh status [--domain d1,d2] [--status s1,s2] [--project] [--target DIR]
```

- Default target `~/.config/opencode`, `--project` targets `./.opencode`; everything is symlinked except TUI plugins, which are generated copies plus a managed `tui.json` entry and pinned `package.json` dependency (requires OpenCode >= 1.17.15, `python3`, and `jq`; aborts before mutation otherwise); global rules link to `$TARGET/AGENTS.md`.
- Default filter is `--domain all --status all`.
- Valid skill statuses are `backlog`, `in-progress`, `testing`, and `done`; agents, commands, plugins, and TUI plugins are not status-filtered.
- The installer discovers agent/command regular files and domain skill symlinks. Installed skill links point to the top-level `skills/` directory.
- `install` always installs the global rules regardless of `--domain`/`--status` filters. A pre-existing foreign destination is skipped with a warning unless `--force`.
- The installer writes `.agents-orchestrator-manifest` in its manifest root with `link<TAB>dest`, `file<TAB>dest` (generated files), and `dir<TAB>path` lines, plus `managed-array`/`managed-object` rows (`kind<TAB>file<TAB>field<TAB>value`) that narrowly own one exact config value each (the `tui.json` plugin entry and the `jsonc-parser` dependency). Pre-existing identical values are never claimed.
- `install` is a sync: links, generated files, and managed values from the previous manifest that are no longer selected are removed (type-guarded and exact-value-guarded, so user-replaced content is never deleted). OpenCode installs are transactional: a failure mid-install rolls the target back to its prior state.
- `uninstall` removes manifest-owned symlinks, generated files, and still-matching managed values plus empty created directories.
- Generated files do not auto-update when the repo changes; re-run install. `status` reports them as `generated`, `stale`, `foreign`, or `not installed`.
- `install --reload` additionally hot-reloads running OpenCode servers after the transaction commits (best-effort, never fails the install); plugin code still needs a restart. Mechanism in `docs/hot-reload.md`.
- The `skill-registry` plugin generates the skill index consumed at runtime (`.ai/atl/skill-registry.md`).

## Adding A Component

1. Pick the domain first: `sdd`, `refactor`, `architecture`, `plan`, `docs`, `meta`, or `common`.
2. Add one fused file under `domains/<domain>/agents/` or `domains/<domain>/commands/`, or add one skill directory under `skills/` plus a symlink from each using domain under `domains/<domain>/skills/`.
3. For skills, set `metadata.status` deliberately. The installer includes all statuses unless filtered.
4. For skills, bump `metadata.version` when changing an existing skill.
5. Add a plugin under `domains/<domain>/plugins/` only for real OpenCode runtime behavior.
6. Add a TUI plugin under `domains/<domain>/tui-plugins/` (entrypoint `<name>.tsx` plus same-named companion directory) only for interactive OpenCode UI; it is OpenCode-only by design.
7. When adding, removing, or moving a component, update the domain README's `## Components` table; if its entry points changed, update that domain's row in the root README too.
8. Run `installers/opencode.sh install --dry-run` to confirm discovery and link behavior.

Adding a component must not require editing any installer.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly.
- For installer changes, run `bash -n` on the touched scripts; `scripts/validate-harness.sh` syntax-checks `installers/opencode.sh` plus `installers/lib/common.sh` and runs `shellcheck -x` when available.
- For install behavior, use `installers/opencode.sh install --target <scratch>` and inspect the manifest, symlinks, and generated files.
- For structure checks, run `scripts/validate-harness.sh`: it enforces agent/command frontmatter contracts (forbidden keys, key order, mode values), skill frontmatter (name/description/license, strict SemVer `metadata.version`, valid `metadata.status`), domain skill symlink integrity, global agent/command/TUI-plugin name uniqueness, TUI companion-directory layout, profile JSON shape (valid JSON, no agent in two tiers, agents must exist; jq-gated), script syntax (plus `shellcheck -x` when available) for all installers and every `scripts/*.sh`, and the deterministic model-configurator shell contracts (python3/jq-gated).
- For model-configurator changes, run `scripts/test-model-configurator.sh contracts` (shell + TypeScript suites; the TypeScript half needs `npm`) and, with a real binary, `OPENCODE_BIN=<path> scripts/test-model-configurator.sh smoke`.
- For CodeGraph initializer changes, run `scripts/test-codegraph-init.sh`; it uses isolated HOME/XDG state, a fake CodeGraph binary, and OpenCode's `/global/event` stream.
- Do not commit unless explicitly asked.
