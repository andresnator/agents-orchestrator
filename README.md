# Agents Orchestrator

Reusable agent artifacts organized by domain. Authored in OpenCode format for OpenCode.

## Domains at a glance

| Domain | Purpose | Entry points |
|---|---|---|
| [sdd](domains/sdd/README.md) | Spec-driven development around the `orchestraitor` primary agent | `orchestraitor` (primary), `/judgment` |
| [refactor](domains/refactor/README.md) | Risk-gated refactor and test-hardening planning producing ready-for-sdd bundles, plus Java refactor skills | `refactor-planner` (primary), `/harden-plan`, `/refactor-plan` |
| [architecture](domains/architecture/README.md) | Architecture mapping, state reviews, PRDs, audits, ADRs, and ideation | `architect` (primary), `/arch-audit`, `/arch-ideate`, `/arch-map`, `/arch-prd`, `/arch-review`, `/boundary-inspector` |
| [plan](domains/plan/README.md) | Fable-style planning front-door: `/deep-plan` produces ready-for-sdd bundles for executable goals or plan documents for decisions, plus `/wayfinder` multi-session discovery maps under `.ai/` | `deep-planner` (primary), `/deep-plan`, `/wayfinder` |
| [learning](domains/learning/README.md) | Interactive multi-session learning around the `mentor` primary agent, plus English coaching wired into it | `mentor` (primary), `/learn`, `/english` |
| [docs](domains/docs/README.md) | Product docs, Jira ticketing, summaries, slide decks, and transcription | `/decide`, `/doc`, `/prd` |
| [meta](domains/meta/README.md) | Prompt and skill maintenance utilities | `/absorb`, `/prompt-checker`, `model-configurator` (TUI plugin) |
| [common](domains/common/README.md) | Shared engineering, quality, question UX, and output-refinement skills | `/defend`, `/graphify-index`, `/grill`, transversal skills |

- `domains/`: source of truth for agents, commands, plugins, and domain skill usage.
- `skills/`: source of truth for reusable skill bodies.
- `domains/<domain>/agents/*.md`: fused OpenCode agent files with frontmatter and prompt body.
- `domains/<domain>/commands/*.md`: fused OpenCode command files with frontmatter and prompt body.
- `skills/<skill>/SKILL.md`: reusable skill contracts.
- `domains/<domain>/skills/<skill>`: symlink declaring that a domain uses a central skill.
- `domains/<domain>/tui-plugins/*.tsx`: OpenCode TUI plugins (entrypoint plus same-named companion directory), OpenCode-only.
- `installers/opencode.sh`: OpenCode component installer (`~/.config/opencode` by default). Most artifacts are symlinked; TUI plugins are generated copies with managed configuration.
- `docs/`: operational and workflow guides.

Install all components globally:

```bash
installers/opencode.sh install
```

The installer defaults to all lifecycle states. Use filters when needed:

```bash
installers/opencode.sh install --domain refactor --status done,testing
installers/opencode.sh install --project
installers/opencode.sh status --domain sdd
```

`install` is a sync. A filtered install replaces the previous selection, so include every domain and status you want to keep.

## Documentation

| Guide | Use it for |
|---|---|
| [Agent models](docs/agent-models.md) | Assigning models and variants per agent |
| [Delegation receipts](docs/delegation-receipts.md) | Writing compact machine-scannable subagent returns |
| [Graphify](docs/graphify.md) | Indexing, refreshing, querying, and recovering graphs |
| [Graphify test plan](docs/graphify-testing.md) | Validating Graphify integration changes |
| [Hot reload](docs/hot-reload.md) | Applying supported changes without restarting OpenCode |
| [Learning domain](docs/learning-domain.md) | Running multi-session learning workflows |
| [Manual plugin installation](docs/manual-plugin-install.md) | Installing plugins without the repository installer |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspecting and pruning the local session store |
| [Plan handoff](docs/plan-handoff.md) | Passing planner bundles into SDD execution |
| [SDD auto mode](docs/sdd-automode.md) | Toggling SDD tool-permission prompts |

## Graphify (optional)

Graphify gives agents a local structural graph for symbol, caller, and impact exploration, plus one machine-wide graph spanning every indexed repository. Start with the core CLI:

```bash
uv tool install graphifyy   # or: pipx install graphifyy
```

Do not run `graphify opencode install` (or `graphify claude install`): it writes its own agent instructions and plugin, and can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink. First indexing is human-gated: run `/graphify-index` once per repository (it asks docs vs code-only and records the mode); the `graphify-init` plugin then refreshes automatically. See [docs/graphify.md](docs/graphify.md) for the lifecycle, the cross-repository global graph, query usage, the optional MCP entry, and recovery.

See `AGENTS.md` for the editing contract before changing components.
