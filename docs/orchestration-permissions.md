# Orchestration Permissions

The helper writes complete OpenCode permission blocks for `orchestraitor`, its SDD workers, and optionally `general`.

## Quick path

```bash
scripts/orchestration-permissions.sh on --dry-run
scripts/orchestration-permissions.sh on
scripts/orchestration-permissions.sh show
scripts/orchestration-permissions.sh off
```

Use `--project` for `./.opencode` or `--target <dir>` for an explicit target. Use `--no-general` when enabling permissions to leave the built-in `general` agent unchanged.

## Boundaries

The script discovers agents under `domains/orchestration/agents/`. Frontmatter denies override automatic allows. Workflow confirmations remain unchanged.

The script rejects JSONC comments because it uses `jq`. It creates a timestamped backup before changing an existing config.

## Verify

```bash
scripts/test-orchestration-permissions.sh
```
