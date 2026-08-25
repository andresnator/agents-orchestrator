# Toggle SDD Auto Mode

Auto mode removes OpenCode tool-permission prompts for SDD agents. Workflow decisions still return to `sdlc-orchestrator`; repository prompts and frontmatter never change.

## Quick path

```bash
scripts/sdd-automode.sh on --dry-run
scripts/sdd-automode.sh on
scripts/sdd-automode.sh show
scripts/sdd-automode.sh off
```

Options: `--project`, `--target DIR`, `--no-general`, and `--dry-run`. Restart affected OpenCode sessions after `on` or `off`.

## Generated policy

The script discovers agents under `domains/sdd/agents/` and writes complete `agent.<name>.permission` blocks in user or project config.

| Agent group | Preserved boundary |
|---|---|
| `orchestraitor` | Keeps `question: deny` and narrow Task and skill maps |
| Read-only workers | Keep file-write denies |
| Implementation workers | Keep frontmatter ownership boundaries |
| Built-in `general` | Included unless `--no-general` is set |

Other known permission keys become `allow`. New SDD agents are discovered automatically; new OpenCode permission keys require updating `PERMISSION_KEYS`.

`off` removes only generated blocks and prunes empty objects. It preserves models, variants, unrelated agents, top-level config, and repository files.

## Risks and recovery

- `external_directory: allow` permits access outside the project.
- `doom_loop: allow` disables the repeated-action circuit breaker.
- `general` is global and affects other workflows.
- Existing custom blocks are replaced after warning; recover them from the timestamped backup.
- SDD questions remain denied to workers and return as compact `ASK` lines to the primary.

Inspect `--dry-run` output before enabling. Verify behavior with:

```bash
scripts/test-sdd-automode.sh
```
