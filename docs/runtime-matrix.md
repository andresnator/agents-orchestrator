# Runtime Matrix

How each repo artifact maps into each runtime. OpenCode format is the authoring format; `installers/claude.sh` and `installers/codex.sh` transform at install time.

## Mapping

| Artifact | OpenCode (`opencode.sh`) | Claude Code (`claude.sh`) | Codex CLI (`codex.sh`) |
|---|---|---|---|
| Agents (18) | symlink `$T/agents/<n>.md` | generated `$T/agents/<n>.md` (frontmatter: `name` + `description`; `mode`/`temperature`/`permission` dropped) | generated `~/.codex/agents/<n>.toml` (`name`, `description`, `developer_instructions` = prompt body) |
| Commands (20) | symlink `$T/commands/<n>.md` | generated `$T/commands/<n>.md` (frontmatter reduced to `description` + `argument-hint`) | generated `~/.codex/prompts/<n>.md`, invoked `/prompts:<n>` (user-level only) |
| Skills | symlink `$T/skills/<n>` | symlink `$T/skills/<n>` | symlink `~/.agents/skills/<n>` (not `~/.codex/skills`) |
| Plugins | symlink `$T/plugins/<n>.ts` | skipped | skipped |
| Global rules | symlink `$T/AGENTS.md` | symlink `$T/rules/agents-orchestrator.md` | symlink `~/.codex/AGENTS.md` |
| `--project` | `./.opencode` (everything) | `./.claude` (everything) | `./.codex/agents` + `./.agents/skills` only; prompts and global rules skipped |

`$T` = the runtime target root. For Codex, `--target DIR` acts as a fake `$HOME` (`DIR/.codex` + `DIR/.agents/skills`).

## Transform rules

- Claude agent: `name` comes from the repo filename stem, preserving the name-from-filename contract. OpenCode `permission` maps are NOT translated to Claude `tools`/`disallowedTools`; a wrong mapping would silently break delegation, so Claude user settings govern permissions.
- Claude/Codex command: OpenCode `agent:`/`subtask:`/`model:` keys are stripped. In Claude Code `agent:` means "fork into this subagent" — a different semantic than OpenCode's "run under this primary agent". Delegation still works because the referenced agent is installed as a subagent and the command body asks for the delegation in prose.
- Codex agent TOML: every backslash and double quote in the body is escaped (valid in TOML multiline basic strings), so `"""` collisions are impossible. No `model` is emitted; agents stay provider-agnostic.

## Portability caveats (documented, not fixed)

- The four `mode: primary` agents (`orchestraitor`, `architect`, `refactor-planner`, `deep-planner`) become plain subagents in Claude Code and Codex; there is no "switch primary agent" concept there.
- Some agent bodies (sdd judgment/explore/design) instruct using the `codegraph_explore` MCP tool and `.codegraph/`; that only works where the user configured that MCP server.
- References to OpenCode's built-in `general` subagent degrade to prose in other runtimes; the runtime picks its own generic delegate.
- `.ai/` state paths are CWD-relative and work identically in all runtimes.
- The `skill-registry` plugin is OpenCode-only (`@opencode-ai/plugin`); Claude Code and Codex discover skills natively, so the registry is unnecessary there. `global/AGENTS.md` says to use the registry only when its file exists.
- Codex custom prompts are deprecated in favor of skills but still work; if OpenAI removes them, migrate the 20 commands to skills.
- Codex docs state symlinked skill folders are supported, but there have been discovery regressions with symlinks in past Codex versions; after a Codex upgrade, verify skills still list in a fresh session (`/skills`).
- Generated files (Claude agents/commands, Codex agents/prompts) do not auto-update when the repo changes; re-run the installer. Symlinked artifacts stay live.
