# Use CodeGraph safely with OpenCode

CodeGraph is optional. Install only its CLI, merge one MCP entry manually, and enable background indexing only in sessions where you want it. The repository installer never edits your OpenCode MCP configuration.

Compatibility target: OpenCode `1.17.15` and CodeGraph `1.4.1`.

## Quick setup

1. Install the pinned CLI:

   ```bash
   npm install -g @colbymchenry/codegraph@1.4.1
   ```

2. Merge `mcp.codegraph` into your existing user or project `opencode.jsonc`. This minimal entry is the recommended configuration for this repository's domains (see MCP options below):

   ```jsonc
   {
     "$schema": "https://opencode.ai/config.json",
     "mcp": {
       "codegraph": {
         "type": "local",
         "command": ["codegraph", "serve", "--mcp"],
         "enabled": true
       }
     }
   }
   ```

3. Open a repository with background initialization explicitly enabled:

   ```bash
   OPENCODE_CODEGRAPH_AUTOINIT=1 opencode
   ```

Do not run the CodeGraph OpenCode wizard. It writes agent instructions and can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink.

## MCP options

**Recommended: the minimal entry from step 2.** `codegraph_explore` is the default MCP tool and covers most structural questions; it is the only MCP tool this repository's agents reference (plan, refactor, and sdd domains) — agents with shell access reach the finer verbs (`callers`, `impact`, `node`, …) through the read-only CLI instead. Every extra exposed tool adds its schema to each session's context, so expose extra tools only when a workflow explicitly needs them via MCP:

```jsonc
{
  "mcp": {
    "codegraph": {
      "type": "local",
      "command": ["codegraph", "serve", "--mcp"],
      "enabled": true,
      "environment": {
        "CODEGRAPH_MCP_TOOLS": "explore,node,search,callers,impact"
      }
    }
  }
}
```

Useful environment controls:

| Variable | Use |
|---|---|
| `OPENCODE_CODEGRAPH_AUTOINIT=1` | Enables the common-domain initializer for this OpenCode process. Any other value is opt-out. |
| `CODEGRAPH_DIR=.codegraph-name` | Selects a different single-segment index directory. The plugin trusts the `indexPath` returned by CodeGraph. |
| `CODEGRAPH_PARSE_WORKERS=1` | Limits parsing to one worker on memory- or CPU-constrained machines. |
| `CODEGRAPH_TELEMETRY=0` or `DO_NOT_TRACK=1` | Disables CodeGraph's anonymous usage telemetry. `codegraph telemetry off` is the persistent CLI equivalent. |

## Background initializer

Installing the `common` domain installs `domains/common/plugins/codegraph-init.ts`. On OpenCode startup the plugin returns immediately, then works in the background:

1. Run `codegraph status <root> --json`.
2. Stay silent when the index is healthy.
3. When the project is not initialized, show one start toast and spawn `codegraph init <root>` without a shell.
4. Let CodeGraph's native index lock arbitrate concurrent sessions.
5. Re-check status, add the returned index path to `.git/info/exclude`, and show one result toast.

There is no dialog, blocking spinner, or repeated progress notification. Toast delivery is best-effort through OpenCode's `/tui/show-toast`; indexing continues if no TUI is connected.

| Condition | Notification | Automatic action |
|---|---|---|
| Opt-out or healthy `complete` index | None | None |
| Index missing | `info`, 5 seconds | Start background `init` |
| Init succeeds and status is `complete` | `success`, 5 seconds | Git-exclude the active index path |
| CLI missing | `warning`, 8 seconds | None |
| Existing `partial`, `failed`, unknown, or abandoned `indexing` state | `warning`, 8 seconds | None |
| Status or init process fails | `error`, 8 seconds | None; the OpenCode session stays operational |

## Freshness and recovery

After initialization, `codegraph serve --mcp` watches source files and debounces automatic sync. Tool responses identify files that may still be inside that short freshness window. Manual `sync` is normally unnecessary.

The plugin deliberately does not repair an incomplete index. Inspect first, then choose the recovery action yourself:

```bash
codegraph status /path/to/repo --json
codegraph index /path/to/repo --force
```

Other common recovery checks:

- Missing CLI: `npm install -g @colbymchenry/codegraph@1.4.1`.
- Constrained machine: rerun with `CODEGRAPH_PARSE_WORKERS=1`.
- Shared Windows/WSL checkout: give each environment a different `CODEGRAPH_DIR`; never share one active index across operating systems.
- Lock diagnosed as stale: inspect `codegraph status` before using `codegraph unlock`. The plugin never unlocks automatically.

## Agent behavior

The installed global rules make structural exploration CodeGraph-first when a healthy index exists. Agents use `codegraph_explore`, then read-only CLI queries when permitted, and finally normal LSP/filesystem tools as fallback.

Domain-specific restrictions still win. SDD agents retain their stricter lifecycle and read-only rules, while `deep-planner`, `refactor-planner`, and `refactor-analyzer` use the MCP graph only and fall back, because their shell access does not allow the CodeGraph CLI. The refactor planner probes the index once and passes `codegraph: available | absent` in its analyzer briefs so fan-out instances do not re-probe.

## Measure the benefit (A/B)

Use two clean checkouts at the same commit; never rename or move an active index.

1. Create checkout A and checkout B from the same commit.
2. Run `CODEGRAPH_PARSE_WORKERS=1 codegraph init <checkout-A>` only in A. Leave B unindexed.
3. Fix the OpenCode version, model/profile, prompt, agent, and tool permissions for both arms.
4. Run the same exploration task four times per arm, each in a fresh session.
5. Record input tokens, total tool calls, filesystem reads, elapsed time, and success/quality notes from OpenCode session statistics.
6. Compare medians. Treat a reduction above 30% in exploration input tokens as material, but reject the result if answer quality regresses.

| Run | Arm | Input tokens | Tool calls | File reads | Elapsed | Quality notes |
|---:|---|---:|---:|---:|---:|---|
| 1-4 | A: indexed | | | | | |
| 1-4 | B: unindexed | | | | | |

Keep both checkouts clean and preserve their state until all eight runs finish. This measures the agent workflow; CodeGraph's anonymous product telemetry is unrelated and may remain disabled.
