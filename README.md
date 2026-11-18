# Agents Orchestrator

Agents Orchestrator gives reusable OpenCode agents, commands, skills, and plugins. It has three agents:

| Agent | Mode | Role |
|---|---|---|
| `orchestraitor` | primary | Routes, plans, coordinates, and owns Git in the main working tree |
| `worker` | subagent | Implements one self-contained brief. It can edit files and run checks |
| `scout` | subagent | Read-only. It explores, verifies, and judges |

You talk only to `orchestraitor`. It loads `oc-*` skills and delegates one level deep. If `worker` or `scout` is not available, it uses the built-in `general` subagent. Skills and agent bodies use the [IDSD format](CONTRIBUTING.md#idsd-format).

## Quick path

Install all components globally:

```bash
installers/opencode.sh install
```

After the install, restart OpenCode. `--reload` does not reload plugin code.

## Daily flow

1. Ask for a plan, for example `plan: add retry to the export job`. `orchestraitor` saves it to `.ai/plans/<slug>.md` and stops.
2. Say `ejecuta el plan .ai/plans/<slug>.md`. `oc-build` does all tasks without stops and ticks each task in the plan.
3. Read the report: done, failed, assumptions, and deviations. To resume, give the same trigger again.

For several independent tasks at the same time, use `/factory`. See [Software factory](#software-factory).

### Optional: quiet Mini interface

Run this setup step after installation. It requires Python 3 and OpenCode 2 with `opencode mini`.

```bash
make mini
opencode mini
```

`make mini` sets `mini.thinking` and `mini.shell_output` to `hide`, and `mini.tools` to `show`, in the global `cli.json`.
It hides reasoning and raw shell output, and shows tool calls and the preceding assistant text, in Mini.
It does not collapse items in the full-screen TUI or change the interface of an active session.
Continue an existing session with `opencode mini --session <session-id>`.

The command keeps other settings, comments, permissions, symlinks, and file modes.
It saves the previous file as `cli.json.bak` before a change.
If a setting has another value, use `make mini FORCE=1` to replace it.

Run `make mini-remove` to remove the three settings that `make mini` set.
This restores the OpenCode defaults, not previous custom values.
The normal install and uninstall do not change these optional settings.

The default directory is `$XDG_CONFIG_HOME/opencode`, or `~/.config/opencode` when that variable is not set.
Use `OPENCODE_DIR=/path/to/opencode` for an alternate global directory or a scratch test, not project-local settings.
An `OPENCODE_CLI_CONFIG_CONTENT` value can override the file settings.

Only the visual display changes. Hidden activity still uses tools and model tokens.
Check permission prompts, questions, errors, and final responses in your Mini session before regular use.
See the [OpenCode Mini settings](https://opencode.ai/docs/cli/config#mini).

## Repository shape

| Path | Ownership |
|---|---|
| `agents/` | The three OpenCode agents: `orchestraitor`, `worker`, and `scout` |
| `commands/` | Fused OpenCode commands |
| `skills/<skill>/` | All skill bodies, one `SKILL.md` each. Never copy a body or add symlinks |
| `tui-plugins/` | Repository-specific TUI plugins |
| `external-plugins/` | Pinned standalone plugin descriptors |
| `standards/` | Code conventions, writing conventions (ASD-STE100), and glossary |
| `installers/` | Discovery, installation, sync, and uninstall |
| `docs/` | Unique operational guides |

An installation is a sync. All components install together; `--status` filters skills by lifecycle state.

```bash
installers/opencode.sh install --status done,testing
installers/opencode.sh install --project
installers/opencode.sh status
```

## Catalog

### Entry points

| Entry | Result |
|---|---|
| Ask `orchestraitor` for a change | Verified, uncommitted diff |
| Ask for a light or deep plan | Plan in `.ai/plans/<slug>.md`. The work stops after the plan |
| Ask to explore an idea | Wayfinder discovery in `.ai/discoveries/<slug>.md`. Say `convert this discovery into a plan` to get a plan |
| `ejecuta el plan <path>` | Runs the plan with `oc-build`. To resume, give the same trigger again: ticked tasks are skipped |
| `/factory` | Runs independent tasks at the same time, each in its own worktree. See [Software factory](#software-factory) |
| `/arch map\|review\|ideate\|boundary` | Architecture docs, risks, ADR, or service boundary map. Dependency focus gives an inventory only and never runs dependency audit commands |
| `/review [solo\|dual\|defend] [fix] [target]` | `solo` (default) uses one judge. `dual` uses two judges in parallel. Add `fix` to repair critical and warning findings. `defend` is a read-only design defense |
| `/doc` | Routes to the most specific documentation skill |
| `/grill [me\|docs\|plan] [topic]` | Focused interview to stress-test an idea |
| `/ask-me` | Recommends `oc-*` skills for a use case |
| `/wait-what [fragment]` | Explains the fragment or the last response in chat, with only supported context. Preserves facts, uncertainty, vocabulary, and the user's language |
| `/models-profiles` (TUI plugin) | Assigns agent models and variants |

Changes stay in the working tree by default. `orchestraitor` commits only when the request or the plan line `Delivery: commits` asks for it. The `oc-commits` skill owns the commit rules. For the routes, see [`agents/orchestraitor.md`](agents/orchestraitor.md).

### How the flow behaves

The rule is "assume, note, continue". When data is missing, the agent selects the most reasonable option and continues. It reports each assumption at the end. A plan is a living guide: `oc-build` can correct it and records each change in `## Deviations`.

The agent asks you only before an action that is irreversible or visible to other people:

- Push, open a PR, or merge into your branch.
- Delete user data or untracked work.
- Run a migration on real data.
- Rewrite history.

### Software factory

`oc-factory` runs each task in its own worktree on the branch `factory/<id>`. It returns at once and does not wait. The state is in `.ai/factory/`. A question from one task does not stop the other tasks.

| You say | Result |
|---|---|
| `/factory add the CSV export; fix the login timeout` | Adds one brief for each task, starts the tasks, and gives you the ids |
| `/factory status` | Shows each task: `queued`, `running`, `done`, `needs-input`, `failed`, `merged`, or `conflict` |
| `/factory answer <id> <text>` | Answers a `needs-input` task and starts it again |
| `/factory merge <id>` | Merges a `done` task into your branch. A conflict aborts the merge |
| `/factory drop <id>` | Stops the task and removes its worktree, branch, and state |

A merge occurs only when you ask, or when you say `automerge`.

### Skills by purpose

| Purpose | Skills |
|---|---|
| Execution | `oc-build`, `oc-commits`, `oc-factory` |
| Planning | `oc-plan`, `oc-grill` |
| Review | `oc-review` |
| Architecture | `oc-arch`, `oc-adr` |
| Code quality | `oc-conventions`, `oc-domain`, `oc-refactor` |
| Documentation | `oc-prd`, `oc-rfc`, `oc-issue`, `oc-jira`, `oc-usm`, `oc-slides`, `oc-summarize`, `oc-whisper`, `oc-doc-design` |
| Context transfer | `oc-handoff` |
| File-based courses | `oc-teach` |
| PR bodies | `oc-pr` |
| Output and meta | `oc-refine-output`, `oc-prompt`, `oc-skill-creator`, `oc-absorb` |

The npm plugin `opencode-skill-registry` writes `.ai/atl/skill-registry.md` at each OpenCode start.

## Validate

Run `make install` to install the harness. Add options with `ARGS`, for example `make install ARGS=--dry-run`. Run `make hooks` one time to install the pre-push hook. Run `make test` to do the lint and the unit tests.

Run `make mcp` to add the Context7 and Engram MCP servers to the global OpenCode config, and `make mcp-remove` to remove them. Use `make mcp-context7` or `make mcp-engram` for one server. The entries go to `mcp.servers` if that object exists (OpenCode 2.x), else to `mcp`. `make mcp-engram` runs [`engram setup opencode`](https://github.com/Gentleman-Programming/engram/blob/main/docs/AGENT-SETUP.md#opencode), so install `engram` first. To send a Context7 API key, set `CONTEXT7_API_KEY` before `make mcp-context7`; the config gets `{env:CONTEXT7_API_KEY}`, not the key. The targets do not replace an entry that you set; use `FORCE=1` to replace it. Run `make help` for all targets.

## Documentation

| Guide | Purpose |
|---|---|
| [Agent models](docs/agent-models.md) | Assign provider models and variants to `orchestraitor`, `worker`, and `scout` |
| [Orchestration permissions](docs/orchestration-permissions.md) | Write permission blocks for the three agents and `general` |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |
