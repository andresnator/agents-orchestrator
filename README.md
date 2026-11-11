# Agents Orchestrator

Agents Orchestrator gives reusable OpenCode commands, skills, and plugins, organized by domain. `orchestraitor` is the only agent. It loads each `oc-*` skill itself or gives it to the built-in `general` subagent (one delegation level). Skills, the agent body, and plans use the [IDSD format](CONTRIBUTING.md#idsd-format).

## Quick path

Install all components globally:

```bash
installers/opencode.sh install
```

A global install also installs missing Homebrew tools. Use `--no-install-brew-tools` to skip them. Project and explicit-target installs skip them unless you add `--install-brew-tools`.

If `engram` is on PATH, each global install then runs [`engram setup opencode`](https://github.com/Gentleman-Programming/engram/blob/v2.1.0/docs/AGENT-SETUP.md#opencode). It refreshes the Engram plugin, MCP registration, and statusline from the **installed binary**. It does not upgrade Engram or enable Cloud. If the setup fails, the installer shows a warning and does not roll back. `--dry-run` only prints the setup. `--project`, `--target`, `status`, and `uninstall` never run it. A harness uninstall does not remove Engram files.

After the install:

1. Restart OpenCode.
2. Run `opencode mcp list`.
3. Make sure that the memory tools are available in a new session.

`--reload` does not reload plugin code.

To install the single-primary profile into one project only:

```bash
scripts/multi-primary-profile.sh install --project-root /absolute/path/to/project
scripts/multi-primary-profile.sh status --project-root /absolute/path/to/project
```

Then select `orchestraitor` for all routes. See the [profile runbook](docs/multi-primary-profile.md).

## Domains

| Domain | Purpose | Entry points |
|---|---|---|
| [plan](domains/plan/README.md) | Evidence-first discovery and IDSD execution plans | `oc-plan-light`, `oc-plan-deep` skills |
| [architecture](domains/architecture/README.md) | Maps, reviews, target decisions, and service boundaries | `oc-arch` skill, `/arch` |
| [orchestration](domains/orchestration/README.md) | Direct execution and durable SDD coordination | `orchestraitor` agent (the only agent) |
| [review](domains/review/README.md) | Adversarial review and Socratic design defense | `oc-review` skill, `/review` |
| [docs](domains/docs/README.md) | Product documents, Jira artifacts, summaries, and transcription | `/doc` |
| [meta](domains/meta/README.md) | Prompt, skill, and model-configuration utilities | `/ask-me` |
| [common](domains/common/README.md) | Shared engineering and quality skills | `/caveman`, `/grill` |

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
| `standards/` | Code conventions, writing conventions (ASD-STE100), and glossary |
| `installers/` | Discovery, installation, sync, and uninstall |
| `docs/` | Unique operational guides |

A filtered installation is a sync. Include each domain and status that you want to keep.

```bash
installers/opencode.sh install --domain plan --status done,testing
installers/opencode.sh install --domain orchestration,review
installers/opencode.sh install --project
installers/opencode.sh install --project --install-brew-tools
installers/opencode.sh status --domain orchestration
```

## Documentation

| Guide | Purpose |
|---|---|
| [Single-primary profile](docs/multi-primary-profile.md) | Install, select, validate, and roll back the orchestraitor profile |
| [Agent models](docs/agent-models.md) | Assign provider models and variants to orchestraitor and `general` |
| [Orchestration permissions](docs/orchestration-permissions.md) | Toggle `orchestraitor` and `general` permissions |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |
