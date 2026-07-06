# 2026-07-06 Domain Restructure

The repository moved from a portable catalog plus harness overrides to OpenCode-native domain components.

## Domain Mapping

| Old area | New domain |
|---|---|
| SDD agents, commands, and skills | `domains/sdd/` |
| Refactor agents, commands, refactor skills, and Java skills | `domains/refactor/` |
| Product docs and knowledge commands/skills | `domains/docs/` |
| Prompt and skill maintenance utilities | `domains/meta/` |
| Shared engineering, quality, native question UX, and output refiner skills | `domains/common/` |

## Component Mapping

| Old shape | New shape |
|---|---|
| `catalog/agents/<name>.md` + `catalog/prompts/<domain>/<name>.md` + optional OpenCode override | `domains/<domain>/agents/<name>.md` |
| `catalog/commands/<name>.md` + `catalog/prompts/<domain>/<name>.md` + optional OpenCode override | `domains/<domain>/commands/<name>.md` |
| `catalog/skills/<old-domain>/<skill>/` | `skills/<skill>/` plus `domains/<new-domain>/skills/<skill>` symlink |
| `harnesses/opencode/plugins/write-guard.ts` | `domains/refactor/plugins/write-guard.ts` |
| `docs/harnesses/` | `docs/workflows/` |

## Counts

| Type | Count |
|---|---:|
| Agents | 43 |
| Commands | 13 |
| Skills | 76 |
| Plugins | 1 |

## Installer Change

`installers/opencode.sh` was rewritten as a direct symlink installer. It no longer builds generated OpenCode files. Its default filter changed from `done,testing` to all lifecycle states. Domain skill selection is represented by symlinks to top-level `skills/`.
