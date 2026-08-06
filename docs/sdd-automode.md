# Toggle SDD Auto Mode

Auto mode removes OpenCode tool-permission prompts for SDD agents. Workflow decisions still return to the SDLC primary; repository prompts and frontmatter are never edited.

## Quick path

```bash
scripts/sdd-automode.sh on
scripts/sdd-automode.sh show
scripts/sdd-automode.sh off
```

Options: `--dry-run`, `--project`, `--target DIR`, and `--no-general`. Restart OpenCode sessions after `on` or `off`.

## Generated policy

The script discovers current files under `domains/sdd/agents/` and writes a complete `agent.<name>.permission` block in user or project OpenCode config.

| Level | Preserved boundary |
|---|---|
| Coordinator | `orchestraitor` keeps `question: deny` and its narrow Task and skill maps |
| Read-only workers | `sdd-explore`, `sdd-verify`, and judges keep file-write denies |
| Implementation workers | `sdd-implement` and `jd-fix` keep their frontmatter ownership boundaries |
| Built-in helper | `general` is included unless `--no-general` is used |

All other known permission keys become `allow`. New SDD agents are discovered automatically; if OpenCode adds a permission key, update `PERMISSION_KEYS` in the script.

`off` removes only the generated permission blocks and prunes empty objects. It does not alter models, variants, unrelated agents, top-level config, or repository files.

## Safety trade-offs

- `external_directory: allow` permits access outside the project.
- `doom_loop: allow` disables the repeated-action circuit breaker.
- `general` is global, so its all-allow block affects other workflows too.
- An existing custom permission block is overwritten with a warning; recover it from the timestamped backup.
- Workflow questions are unchanged: SDD agents keep `question: deny`, return compact `ASK`, and `sdlc-orchestrator` asks the user.

Use `--dry-run` to inspect the exact resulting config before enabling auto mode. Tests run against scratch targets:

```bash
scripts/test-sdd-automode.sh
```
