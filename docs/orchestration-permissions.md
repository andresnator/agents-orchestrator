# Orchestration Permissions

The helper writes OpenCode permission blocks for `orchestraitor` and, optionally, `general`.

## Quick path

```bash
scripts/orchestration-permissions.sh on --dry-run
scripts/orchestration-permissions.sh on
scripts/orchestration-permissions.sh show
scripts/orchestration-permissions.sh off
```

Use `--project` for `./.opencode`. Use `--target <dir>` for an explicit target. When you enable permissions, use `--no-general` to keep the built-in `general` agent unchanged.

## Boundaries

Frontmatter denies override automatic allows. `off` also removes blocks from the retired `sdd-*` and `jd-*` agents. Workflow confirmations do not change. The script uses `jq`, so it rejects JSONC comments. It makes a timestamped backup before it changes a config.
