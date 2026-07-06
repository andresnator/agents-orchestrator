# OpenCode Notes

This repo now stores OpenCode-native components directly under `domains/`.

## Target Layout

`installers/opencode.sh install` symlinks selected components into:

```text
~/.config/opencode/
├── agents/
├── commands/
├── skills/
├── plugins/
└── .agents-orchestrator-manifest
```

Use `--project` to target `./.opencode` from the current working directory, or `--target DIR` for scratch installs.

## Component Files

Agents and commands are Markdown files with YAML frontmatter and the prompt body in the same file. Extra metadata such as `metadata.status`, `metadata.version`, and command `argument-hint` stays inline.

Skills are declared per domain as symlinks to top-level `skills/<skill>/` directories. The installer resolves those symlinks and links the central skill directories into OpenCode without rewriting. Plugins are linked as TypeScript files.

## Refactor Plugin

`domains/refactor/plugins/write-guard.ts` belongs to the refactor planning flow. It denies writes outside `.ia-refactor/plan/YYYYMMDD/<target>.md` before tool execution.

## Operational Notes

- The installer default is all domains and all statuses.
- Use `--domain` and `--status` to narrow installs.
- Domain skill symlinks decide which skills are selected for a domain.
- Manifest sync removes stale symlinks from the previous install selection.
- CodeGraph MCP and compaction settings are runtime-local OpenCode configuration, not repo build outputs.
