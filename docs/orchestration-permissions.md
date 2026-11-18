# Orchestration Permissions

The helper writes OpenCode permission blocks into your config for each agent in `agents/` (`orchestraitor`, `worker`, `scout`) and, optionally, the built-in `general`.

## When you need it

The agent frontmatter already grants `"*": allow`. An installed harness thus runs without tool prompts, and you do not need this helper for the three agents.

Use it in these cases:

- `general` does the work because `worker` or `scout` is not installed. `general` has no frontmatter in this repository.
- You want the permissions as explicit keys in your config.
- You want to remove blocks that an earlier release wrote (`off`).

## Quick path

```bash
scripts/orchestration-permissions.sh on --dry-run
scripts/orchestration-permissions.sh on
scripts/orchestration-permissions.sh show
scripts/orchestration-permissions.sh off
```

Use `--project` for `./.opencode`. Use `--target <dir>` for an explicit target. When you enable permissions, use `--no-general` to keep the built-in `general` agent unchanged.

## Boundaries

Each block sets all permission keys to `allow`, then applies the frontmatter entries. A frontmatter deny stays: `scout` keeps `edit: deny`. `off` also removes blocks from the retired `sdd-*` and `jd-*` agents. The script uses `jq`, so it rejects JSONC comments. It makes a timestamped backup before it changes a config.
