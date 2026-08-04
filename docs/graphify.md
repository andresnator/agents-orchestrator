# Graphify Integration

Graphify is optional. This repository owns the `/graphify-index` consent command, the OpenCode integration lock, and the agent rules that consume graphs. The reusable refresher implementation, tests, releases, and standalone installation instructions live in [`opencode-graphify-init`](https://github.com/andresnator/opencode-graphify-init).

The integration targets OpenCode >= 1.17.15 and [`graphifyy` 0.9.32](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.32). The repository installer fetches the refresher bundle from its exact locked commit and verifies its SHA-256 before changing the target.

## Quick setup

1. Install the `common` domain, which includes `/graphify-index`, the `graphify-cli` skill, and the external refresher:

   ```bash
   installers/opencode.sh install --domain common
   ```

2. Install Graphify. Include its MCP extra when agents need to query the graph:

   ```bash
   uv tool install "graphifyy[mcp]==0.9.32"
   # or: pipx install "graphifyy[mcp]==0.9.32"
   ```

3. Export the output path in the environment that launches OpenCode:

   ```bash
   export GRAPHIFY_OUT=.ai/graphify-out
   ```

4. Add the [MCP configuration](#mcp-configuration) when agents need graph queries.

5. Open a repository and run `/graphify-index` once. It asks whether to index and whether to use code-only or docs mode. Later OpenCode sessions refresh that repository automatically.

Do not run `graphify opencode install`, `graphify install --platform opencode`, or `graphify claude install`. Those commands write their own instructions and plugin and can conflict with the installer-managed `AGENTS.md` and refresher.

## Lifecycle contract

First indexing and background refresh are intentionally separate:

```mermaid
flowchart LR
  human[Human runs /graphify-index] --> consent{Index this repository?}
  consent -->|yes| mode[Choose code-only or docs]
  mode --> graph[Build graph and record mode]
  graph --> later[Later OpenCode session]
  later --> refresh[graphify-init refreshes only when stale]
```

- `/graphify-index` owns first indexing. It records standing consent and mode in `.ai/graphify-out/.opencode-index-mode`.
- `graphify-init` is a refresher only. Without the mode file it may show a hint, but it never starts the first extraction.
- With a recorded mode, a missing or stale graph is rebuilt in the background. A current graph is left untouched.
- `OPENCODE_GRAPHIFY_AUTOINIT=0` disables refresh for one OpenCode process.
- On a plain aggregator directory, the command and refresher discover nested Git repositories up to two levels deep. Each repository keeps independent state.
- The implementation serializes competing extracts, terminates owned child processes on normal shutdown, preserves the recorded mode, and reports failures without blocking the OpenCode session. The external plugin README is authoritative for these runtime details.

Mode changes are directional. Moving from code-only to docs adds semantic document nodes incrementally. Moving from docs to code-only requires removing the old graph first because Graphify otherwise preserves document nodes; `/graphify-index` handles the confirmation and rebuild workflow.

## State and controls

Per-repository state lives under `.ai/graphify-out/`, including `graph.json`, the incremental manifest and cache, the mode file, and generated reports. The integration adds `.ai/graphify-out` to `.git/info/exclude`; none of it is a managed repository artifact.

Use `GRAPHIFY_OUT=.ai/graphify-out`, not `--out`, for the standard layout. Combining both can create a duplicated `.ai/.ai/graphify-out/` path, while using only `--out` can make MCP `project_path` resolution miss the graph.

| Variable | Effect |
|---|---|
| `GRAPHIFY_OUT=.ai/graphify-out` | Makes the CLI, refresher, and MCP server resolve the same graph path |
| `OPENCODE_GRAPHIFY_AUTOINIT=0` | Disables background refresh for this OpenCode process |
| `OPENCODE_GRAPHIFY_GLOBAL=0` | Keeps graphs local and skips the cross-repository merge |
| `OPENCODE_GRAPHIFY_DOCS=1` | Defaults the docs question in `/graphify-index`; it does not override a recorded mode |
| `OPENCODE_GRAPHIFY_BACKEND=<name>` | Defaults the docs backend question and supports legacy docs graphs without a recorded backend |
| `GRAPHIFY_FORCE=1` | Forces Graphify to rescan instead of using its incremental manifest/cache; it does not imply `--allow-partial` |

## MCP configuration

The installer deliberately does not edit OpenCode's MCP configuration. Merge the entries you want into the user or project `opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "graphify": {
      "type": "local",
      "command": ["graphify-mcp", "--graph", ".ai/graphify-out/graph.json"],
      "enabled": true
    },
    "graphify-global": {
      "type": "local",
      "command": ["graphify-mcp", "--graph", "/Users/<you>/.graphify/global-graph.json"],
      "enabled": false
    }
  }
}
```

The relative local path assumes OpenCode starts the server at the repository root. For a frequently used project, prefer an absolute path in that project's `.opencode/opencode.json`. The global path must be absolute; command arrays do not expand `~`.

Verify the connection rather than relying only on config shape:

```bash
opencode mcp list
```

Then ask an agent to call `graph_stats` in a repository with `.ai/graphify-out/graph.json`. A node count proves the server resolved the graph. A `graph.json not found` response means the MCP path is wrong even if the server reports connected.

Every enabled MCP server contributes tool schemas to agent context. Keep `graphify-global` disabled unless cross-repository questions justify that fixed context cost.

## Local and global graphs

Each repository owns `.ai/graphify-out/graph.json`. Unless `OPENCODE_GRAPHIFY_GLOBAL=0`, first indexing and refresh also register it in Graphify's machine-wide graph:

- graph: `~/.graphify/global-graph.json`
- repository locations: `~/.graphify/global-manifest.json`
- tag: sanitized repository directory name

Useful human-run commands:

```bash
graphify global list
graphify global path
graphify global remove <tag>
graphify query "how does auth work" --graph ~/.graphify/global-graph.json
```

Use the repository graph for questions about a named local symbol. Use the global graph for open-ended cross-repository questions; identical symbol labels can exist in several repositories.

Reading the global manifest or another repository may require OpenCode's `external_directory` permission. If you allow it globally, keep Graphify's machine state read-only to agents:

```jsonc
"permission": {
  "external_directory": "allow",
  "edit": { "~/.graphify/**": "deny" }
}
```

## Recovery

Reopening OpenCode retries a failed refresh. When the mode file exists, deleting an unreadable or obsolete `graph.json` also causes a full background rebuild on the next session.

For an immediate manual rebuild, read `.ai/graphify-out/.opencode-index-mode` and run the matching command from the repository root:

```bash
# code-only
GRAPHIFY_OUT=.ai/graphify-out graphify extract . --code-only --global --as <tag>

# docs; use the backend recorded in the mode file
GRAPHIFY_OUT=.ai/graphify-out graphify extract . --backend <backend> --global --as <tag>
```

Omit `--global --as <tag>` when global registration is disabled. Add `--allow-partial` only when Graphify explicitly refuses an incomplete extraction.

Common symptoms:

- `graphify: command not found`: reinstall `graphifyy==0.9.32` and ensure its executable directory is on OpenCode's `PATH`.
- `graph.json not found` from MCP: export `GRAPHIFY_OUT`, verify the server working directory, or use an absolute `--graph` path.
- `graphify-out/` at the repository root: a manual `update`, `watch`, or extract ran without the standard `GRAPHIFY_OUT`; remove that stray output and rebuild under `.ai/`.
- `.ai/.ai/graphify-out/`: `GRAPHIFY_OUT` and `--out` were combined; remove the duplicated tree and use the environment variable alone.
- stale global entry after moving or deleting a repository: run `graphify global remove <tag>`.

Avoid `graphify update` and `graphify watch` in this integration; they can bypass the relocated output contract. `extract` is incremental and is the supported manual recovery path.

## Docs mode and privacy

Code-only mode is the default recommendation: it uses local parsing, needs no model credentials, and sends no corpus to an LLM. Docs mode performs semantic extraction and can be slower and billable. `/graphify-index` asks explicitly and records the selected backend so later refreshes cannot silently change providers based on whichever API key happens to be present.

Custom OpenAI-compatible backends belong in `~/.graphify/providers.json`, not in this repository. Keep project-local provider files disabled unless you intentionally trust the repository to choose where its corpus is sent.

## Agent boundary

Installed global rules make exploration graph-first when `.ai/graphify-out/graph.json` exists and MCP tools are available. Agents may query the local or global graph, then verify exhaustive inventories with filesystem tools. They must not run Graphify lifecycle commands (`extract`, `update`, `watch`, `global add|remove`, or any install variant): first indexing belongs to `/graphify-index`, refresh belongs to `graphify-init`, and manual recovery belongs to the human.
