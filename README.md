# Agents Orchestrator

Reusable OpenCode commands, skills, and plugins organized by domain around a single agent. `orchestraitor` is the only agent; every other capability is an `oc-*` skill that it loads itself or hands to OpenCode's built-in `general` subagent (one delegation level). Skills, the orchestraitor body, and plans follow the Intent-Driven Software Development (IDSD) format described in [CONTRIBUTING.md](CONTRIBUTING.md#idsd-format).

## Quick path

Install every component globally:

```bash
installers/opencode.sh install
```

Global installs also attempt to install missing Homebrew tools required by the selected components. Use `--no-install-brew-tools` to skip them. Project and explicit-target installs skip Homebrew by default and accept `--install-brew-tools` as an opt-in.

Every global install then runs [`engram setup opencode`](https://github.com/Gentleman-Programming/engram/blob/v2.1.0/docs/AGENT-SETUP.md#opencode) if `engram` is on PATH, including with `--no-install-brew-tools`. This refreshes Engram's plugin, MCP registration, and statusline integration from the **installed binary**, without upgrading Engram or enabling Cloud. Missing Engram or setup failure produces a warning without rolling back the harness; check setup output for additional warnings. Restart OpenCode afterward, check `opencode mcp list`, and verify memory tools in a new session. `--reload` does not reload plugin code.

`--dry-run` only prints the planned setup. `--project`, any explicit `--target`, `status`, and `uninstall` never run it. Engram's files and settings remain owned by Engram, outside the harness manifest, and survive harness uninstall.

Or install the single-primary profile into one project only:

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/path/to/project
scripts/multi-primary-profile.sh status --project-root /absolute/path/to/project
```

The project profile selects `plan,orchestration,architecture,review,common`, preserves the user's default agent, and allows one delegation level. See the [profile runbook](docs/multi-primary-profile.md). Select `orchestraitor` for every route: it plans with `oc-plan-light` or `oc-plan-deep`, executes and resumes, reviews with `oc-review`, and decides architecture with `oc-arch`.

## Domains

| Domain | Purpose | Entry points |
|---|---|---|
| [plan](domains/plan/README.md) | Evidence-first discovery and IDSD execution plans | `oc-plan-light`, `oc-plan-deep` skills |
| [architecture](domains/architecture/README.md) | Maps, reviews, target decisions, and service boundaries | `oc-arch` skill, `/arch-*`, `/boundary-inspector` |
| [orchestration](domains/orchestration/README.md) | Direct execution and durable SDD coordination | `orchestraitor` agent (the only agent) |
| [review](domains/review/README.md) | Adversarial review and Socratic design defense | `oc-review` skill, `/judgment`, `/defend` |
| [docs](domains/docs/README.md) | Product documents, Jira artifacts, summaries, and transcription | `/adr`, `/doc`, `/prd` |
| [meta](domains/meta/README.md) | Prompt, skill, and model-configuration utilities | `/absorb` |
| [common](domains/common/README.md) | Shared engineering and quality skills | `/caveman`, `/graphify-index`, `/grill` |

## Repository shape

| Path | Ownership |
|---|---|
| `domains/orchestration/agents/` | The single OpenCode agent, `orchestraitor` |
| `domains/<domain>/commands/` | Fused OpenCode commands |
| `domains/<domain>/skills/<skill>/` | Skills used by one domain |
| `skills/<skill>/` | Skill bodies shared by multiple domains |
| `domains/<domain>/skills/<shared-skill>` | Relative symlinks declaring shared usage |
| `domains/<domain>/plugins/` | Repository-specific plugins |
| `domains/<domain>/external-plugins/` | Pinned standalone plugin descriptors |
| `installers/` | Discovery, installation, sync, and uninstall |
| `docs/` | Unique operational guides |
| `manual-tests/fixtures/` | Reusable inputs for human regression cases |

Filtered installation is a sync: include every domain and lifecycle status you want to keep.

```bash
installers/opencode.sh install --domain plan --status done,testing
installers/opencode.sh install --domain orchestration,review
installers/opencode.sh install --project
installers/opencode.sh install --project --install-brew-tools
installers/opencode.sh status --domain orchestration
```

Install `orchestration` and `review` independently. Ask `orchestraitor` for a review (it loads `oc-review`) only when a separate evaluation is wanted.

## Documentation

| Guide | Purpose |
|---|---|
| [Single-primary profile](docs/multi-primary-profile.md) | Install, select, validate, and roll back the orchestraitor profile |
| [Manual regression catalog](docs/manual-testing.md) | Find affected cases by repository surface |
| [Agent models](docs/agent-models.md) | Assign provider models and variants to orchestraitor and `general` |
| [Orchestration permissions](docs/orchestration-permissions.md) | Toggle `orchestraitor` and `general` permissions |
| [Graphify](docs/graphify.md) | Index and query structural graphs |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |

## Validate changes

```bash
python3 scripts/lint-manual-tests.py
```

The linter validates only the manual catalog and never executes OpenCode or product scripts. In a pull request, its `manual-test-catalog` summary lists the human cases affected by the diff; follow the [manual testing guide](docs/manual-testing.md) and run model-backed cases only with separate cost authorization.
