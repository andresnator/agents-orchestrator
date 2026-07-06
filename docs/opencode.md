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

## Skill Registry Plugin

`domains/meta/plugins/skill-registry.ts` generates `.atl/skill-registry.md` and `.atl/skill-registry.hash` on OpenCode startup without blocking the session. It scans project and user skill directories, resolves symlinks, deduplicates by skill name with project skills winning, and writes only when its staleness hash changes.

## Refactor Write Boundary

The refactor planning flow relies on agent `permission` frontmatter for write scoping. `refactor-planner` may write only under `.ia-refactor/plan/**`; there is no global refactor write-blocking plugin.

## Operational Notes

- The installer default is all domains and all statuses.
- Use `--domain` and `--status` to narrow installs.
- Domain skill symlinks decide which skills are selected for a domain.
- Plugins are discovered generically from `domains/<domain>/plugins/*.ts`; they are installed with the selected domain and are not filtered by skill status.
- Manifest sync removes stale symlinks from the previous install selection.
- CodeGraph MCP and compaction settings are runtime-local OpenCode configuration, not repo build outputs.
