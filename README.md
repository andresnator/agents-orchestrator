# Agents Orchestrator

Agents Orchestrator gives reusable OpenCode commands, skills, and plugins. `orchestraitor` is the only agent. It loads each `oc-*` skill itself or gives it to the built-in `general` subagent (one delegation level). Skills, the agent body, and plans use the [IDSD format](CONTRIBUTING.md#idsd-format).

## Quick path

Install all components globally:

```bash
installers/opencode.sh install
```

A global install also installs missing Homebrew tools. Use `--no-install-brew-tools` to skip them. Project and explicit-target installs skip them unless you add `--install-brew-tools`.

For Engram memory, run `make engram-install` one time and `make engram-upgrade` to update it. Both run `engram setup opencode`.

After the install, restart OpenCode. `--reload` does not reload plugin code.

## Repository shape

| Path | Ownership |
|---|---|
| `agents/` | The single OpenCode agent, `orchestraitor` |
| `commands/` | Fused OpenCode commands |
| `skills/<skill>/` | All skill bodies, one `SKILL.md` each. Never copy a body or add symlinks |
| `plugins/` | Repository-specific server plugins, if any (`*.test.mjs` are not installed) |
| `tui-plugins/` | Repository-specific TUI plugins |
| `external-plugins/` | Pinned standalone plugin descriptors |
| `standards/` | Code conventions, writing conventions (ASD-STE100), and glossary |
| `installers/` | Discovery, installation, sync, and uninstall |
| `docs/` | Unique operational guides |

An installation is a sync. All components install together; `--status` filters skills by lifecycle state.

```bash
installers/opencode.sh install --status done,testing
installers/opencode.sh install --project
installers/opencode.sh install --project --install-brew-tools
installers/opencode.sh status
```

## Catalog

### Entry points

| Entry | Result |
|---|---|
| Ask `orchestraitor` for a change | Verified, uncommitted diff (Direct or SDD) |
| Ask for a light or deep plan | IDSD plan in `.ai/deep-planner/plans/<slug>.md` |
| Ask to explore an idea | Wayfinder discovery in `.ai/deep-planner/discoveries/<slug>.md`. Say `convert this discovery into a plan` to get a plan |
| `ejecuta el plan <path>` | Runs an exact plan. No new approval. Structural and checksum checks still run |
| `continúa <run>` | Resumes an SDD run without a new approval |
| `/arch map\|review\|ideate\|boundary` | Architecture docs, risks, ADR, or service boundary map. Dependency commands need authorization, else they give inventory only |
| `/review judgment\|light\|defend` | Adversarial code review or design defense. Judgment fixes only authorized, confirmed findings. Defend is read-only |
| `/doc` | Routes to the most specific documentation skill |
| `/grill` | Focused interview to stress-test an idea |
| `/ask-me` | Recommends `oc-*` skills for a use case |
| `/models-profiles` (TUI plugin) | Assigns agent models and variants |

A new SDD contract needs explicit approval. Silence is not approval. An exact existing plan skips approval. Delivery precedence: the current instruction, then the plan `Delivery:` value, then `working-tree`. Only `orchestraitor` stages, commits, or pushes. Workers never stage, commit, roll back, or push.

### Skills by purpose

| Purpose | Skills |
|---|---|
| Execution (SDD) | `oc-sdd`, `oc-routing`, `oc-commits` |
| Planning | `oc-plan`, `oc-grill` |
| Review | `oc-review`, `oc-judge` |
| Architecture | `oc-arch`, `oc-adr` |
| Code quality | `oc-conventions`, `oc-domain`, `oc-refactor` |
| Java | `oc-java` |
| Documentation | `oc-prd`, `oc-rfc`, `oc-issue`, `oc-jira`, `oc-usm`, `oc-slides`, `oc-summarize`, `oc-whisper`, `oc-doc-design` |
| Output and meta | `oc-refine-output`, `oc-prompt`, `oc-skill-creator`, `oc-absorb` |

The external plugin `opencode-skill-registry` writes `.ai/atl/skill-registry.md` at each OpenCode start.

## Validate

Run `make install` to install the harness. Add options with `ARGS`, for example `make install ARGS=--dry-run`. Run `make hooks` one time to install the pre-push hook. Run `make test` to do the lint and the unit tests.

## Documentation

| Guide | Purpose |
|---|---|
| [Agent models](docs/agent-models.md) | Assign provider models and variants to orchestraitor and `general` |
| [Orchestration permissions](docs/orchestration-permissions.md) | Toggle `orchestraitor` and `general` permissions |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |
