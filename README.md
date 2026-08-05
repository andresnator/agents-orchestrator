# Agents Orchestrator

Reusable agent artifacts organized by domain. Authored in OpenCode format for OpenCode.

## Domains at a glance

| Domain | Purpose | Entry points |
|---|---|---|
| [sdlc](domains/sdlc/README.md) | Single natural-language SDLC primary routing to domain coordinators and owning every user question | `sdlc-orchestrator` (primary) |
| [sdd](domains/sdd/README.md) | Spec-driven development through the `orchestraitor` coordinator, including ready-bundle execution without redrafting | `orchestraitor` (subagent), `/judgment` alias |
| [sdd-lite](domains/sdd-lite/README.md) | POC: single-context flow for bounded changes — `change.md` in chat, inline implementation, delegated cold verify only | `orchestralite` (primary) |
| [refactor](domains/refactor/README.md) | Risk-gated refactor and test-hardening planning producing ready-for-sdd bundles, plus Java refactor skills | `refactor-planner` (primary), `/harden-plan`, `/refactor-plan` |
| [architecture](domains/architecture/README.md) | Architecture mapping, state reviews, PRDs, audits, ADRs, and ideation | `architect` (primary), `/arch-audit`, `/arch-ideate`, `/arch-map`, `/arch-prd`, `/arch-review`, `/boundary-inspector` |
| [plan](domains/plan/README.md) | Fable-style planning: Deep Plan produces ready-for-sdd bundles for executable goals or plan documents for decisions, plus Wayfinder maps under `.ai/` | `deep-planner` (subagent), `/deep-plan` and `/wayfinder` aliases |
| [learning](domains/learning/README.md) | Interactive multi-session learning around the `mentor` primary agent, plus English coaching wired into it | `mentor` (primary), `/learn`, `/english` |
| [docs](domains/docs/README.md) | Product docs, Jira ticketing, summaries, slide decks, and transcription | `/decide`, `/doc`, `/prd` |
| [meta](domains/meta/README.md) | Prompt and skill maintenance utilities | `/absorb`, `/prompt-checker`, `model-configurator` (TUI plugin) |
| [common](domains/common/README.md) | Shared engineering, quality, question UX, and output-refinement skills | `/defend`, `/graphify-index`, `/grill`, transversal skills |

- `domains/`: source of truth for agents, commands, local plugins, external-plugin locks, and domain skill usage.
- `skills/`: source of truth for reusable skill bodies.
- `domains/<domain>/agents/*.md`: fused OpenCode agent files with frontmatter and prompt body.
- `domains/<domain>/commands/*.md`: fused OpenCode command files with frontmatter and prompt body.
- `skills/<skill>/SKILL.md`: reusable skill contracts.
- `domains/<domain>/skills/<skill>`: symlink declaring that a domain uses a central skill.
- `domains/<domain>/external-plugins/*.server.json|*.tui.json`: version, commit, artifact, and SHA-256 locks for reusable plugins maintained in standalone repositories.
- `installers/opencode.sh`: OpenCode component installer (`~/.config/opencode` by default). Repository artifacts are symlinked; external plugin bundles are downloaded from pinned commits, checksum-verified, and manifest-owned.
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
| [Hot reload](docs/hot-reload.md) | Applying supported changes without restarting OpenCode |
| [Learning domain](docs/learning-domain.md) | Running multi-session learning workflows |
| [LM Studio over LAN](docs/lm-studio.md) | Connecting OpenCode to one or more LM Studio models on another computer |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspecting and pruning the local session store |
| [Plan handoff](docs/plan-handoff.md) | Passing planner bundles into SDD execution |
| [SDLC orchestrator ADR](docs/architecture/adr/0001-adopt-sdlc-orchestrator.md) | Understanding the primary-to-coordinator topology and trade-offs |
| [SDD auto mode](docs/sdd-automode.md) | Toggling SDD tool-permission prompts |

## Graphify (optional)

Graphify gives agents a local structural graph for symbol, caller, and impact exploration, plus one machine-wide graph spanning every indexed repository. Start with the core CLI:

```bash
uv tool install "graphifyy[mcp]==0.9.32"   # or use pipx
```

Do not run `graphify opencode install` (or `graphify claude install`): it writes its own agent instructions and plugin, and can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink. First indexing is human-gated: run `/graphify-index` once per repository (it asks docs vs code-only and records the mode); the `graphify-init` plugin then refreshes automatically. See [docs/graphify.md](docs/graphify.md) for the lifecycle, the cross-repository global graph, query usage, the optional MCP entry, and recovery.

See `AGENTS.md` for the editing contract before changing components.
