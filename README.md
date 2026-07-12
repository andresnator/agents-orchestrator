# Agents Orchestrator

Reusable agent artifacts organized by domain. Authored in OpenCode format; installable into OpenCode, Claude Code, and Codex CLI.

- `domains/`: source of truth for agents, commands, plugins, and domain skill usage.
- `skills/`: source of truth for reusable skill bodies.
- `domains/<domain>/agents/*.md`: fused OpenCode agent files with frontmatter and prompt body.
- `domains/<domain>/commands/*.md`: fused OpenCode command files with frontmatter and prompt body.
- `skills/<skill>/SKILL.md`: reusable skill contracts.
- `domains/<domain>/skills/<skill>`: symlink declaring that a domain uses a central skill.
- `domains/<domain>/tui-plugins/*.tsx`: OpenCode TUI plugins (entrypoint plus same-named companion directory), OpenCode-only.
- `installers/opencode.sh`: symlink installer for OpenCode (`~/.config/opencode`).
- `installers/claude.sh`: installer for Claude Code (`~/.claude`); skills symlinked, agents/commands generated.
- `installers/codex.sh`: installer for Codex CLI (`~/.codex` + `~/.agents/skills`); skills symlinked, agents as TOML, commands as custom prompts.
- `docs/`: workflow notes, `docs/runtime-matrix.md` (per-runtime mapping), and migration records.

Install all components globally into the runtime you use:

```bash
installers/opencode.sh install
installers/claude.sh install
installers/codex.sh install
```

The installer now defaults to all lifecycle states. Use filters when needed:

```bash
installers/opencode.sh install --domain refactor --status done,testing
installers/opencode.sh install --project
installers/opencode.sh status --domain sdd
```

See `AGENTS.md` for the editing contract before changing components.
