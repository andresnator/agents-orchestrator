# Agents Orchestrator

Reusable OpenCode agents, commands, skills, and plugins organized by domain. The opt-in SDLC profile provides one natural-language entrypoint while preserving specialized coordinators.

## Quick path

Install every component globally:

```bash
installers/opencode.sh install
```

Or install the SDLC POC into one project only:

```bash
scripts/sdlc-orchestrator-poc.sh install --project-root /absolute/path/to/project
scripts/sdlc-orchestrator-poc.sh status --project-root /absolute/path/to/project
```

The project profile selects `sdlc,plan,sdd,architecture,sdd-lite,common`, sets `sdlc-orchestrator` as the default, and allows two delegation levels. See the [POC runbook](docs/sdlc-orchestrator-poc.md).

## Domains

| Domain | Purpose | Entry points |
|---|---|---|
| [sdlc](domains/sdlc/README.md) | Natural-language routing and user-question ownership | `sdlc-orchestrator` |
| [plan](domains/plan/README.md) | Delivery, refactor, hardening, decision, and Wayfinder plans | `/deep-plan`, `/refactor-plan`, `/harden-plan`, `/wayfinder` |
| [architecture](domains/architecture/README.md) | Maps, reviews, PRDs, audits, boundaries, and ideation | `/arch-*`, `/boundary-inspector` |
| [sdd](domains/sdd/README.md) | Full spec-driven implementation and durable canonical specs | `orchestraitor`, `/judgment` |
| [sdd-lite](domains/sdd-lite/README.md) | Bounded implementation in one coordinator context | `orchestralite` |
| [learning](domains/learning/README.md) | Multi-session learning and English coaching | `/learn`, `/english` |
| [docs](domains/docs/README.md) | Product documents, Jira artifacts, summaries, and transcription | `/decide`, `/doc`, `/prd` |
| [meta](domains/meta/README.md) | Prompt, skill, and model-configuration utilities | `/absorb`, `/prompt-checker` |
| [common](domains/common/README.md) | Shared engineering and quality skills | `/defend`, `/graphify-index`, `/grill` |

## Repository shape

| Path | Ownership |
|---|---|
| `domains/<domain>/agents/` | Fused OpenCode agent definitions |
| `domains/<domain>/commands/` | Fused OpenCode commands |
| `domains/<domain>/skills/<skill>/` | Skills used by one domain |
| `skills/<skill>/` | Skill bodies shared by multiple domains |
| `domains/<domain>/skills/<shared-skill>` | Relative symlinks declaring shared usage |
| `domains/<domain>/plugins/` | Repository-specific plugins |
| `domains/<domain>/external-plugins/` | Pinned standalone plugin descriptors |
| `profiles/` | Provider-independent agent tiers |
| `installers/` | Discovery, installation, sync, and uninstall |
| `docs/` | Unique operational guides |

Filtered installation is a sync: include every domain and lifecycle status you want to keep.

```bash
installers/opencode.sh install --domain plan --status done,testing
installers/opencode.sh install --project
installers/opencode.sh status --domain sdd
```

## Documentation

| Guide | Purpose |
|---|---|
| [SDLC POC](docs/sdlc-orchestrator-poc.md) | Install, route, validate, and roll back the project profile |
| [SDD test plan](docs/sdd-test-plan.md) | Choose deterministic or model-backed flow checks |
| [Agent models](docs/agent-models.md) | Assign provider models and variants by tier |
| [SDD auto mode](docs/sdd-automode.md) | Toggle coordinator and worker permissions |
| [Learning](docs/learning-domain.md) | Run durable learning topics |
| [Graphify](docs/graphify.md) | Index and query structural graphs |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |

## Validate changes

```bash
installers/opencode.sh install --dry-run
scripts/validate-harness.sh
```

Use component-specific checks documented in [AGENTS.md](AGENTS.md). Model-backed tests are opt-in because they spend credits.
