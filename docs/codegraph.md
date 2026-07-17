# Use CodeGraph safely with OpenCode

CodeGraph is optional. Install only its CLI and merge one MCP entry manually. Once the `common` domain is installed, background indexing and repair run by default in every session; opt out per session with `OPENCODE_CODEGRAPH_AUTOINIT=0`. The repository installer never edits your OpenCode MCP configuration.

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

3. Open a repository normally. Background initialization is on by default. To silence it for one session, opt out:

   ```bash
   OPENCODE_CODEGRAPH_AUTOINIT=0 opencode
   ```

Do not run the CodeGraph OpenCode wizard. It writes agent instructions and can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink.

## MCP options

**Recommended: the minimal entry from step 2.** `codegraph_explore` is the default MCP tool and covers most structural questions; it is the only MCP tool this repository's agents reference (plan, refactor, sdd, and architecture domains) — agents with shell access reach the finer verbs (`callers`, `impact`, `node`, …) through the read-only CLI instead. Every extra exposed tool adds its schema to each session's context, so expose extra tools only when a workflow explicitly needs them via MCP:

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
| `OPENCODE_CODEGRAPH_AUTOINIT=0` | Opts this OpenCode process out of the common-domain initializer. Unset or any other value keeps it on (default). |
| `CODEGRAPH_DIR=.codegraph-name` | Selects a different single-segment index directory. The plugin trusts the `indexPath` returned by CodeGraph. |
| `CODEGRAPH_PARSE_WORKERS=1` | Limits parsing to one worker on memory- or CPU-constrained machines. |
| `CODEGRAPH_TELEMETRY=0` or `DO_NOT_TRACK=1` | Disables CodeGraph's anonymous usage telemetry. `codegraph telemetry off` is the persistent CLI equivalent. |

## Background initializer

Installing the `common` domain installs `domains/common/plugins/codegraph-init.ts`. It runs by default (opt out with `OPENCODE_CODEGRAPH_AUTOINIT=0`). On OpenCode startup the plugin returns immediately, then works in the background:

1. Run `codegraph status <root> --json`.
2. Stay silent when the index is healthy.
3. When the project is not initialized, show one start toast and spawn `codegraph init <root>` without a shell.
4. When an index exists but is unhealthy (`partial`, `failed`, abandoned `indexing`, or unknown state), show one repair toast and spawn `codegraph index <root> --force`.
5. Let CodeGraph's native index lock arbitrate concurrent sessions. `--force` overrides only path safety, not the lock, so a live indexer keeps the repair from clobbering its work; the plugin never runs `unlock`.
6. Re-check status, add the returned index path to `.git/info/exclude`, and show one result toast.

There is no dialog, blocking spinner, or repeated progress notification. Toast delivery is best-effort through OpenCode's `/tui/show-toast`; indexing continues if no TUI is connected.

**Workspace roots.** When the session root is itself a Git repository (it has a `.git` entry), the plugin acts on that single root. When the root is a plain folder with no `.git` — an aggregator workspace holding cloned repos — the plugin discovers nested Git repositories up to two directory levels deep, skipping hidden directories, `node_modules`, and symlinked directories. It initializes or repairs each one sequentially to bound CPU, emitting one aggregate start toast and one aggregate summary toast instead of per-repository notifications. A plain folder with no nested repositories falls back to acting on the folder itself.

| Condition | Notification | Automatic action |
|---|---|---|
| Opt-out (`=0`) or healthy `complete` index | None | None |
| Index missing | `info`, 5 seconds | Start background `init` |
| Existing `partial`, `failed`, abandoned `indexing`, or unknown state | `info`, 5 seconds | Start background `index --force` repair |
| Init or repair succeeds and status is `complete` | `success`, 5 seconds | Git-exclude the active index path |
| Repair runs but the index is still not `complete` | `warning`, 8 seconds | None; recover manually |
| CLI missing | `warning`, 8 seconds | None |
| Status, init, or repair process fails | `error`, 8 seconds | None; the OpenCode session stays operational |
| Non-git workspace root with nested repos | One aggregate `info`/`success`/`warning` toast | Init or repair each nested repo sequentially |

## Freshness and recovery

After initialization, `codegraph serve --mcp` watches source files and debounces automatic sync. Tool responses identify files that may still be inside that short freshness window. Manual `sync` is normally unnecessary.

The plugin repairs an unhealthy index automatically with `codegraph index --force`. When the repair itself fails — or leaves the index still incomplete — it stops and reports the state; recover manually from there:

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

The architecture domain follows the same pattern: `architect` probes the index during its state scan — once per repository in multi-project workspaces — and passes `codegraph: available | absent` in every `arch-analyzer` brief. All three agents use the MCP graph only — `architect`'s ask-gated bash allowlist covers audit commands, not the CodeGraph CLI, and the two subagents deny bash — and fall back to read/grep/glob/lsp. In an aggregator workspace each nested repository carries its own index; agents never assume cross-repository graph queries — a repo whose probe fails is treated as unindexed.

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
