# Graphify Integration

Graphify is optional. This repository owns first-run consent, integration locks, and agent boundaries; [`opencode-graphify-init`](https://github.com/andresnator/opencode-graphify-init) owns refresher code, tests, and releases.

The supported baseline is OpenCode >= 1.17.15 and [`graphifyy` 0.9.32](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.32). The installer fetches the exact locked plugin commit and verifies its SHA-256 before changing a target.

## Quick path

1. Install the `common` domain:

   ```bash
   installers/opencode.sh install --domain common
   ```

2. Install Graphify with MCP support:

   ```bash
   uv tool install "graphifyy[mcp]==0.9.32"
   # or: pipx install "graphifyy[mcp]==0.9.32"
   ```

3. Launch OpenCode with the standard output path:

   ```bash
   export GRAPHIFY_OUT=.ai/graphify-out
   ```

4. Add the MCP entry below when agents need graph queries.
5. Run `/graphify-index` once in the repository and choose code-only or docs mode.

Do not run `graphify opencode install`, `graphify install --platform opencode`, or `graphify claude install`. Those commands can overwrite installer-managed rules and plugins.

## Ownership and lifecycle

| Owner | Responsibility |
|---|---|
| `/graphify-index` | Requests consent, performs first extraction, and records mode |
| `graphify-init` | Refreshes an approved graph when missing or stale |
| Human operator | Installs Graphify, configures MCP, and performs recovery |
| Agents | Query graphs and verify results against files |

Consent and mode live at `.ai/graphify-out/.opencode-index-mode`. Without that file, the refresher never starts first extraction. Code-only to docs adds document nodes; docs to code-only requires a confirmed rebuild. Aggregator directories discover nested Git repositories up to two levels deep, each with independent state.

Graph state lives under ignored `.ai/graphify-out/`. Use `GRAPHIFY_OUT=.ai/graphify-out` without `--out`; combining both can create `.ai/.ai/graphify-out/` and break MCP resolution.

| Variable | Effect |
|---|---|
| `GRAPHIFY_OUT=.ai/graphify-out` | Aligns CLI, refresher, and MCP paths |
| `OPENCODE_GRAPHIFY_AUTOINIT=0` | Disables refresh for one OpenCode process |
| `OPENCODE_GRAPHIFY_GLOBAL=0` | Skips global graph registration |
| `OPENCODE_GRAPHIFY_DOCS=1` | Defaults first-run docs mode |
| `OPENCODE_GRAPHIFY_BACKEND=<name>` | Defaults the docs backend |
| `GRAPHIFY_FORCE=1` | Forces a full rescan |

## MCP configuration

The installer never edits MCP config. Add only the servers you need to user or project `opencode.jsonc`:

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

The relative path assumes the server starts at the repository root. Prefer an absolute path in a frequently used project's `.opencode/opencode.json`; the global path must be absolute because command arrays do not expand `~`.

Verify both connection and data:

```bash
opencode mcp list
```

Then call `graph_stats` in a repository with a graph. A node count proves path resolution; `graph.json not found` means the configured path is wrong. Keep the global server disabled unless cross-repository queries justify its context cost.

## Local, global, and private data

Each repository owns `.ai/graphify-out/graph.json`. Unless disabled, Graphify also registers it in `~/.graphify/global-graph.json` and records locations in `~/.graphify/global-manifest.json`.

```bash
graphify global list
graphify global path
graphify global remove <tag>
graphify query "how does auth work" --graph ~/.graphify/global-graph.json
```

Use local graphs for named repository symbols and the global graph for cross-repository discovery. Reading global state may require `external_directory`; if enabled, deny agent edits to `~/.graphify/**`.

Code-only mode parses locally and sends no corpus to an LLM. Docs mode performs semantic extraction and may be slower or billable. `/graphify-index` records the backend so refreshes cannot silently switch providers. Put custom OpenAI-compatible providers in `~/.graphify/providers.json`, not this repository.

## Recovery

Reopen OpenCode to retry a failed refresh. With a mode file present, removing an unreadable `graph.json` triggers a rebuild on the next session. For immediate recovery, read the recorded mode and run the matching command from the repository root:

```bash
# code-only
GRAPHIFY_OUT=.ai/graphify-out graphify extract . --code-only --global --as <tag>

# docs
GRAPHIFY_OUT=.ai/graphify-out graphify extract . --backend <backend> --global --as <tag>
```

Omit `--global --as <tag>` when global registration is disabled. Add `--allow-partial` only after Graphify rejects an incomplete extraction. Avoid `graphify update` and `graphify watch`; they bypass this integration's output contract.

Common failures:

- `graphify: command not found`: reinstall `graphifyy==0.9.32` and fix OpenCode's `PATH`.
- `graph.json not found`: align `GRAPHIFY_OUT`, server working directory, and MCP path.
- Root `graphify-out/`: remove stray manual output and rebuild under `.ai/`.
- `.ai/.ai/graphify-out/`: remove the duplicate tree and stop combining `GRAPHIFY_OUT` with `--out`.
- Stale global entry: run `graphify global remove <tag>`.

Agents must never run lifecycle commands: `extract`, `update`, `watch`, global mutation, or installation. First indexing belongs to `/graphify-index`, refresh to `graphify-init`, and recovery to the human operator.
