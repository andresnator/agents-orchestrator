# Agents Orchestrator

Reusable agent artifacts for any agent runtime, including OpenCode, Claude Code, and Codex.

- `catalog/`: runtime-agnostic source of truth for skills, agent stubs, command stubs, and prompt bodies
- `harnesses/`: runtime-specific metadata rules and optional overrides
- `installers/`: incremental installers for supported runtimes
- `build/`: generated runtime artifacts, ignored by git

Skills are organized by domain under `catalog/skills/{engineering,java,knowledge,meta,product-docs,sdd}/`. Agents and commands split portable metadata stubs from clean prompt bodies under `catalog/prompts/`.

Install the default `done|testing` OpenCode components globally:

```bash
installers/opencode.sh install
```

Use `installers/opencode.sh install --project` for `./.opencode`, or `--all` to include backlog and in-progress components.
`--status` is a raw `metadata.status` lifecycle filter and does not resolve dependencies between commands, prompts, and skills.

See `AGENTS.md` for repo-specific guidance before editing.
