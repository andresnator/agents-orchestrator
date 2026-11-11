# Agents Orchestrator

Agents Orchestrator gives reusable OpenCode commands, skills, and plugins. `orchestraitor` is the only agent. It loads each `oc-*` skill itself or gives it to the built-in `general` subagent (one delegation level). Skills, the agent body, and plans use the [IDSD format](CONTRIBUTING.md#idsd-format).

## Quick path

Install all components globally:

```bash
installers/opencode.sh install
```

After the install, restart OpenCode. `--reload` does not reload plugin code.

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
| `agents/` | The single OpenCode agent, `orchestraitor` |
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
| Ask `orchestraitor` for a change | Verified, uncommitted diff (Direct or SDD) |
| Ask for a light or deep plan | IDSD plan in `.ai/deep-planner/plans/<slug>.md` |
| Ask to explore an idea | Wayfinder discovery in `.ai/deep-planner/discoveries/<slug>.md`. Say `convert this discovery into a plan` to get a plan |
| `ejecuta el plan <path>` | Runs an exact plan. No new approval. Structural and checksum checks still run |
| `continúa <run>` | Resumes an SDD run without a new approval |
| `/arch map\|review\|ideate\|boundary` | Architecture docs, risks, ADR, or service boundary map. Dependency focus gives an inventory only and never runs dependency audit commands |
| `/review judgment\|light\|defend` | Adversarial code review or design defense. Judgment fixes only authorized, confirmed findings. Defend is read-only |
| `/doc` | Routes to the most specific documentation skill |
| `/grill` | Focused interview to stress-test an idea |
| `/ask-me` | Recommends `oc-*` skills for a use case |
| `/wait-what [fragment]` | Explains the fragment or the last response in chat, with only supported context. Preserves facts, uncertainty, vocabulary, and the user's language |
| `/models-profiles` (TUI plugin) | Assigns agent models and variants |

For delivery and Git rules, see [`agents/orchestraitor.md`](agents/orchestraitor.md). The `oc-sdd` skill owns the SDD approval gate.

### Skills by purpose

| Purpose | Skills |
|---|---|
| Execution (SDD) | `oc-sdd`, `oc-routing`, `oc-commits` |
| Planning | `oc-plan`, `oc-grill` |
| Review | `oc-review`, `oc-judge` |
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
| [Agent models](docs/agent-models.md) | Assign provider models and variants to orchestraitor and `general` |
| [Orchestration permissions](docs/orchestration-permissions.md) | Toggle `orchestraitor` and `general` permissions |
| [Hot reload](docs/hot-reload.md) | Apply supported configuration changes live |
| [LM Studio](docs/lm-studio.md) | Connect OpenCode to LAN-hosted models |
| [OpenCode database growth](docs/opencode-db-growth.md) | Inspect and prune local session data |
