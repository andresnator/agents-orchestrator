# Graphify Integration

Graphify is optional. The pinned `opencode-graphify-init@0.2.0` supports **code-only** indexing and conservative lock ownership, not LLM document indexing or automatic dead-PID lock takeover. Source comments/docstrings remain included; repository documents are never deleted.

The integration requires OpenCode >=2.0.28 and <3; the documented Graphify target is [`graphifyy` 0.9.32](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.32). The installer pins the npm package; OpenCode resolves it at startup without a global npm install.

## Quick path

1. Install `common`: `installers/opencode.sh install --domain common`.
2. Install Graphify MCP support manually: `uv tool install "graphifyy[mcp]==0.9.32"` or `pipx install "graphifyy[mcp]==0.9.32"`.
3. Set `GRAPHIFY_OUT=.ai/graphify-out`; never combine it with `--out`.
4. Configure only the MCP servers you need below.
5. Run `/graphify-index`, approve local code-only indexing, and inspect its outcome.

Do not run `graphify opencode install`, `graphify install --platform opencode`, or `graphify claude install`: they can overwrite managed integration files. Docs/backend environment options are not part of this pinned integration; do not offer them or promise their mode persists.

## Ownership and lifecycle

| Owner | Responsibility |
| --- | --- |
| `/graphify-index` | Explicit consent and first local code-only extraction |
| `graphify-init` | Locked reconstruction, incremental refresh, owned global reconciliation |
| Human operator | Install tools/MCP and recover uncertain locks after quiescence |
| Agents | Read-only graph queries checked against source |

Inspect hidden state by literal path:

| Path | Meaning |
| --- | --- |
| `.ai/graphify-out/graph.json` | Local graph |
| `.opencode-index-mode` in that directory | Consent; `policyVersion: 1` proves a completed code-only build or confirmed empty outcome |
| `.opencode-extract-lock` | Exclusive owner/direct child PIDs; retained on uncertainty |
| `.opencode-empty-corpus` | Commit confirmed to have no indexable code |
| `~/.graphify/global-manifest.json` | Optional global contribution owners |
| `~/.graphify/.opencode-global-lock` | Exclusive plugin global mutation lock |

A historical `mode: code-only` or `mode: docs` alone does not prove the graph is clean. The plugin reconstructs previously authorized unversioned generated state under its lock, preserving consent, locks and source documents. Failed/interrupted reconstruction does not certify an old graph. A confirmed empty corpus avoids retries at the same commit; changed HEAD permits a new attempt.

Versioned graphs refresh incrementally. Local/global locks serialize plugin-controlled work only; external Graphify processes may ignore them. Global reconciliation checks canonical `source_path` ownership before replacing/removing a contribution, refuses foreign tags or unsafe state, and retains pending work for retry.

| Variable | Effect |
| --- | --- |
| `GRAPHIFY_OUT=.ai/graphify-out` | Align CLI, refresher and MCP paths |
| `OPENCODE_GRAPHIFY_AUTOINIT=0` | Disable refresh for this OpenCode process |
| `OPENCODE_GRAPHIFY_GLOBAL=0` | Leave shared global state untouched; reconciliation remains pending |

## MCP configuration

The installer does not register MCP servers. Add only those needed to user/project `opencode.jsonc`:

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

Relative paths require the repository working directory; prefer an absolute local graph path when that is uncertain. Global paths must be absolute because command arrays do not expand `~`. Keep global MCP disabled unless cross-repository queries justify its context cost.

Run `opencode mcp list`, then `graph_stats` against an existing graph. A node count verifies data resolution; a connection alone does not. Use filesystem tools for documentation, not a code-only graph.

## Recovery

An existing local or global lock is **never automatically reclaimed**, even when its PIDs are dead. Children/descendants can outlive parents; a read/unlink/create sequence can erase a new owner.

Stop all affected OpenCode/Graphify processes, including wrappers and descendants, and verify none can write. Inspect exact lock ownership; only then may a human remove the relevant repository lock or owned global lock. Preserve consent, graph artifacts, unrelated locks and the shared store. If quiescence or ownership is uncertain, leave the lock and escalate. Reopen after recovery; the plugin performs its locked cleanup/retry.

An extraction failure's `GRAPHIFY_OUT=.ai/graphify-out graphify extract '<repo>' --code-only` hint is diagnostic, not permission for an unlocked rebuild or tag replacement. Do not manually certify a failed or empty build; let the plugin confirm and record its outcome.

For missing tools, install the documented target and repair PATH. For missing graphs, check output path, working directory and MCP path. Do not purge global data or override a foreign tag to fix local errors.

Agents never run lifecycle commands (`extract`, `update`, `watch`, global mutation or install). First indexing belongs to the explicitly invoked command; refresh to the plugin; recovery to the human operator.
