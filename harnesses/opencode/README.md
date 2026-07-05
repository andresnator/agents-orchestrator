# OpenCode Harness

This harness builds catalog stubs into OpenCode-readable Markdown and symlinks them into an OpenCode config directory.

OpenCode locations used by the installer:

- `agents/<name>.md`
- `commands/<name>.md`
- `skills/<name>/SKILL.md`

Agent and command file bodies are prompts. Catalog stubs therefore stay bodyless and point to `catalog/prompts/...`; the installer assembles the OpenCode files under `build/opencode/`.

## Whitelisted Frontmatter

Agent builds keep:

- `description`
- `mode`
- `model`
- `temperature`
- `permission`
- `tools`
- `disable`

Agent builds remove `name`, `prompt`, `license`, `metadata`, and `argument-hint`.

Command builds keep:

- `description`
- `agent`
- `model`
- `subtask`

Command builds remove every other field, including `name`, `prompt`, `license`, `metadata`, and `argument-hint`.

Skills are linked as directories without rewriting.

## Overrides

Optional overrides live at:

- `harnesses/opencode/overrides/agents/<name>.md`
- `harnesses/opencode/overrides/commands/<name>.md`

Override files are frontmatter-only. The installer performs a shallow merge by top-level key before whitelist filtering, with override values winning over catalog stub values.
