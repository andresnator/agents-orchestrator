# Agents Orchestrator

Reusable OpenCode agent artifacts organized by domain.

- `domains/`: source of truth for agents, commands, plugins, and domain skill usage.
- `skills/`: source of truth for reusable skill bodies.
- `domains/<domain>/agents/*.md`: fused OpenCode agent files with frontmatter and prompt body.
- `domains/<domain>/commands/*.md`: fused OpenCode command files with frontmatter and prompt body.
- `skills/<skill>/SKILL.md`: reusable skill contracts.
- `domains/<domain>/skills/<skill>`: symlink declaring that a domain uses a central skill.
- `installers/opencode.sh`: direct symlink installer for OpenCode.
- `docs/`: workflow notes, OpenCode notes, and migration records.

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

See `AGENTS.md` for the editing contract before changing components.
