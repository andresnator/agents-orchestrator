# AGENTS.md

This repo stores reusable agent artifacts, not application code. Keep additions compact, contract-focused, and domain-organized.

**OpenCode is the runtime and the authoring format.** Components are written in OpenCode format and installed into OpenCode via `installers/opencode.sh`. The repo stores no tracked runtime state — the installer writes into targets like `~/.config/opencode`, but those directories never become repo artifacts.

## Repo Shape

- All documentation and descriptive text in this repo — including READMEs, `docs/`, skill contracts, frontmatter descriptions, and comments — is written in English. Preserve literal runtime trigger phrases (for example, `"ejecuta el plan <change>"` and Spanish skill triggers) because they are activation contracts, not documentation; translating existing legacy Spanish prose is out of scope for this forward-looking rule.
- `domains/` is the source of truth for agents, commands, plugins, and domain skill usage.
- `skills/` is the source of truth for reusable skill bodies.
- `domains/{sdd,sdd-lite,refactor,architecture,plan,learning,docs,meta,common}/README.md` explains each domain.
- `domains/<domain>/agents/<name>.md` stores one fused OpenCode agent file: frontmatter plus prompt body.
- `domains/<domain>/commands/<name>.md` stores one fused OpenCode command file: frontmatter plus prompt body.
- `skills/<skill>/SKILL.md` stores self-contained skill contracts.
- `domains/<domain>/skills/<skill>` is a relative symlink to `skills/<skill>` that declares domain usage.
- `domains/<domain>/plugins/*.ts` stores repository-owned OpenCode plugins installed with that domain.
- `domains/<domain>/external-plugins/<name>.server.json` and `<name>.tui.json` lock reusable standalone plugins by version, GitHub repository, full commit, artifact path, and SHA-256. Their source, tests, and releases live in the named external repositories.
- `domains/common/external-plugins/graphify-init.server.json` pins the default-on (opt out with `OPENCODE_GRAPHIFY_AUTOINIT=0`), non-blocking Graphify graph **refresher**. First indexing remains human-gated behind `domains/common/commands/graphify-index.md`, which records the per-repo mode in `.ai/graphify-out/.opencode-index-mode`; setup and recovery live in `docs/graphify.md`.
- `global/AGENTS.md` is the installable global rules file (agent personality, skill-registry usage, documentation rules, and the context7 block); the installer links it to `$TARGET/AGENTS.md`.
- `docs/` stores reference docs for live mechanisms.
- `profiles/<name>.json` stores abstract model-tier profiles (never concrete model ids) consumed by the meta `model-configurator` TUI plugin; see `docs/agent-models.md`.
- The externally maintained meta `model-configurator` TUI plugin is the interactive per-agent model/variant assistant; it writes user OpenCode config, never repo artifacts (see `docs/agent-models.md` and `docs/hot-reload.md`).
- `scripts/sdd-automode.sh` toggles SDD auto-mode: per-agent `permission` blocks in user OpenCode config, never repo artifacts (see `docs/sdd-automode.md`).
- `installers/opencode.sh` installs selected domain components into OpenCode; `installers/lib/common.sh` is the discovery/manifest library.
- `CLAUDE.md` is a symlink to this file; keep shared agent guidance here.
- There is no root package manifest, lockfile, CI workflow, or single root test command. Component-specific validation commands are documented below.
- `.ai/` is ignored local tool state. `.ai/atl/skill-registry.md` is the generated index produced by the meta `skill-registry` plugin; `.atl/` is legacy ignored state during migration. Top-level `skills/<skill>/SKILL.md` remains the source of truth for skills.
- Runtime state directories such as `.engram/`, `.claude/`, `.cursor/`, or tool-local memory chunks must not become managed repo artifacts unless explicitly adopted as an OpenCode component.

## Domains

Each `domains/<domain>/README.md` is the authoritative description; one-liners:

- `sdd`: spec-driven development around the `orchestraitor` primary agent; adopts ready-for-sdd planner bundles (see `docs/plan-handoff.md`).
- `sdd-lite`: POC of a single-context flow for bounded changes around the `orchestralite` primary agent; only the cold verify is delegated.
- `refactor`: risk-gated refactor and test-hardening (CDD) planning producing ready-for-sdd bundles, plus Java refactor skills.
- `architecture`: architecture mapping, state reviews, reverse-engineered PRDs, audits, and ADR + ideation bundles.
- `plan`: Fable-style planning front-door (`/deep-plan` → ready-for-sdd bundles for executable goals, plan docs for decisions) and `/wayfinder` multi-session discovery maps under `.ai/`.
- `learning`: interactive multi-session learning around the `mentor` primary agent (`/learn`) plus `/english` coaching (see `docs/learning-domain.md`).
- `docs`: product docs, Jira ticketing, summaries, and transcription skills.
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

- Default target `~/.config/opencode`, `--project` targets `./.opencode`; repository artifacts are symlinked. External plugins require OpenCode >= 1.17.15, `curl`, `jq`, and `shasum` or `sha256sum`; an external TUI plugin additionally requires `python3` so its exact entry can be added to `tui.json` without losing JSONC comments. Preflight and downloads finish before the transaction mutates the target. Global rules link to `$TARGET/AGENTS.md`.
- All plugins install under `$TARGET/plugins/`. Repository-owned server plugins are symlinked at the top level. External server bundles are verified regular `<name>.js` files at the top level. External TUI bundles live at `<name>/tui.js` and load only through the exact managed `tui.json` entry, so OpenCode's top-level server-plugin glob does not load them twice.
- Default filter is `--domain all --status all`.
- Valid skill statuses are `backlog`, `in-progress`, `testing`, and `done`; agents, commands, plugins, and external plugins are not status-filtered.
- The installer discovers agent/command regular files, domain skill symlinks, repository plugins, and external-plugin descriptors. Installed skill links point to the top-level `skills/` directory.
- `install` always installs the global rules regardless of `--domain`/`--status` filters. A pre-existing foreign destination is skipped with a warning unless `--force`.
- The installer writes `.agents-orchestrator-manifest` in its manifest root with `link<TAB>dest`, `file<TAB>dest` (generated or downloaded files), and `dir<TAB>path` lines, plus `managed-array` rows that narrowly own an exact `tui.json` plugin entry. Pre-existing identical entries are never claimed. Legacy `managed-object` rows are still understood so upgrading removes the retired `jsonc-parser` package dependency safely.
- `install` is a sync: links, generated files, and managed values from the previous manifest that are no longer selected are removed (type-guarded and exact-value-guarded, so user-replaced content is never deleted), then directories the previous manifest created and the current one no longer claims are pruned deepest-first with `rmdir`, so one that still holds anything is kept. OpenCode installs are transactional: a failure mid-install rolls the target back to its prior state.
- `uninstall` removes manifest-owned symlinks, generated files, and still-matching managed values plus empty created directories.
- Downloaded bundles and copied profiles do not auto-update when a descriptor or repo profile changes; re-run install. `status` reports external bundles with their pinned version and distinguishes installed, stale, foreign, and missing state.
- `install --reload` additionally hot-reloads running OpenCode servers after the transaction commits (best-effort, never fails the install); plugin code still needs a restart. Mechanism in `docs/hot-reload.md`.
- The `skill-registry` plugin generates the skill index consumed at runtime (`.ai/atl/skill-registry.md`).

## Adding A Component

1. Pick the domain first: `sdd`, `sdd-lite`, `refactor`, `architecture`, `plan`, `learning`, `docs`, `meta`, or `common`.
2. Add one fused file under `domains/<domain>/agents/` or `domains/<domain>/commands/`, or add one skill directory under `skills/` plus a symlink from each using domain under `domains/<domain>/skills/`.
3. For skills, set `metadata.status` deliberately. The installer includes all statuses unless filtered.
4. For skills, bump `metadata.version` when changing an existing skill.
5. Add a plugin under `domains/<domain>/plugins/` only when it is repository-specific. A reusable server or TUI plugin belongs in a standalone repository; add a `.server.json` or `.tui.json` lock under `domains/<domain>/external-plugins/` instead of copying its implementation here.
6. For an external plugin update, change `version`, `commit`, `artifact`, and `sha256` together, then run the remote artifact check below. A TUI descriptor may also name a repository-local `profileSource` copied beside its bundle.
7. When adding, removing, or moving a component, update the domain README's `## Components` table; if its entry points changed, update that domain's row in the root README too.
8. Run `installers/opencode.sh install --dry-run` to confirm discovery and target behavior.

Adding a component must not require editing any installer.

## Validation

- For doc-only changes, inspect the edited Markdown/frontmatter directly.
- For installer changes, run `bash -n` on the touched scripts; `scripts/validate-harness.sh` syntax-checks `installers/opencode.sh` plus `installers/lib/common.sh` and runs `shellcheck -x` when available.
- For install behavior, use `installers/opencode.sh install --target <scratch>` and inspect the manifest, symlinks, and generated files.
- For structure checks, run `scripts/validate-harness.sh`: it enforces agent/command and skill frontmatter contracts, domain skill symlink integrity, global component-name uniqueness, external descriptor shape, profile JSON shape, script syntax (plus `shellcheck -x` when available), deterministic external-plugin installer contracts, and the remaining component-specific checks.
- For external-plugin installation changes, run `scripts/test-external-plugin-install.sh contracts`; it covers JSONC preservation, install/repair/status/uninstall, foreign-file protection, rollback, filtered sync, migration from the old internal plugins, and project-target containment without network access. Run `scripts/test-external-plugin-install.sh remote` to download every descriptor's real pinned artifact and verify its SHA-256.
- Plugin implementation checks belong to their standalone repositories: `opencode-agent-model-configurator`, `opencode-skill-registry`, and `opencode-graphify-init` each expose `npm run check` and CI. Changes here validate the descriptor and integration, not copied source.
- For recall calculator changes, run `scripts/test-recall-calc.sh`; it needs Node >= 22.18 (native TypeScript type stripping).
- For `scripts/sdd-automode.sh` changes, run `scripts/test-sdd-automode.sh`; it needs `jq` and runs every case against a scratch `--target`, never the user's real OpenCode config.
- For sdd flow behavior, run `OPENCODE_BIN=<path> scripts/test-sdd-flows.sh probe` first, then `smoke`, `lite` (the sdd-lite `LITE-*` scenarios, driving `orchestralite`), or a single scenario id. It drives `orchestraitor` headlessly against `scripts/fixtures/sdd-agent-routes/java-orders/` and asserts the scenarios in `docs/sdd-test-plan.md`. It calls a real model and spends credits, so it is opt-in and deliberately not wired into `validate-harness.sh`.
- For SDD worktree swarm changes, run `scripts/test-sdd-swarm.sh`; it needs Node >= 22.18, Git, Java 17, Maven, and `jq`, and exercises the scheduler/controller against scratch repositories without model calls. `scripts/probe-sdd-swarm-task.sh` and `scripts/benchmark-sdd-swarm.sh` call real models and require explicit spend approval, so they are opt-in and not wired into `validate-harness.sh`.
- Do not commit unless explicitly asked.
