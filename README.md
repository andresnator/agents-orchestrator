# Agents Orchestrator

Reusable agent artifacts for any agent runtime, including OpenCode, Claude Code, and Codex.

- `agents/`: staged subagent definitions
- `commands/`: flat slash-command definitions
- `skills/`: domain-organized skill definitions

Skills are organized by domain under `skills/{engineering,java,knowledge,meta,product-docs,sdd}/`. Their lifecycle state lives in `metadata.status`.

See `AGENTS.md` for repo-specific guidance before editing.
