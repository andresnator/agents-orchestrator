# Agents Orchestrator

Reusable OpenCode agents, commands, skills, and plugins organized by domain. Core workflows use direct primary agents with one delegation level for specialized workers.

## Quick path

Install every component globally:

```bash
installers/opencode.sh install
```

Global installs also attempt to install missing Homebrew tools required by the selected components. Use `--no-install-brew-tools` to skip them. Project and explicit-target installs skip Homebrew by default and accept `--install-brew-tools` as an opt-in.

Or install the multi-primary profile into one project only:

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/path/to/project
scripts/multi-primary-profile.sh status --project-root /absolute/path/to/project
```

The project profile selects `plan,orchestration,architecture,review,common`, preserves the user's default agent, and allows one delegation level. See the [multi-primary runbook](docs/multi-primary-profile.md). Select a primary directly: Wayfinder discovers, Deep Plan plans, and Orchestraitor executes.

## Domains

| Domain | Purpose | Entry points |
|---|---|---|
| [plan](domains/plan/README.md) | Evidence-first discovery and neutral execution plans | `deep-planner` |
| [architecture](domains/architecture/README.md) | Maps, reviews, target decisions, and service boundaries | `/arch-*`, `/boundary-inspector` |
| [orchestration](domains/orchestration/README.md) | Direct execution and durable SDD coordination | `orchestraitor` |
| [review](domains/review/README.md) | Adversarial review and Socratic design defense | `review-coordinator`, `/judgment`, `/defend` |
| [learning](domains/learning/README.md) | One-off teaching, durable learning paths, and English coaching | `/learn`, `/english` |
| [docs](domains/docs/README.md) | Product documents, Jira artifacts, summaries, and transcription | `/adr`, `/doc`, `/prd` |
| [meta](domains/meta/README.md) | Prompt, skill, and model-configuration utilities | `/absorb` |
| [common](domains/common/README.md) | Shared engineering and quality skills | `/caveman`, `/graphify-index`, `/grill` |

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
| `installers/` | Discovery, installation, sync, and uninstall |
| `docs/` | Unique operational guides |

Filtered installation is a sync: include every domain and lifecycle status you want to keep.

```bash
installers/opencode.sh install --domain plan --status done,testing
installers/opencode.sh install --domain orchestration,review
installers/opencode.sh install --project
installers/opencode.sh install --project --install-brew-tools
installers/opencode.sh status --domain orchestration
```

Install `orchestration` and `review` independently. Select `review-coordinator` only when a separate evaluation is wanted.

## Documentation

| Guide | Purpose |
|---|---|
| [Multi-primary profile](docs/multi-primary-profile.md) | Install, select, validate, and roll back direct primaries |
| [Orchestration test plan](docs/orchestration-test-plan.md) | Choose deterministic or model-backed flow checks |
| [Plan flow scenarios](docs/plan-flow-test-scenarios.md) | Copy-ready hypothetical prompts and expected Plan evidence |
| [Agent models](docs/agent-models.md) | Assign provider models and variants by tier |
| [Orchestration permissions](docs/orchestration-permissions.md) | Toggle coordinator and worker permissions |
| [Learning](docs/learning-domain.md) | Run one-off sessions or durable learning paths |
| [Graphify](docs/graphify.md) | Index and query structural graphs |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |

## Validate changes

```bash
installers/opencode.sh install --dry-run
scripts/validate-harness.sh
```

Use component-specific checks documented in [CONTRIBUTING.md](CONTRIBUTING.md). Model-backed tests are opt-in because they spend credits.
