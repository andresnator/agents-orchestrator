# Agents Orchestrator

Reusable agent artifacts organized by domain. Authored in OpenCode format for OpenCode.

- `domains/`: source of truth for agents, commands, plugins, and domain skill usage.
- `skills/`: source of truth for reusable skill bodies.
- `domains/<domain>/agents/*.md`: fused OpenCode agent files with frontmatter and prompt body.
- `domains/<domain>/commands/*.md`: fused OpenCode command files with frontmatter and prompt body.
- `skills/<skill>/SKILL.md`: reusable skill contracts.
- `domains/<domain>/skills/<skill>`: symlink declaring that a domain uses a central skill.
- `domains/<domain>/tui-plugins/*.tsx`: OpenCode TUI plugins (entrypoint plus same-named companion directory), OpenCode-only.
- `installers/opencode.sh`: symlink installer for OpenCode (`~/.config/opencode`).
- `docs/`: workflow notes and migration records.

Install all components globally:

```bash
installers/opencode.sh install
```

The installer now defaults to all lifecycle states. Use filters when needed:

```bash
installers/opencode.sh install --domain refactor --status done,testing
installers/opencode.sh install --project
installers/opencode.sh status --domain sdd
```

## CodeGraph (optional)

CodeGraph gives agents a local structural index for symbol, caller, and impact exploration. Install only the pinned CLI; then merge the MCP entry into your OpenCode config manually:

```bash
npm install -g @colbymchenry/codegraph@1.4.1
```

Do not run the CodeGraph OpenCode wizard: it can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink. See [docs/codegraph.md](docs/codegraph.md) for the safe JSONC merge, opt-in background indexing, recovery, and A/B measurement procedure.

See `AGENTS.md` for the editing contract before changing components.
