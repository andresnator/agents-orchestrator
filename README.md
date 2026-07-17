# Agents Orchestrator

Reusable agent artifacts organized by domain. Authored in OpenCode format for OpenCode.

## Domains at a glance

| Domain | Purpose | Entry points |
|---|---|---|
| [sdd](domains/sdd/README.md) | Spec-driven development around the `orchestraitor` primary agent | `orchestraitor` (primary), `/judgment` |
| [refactor](domains/refactor/README.md) | Risk-gated refactor and test-hardening planning producing ready-for-sdd bundles, plus Java refactor skills | `refactor-planner` (primary), `/harden-plan`, `/refactor-plan` |
| [architecture](domains/architecture/README.md) | Architecture mapping, state reviews, PRDs, audits, ADRs, and ideation | `architect` (primary), `/arch-audit`, `/arch-ideate`, `/arch-map`, `/arch-prd`, `/arch-review`, `/boundary-inspector` |
| [plan](domains/plan/README.md) | Fable-style planning front-door: `/deep-plan` produces ready-for-sdd bundles for executable goals or plan documents for decisions, plus `/wayfinder` multi-session discovery maps under `.ai/` | `deep-planner` (primary), `/deep-plan`, `/wayfinder` |
| [learning](domains/learning/README.md) | Interactive multi-session learning via `/learn` | `/learn` |
| [docs](domains/docs/README.md) | Product docs, Jira ticketing, English tutoring, summaries, slide decks, and transcription | `/decide`, `/doc`, `/english`, `/prd` |
| [meta](domains/meta/README.md) | Prompt and skill maintenance utilities | `/absorb`, `/prompt-checker`, `model-configurator` (TUI plugin) |
| [common](domains/common/README.md) | Shared engineering, quality, question UX, and output-refinement skills | `/defend`, `/grill`, transversal skills |

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

Do not run the CodeGraph OpenCode wizard: it can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink. See [docs/codegraph.md](docs/codegraph.md) for the safe JSONC merge, default-on background indexing and repair, recovery, and A/B measurement procedure.

See `AGENTS.md` for the editing contract before changing components.
