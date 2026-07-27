---
name: graphify-cli
description: Query a Graphify code graph safely — availability detection, read-only CLI verbs with the relocated graph path, cross-repository global graph, and the MCP fallback. Use whenever a flow needs structural answers (callers, impact, flows, hubs) from an indexed repository.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# Graphify CLI

Reusable contract for querying a Graphify code graph. The graph is read-only material: this skill covers finding it, querying it, and degrading gracefully — never building it.

## Availability detection

1. The per-repository graph lives at `.ai/graphify-out/graph.json` (repo root). If that file exists and parses, the graph is available; record `graphify: available`.
2. To confirm the CLI itself, run `graphify --version` (shell access) — a missing binary means CLI queries are off the table even when the graph file exists.
3. If the graph file is missing, record `graphify: absent` and skip Graphify entirely. Do not build it: the `graphify-init` OpenCode plugin owns creation and refresh.

## Read-only query verbs

Always pass `--graph` explicitly — the CLI's default (`./graphify-out/graph.json`) does not exist in the relocated layout:

```bash
graphify query "<natural-language question>" --graph .ai/graphify-out/graph.json --budget 2000
graphify explain "<NodeLabel>" --graph .ai/graphify-out/graph.json
graphify path "<NodeA>" "<NodeB>" --graph .ai/graphify-out/graph.json
graphify affected "<NodeLabel>" --depth 2 --graph .ai/graphify-out/graph.json
graphify god-nodes --top 10 --graph .ai/graphify-out/graph.json
```

- `query`: token-budgeted BFS traversal for open-ended questions (`--dfs` for depth-first, `--context` to filter edge contexts).
- `explain`: one node with its neighborhood.
- `path`: shortest connection between two symbols.
- `affected`: reverse-traversal impact — who breaks if this changes.
- `god-nodes`: the most connected hubs.

Run from the repository root so the relative graph path resolves. Cite the underlying `file:line` for every claim the graph resolves; the graph is a locator, not evidence by itself. Graphs may also contain documentation, paper, and image nodes when the repository owner enabled semantic indexing — treat them like any other node.

## Cross-repository global graph

`~/.graphify/global-graph.json` merges every indexed repository under a repo tag. Use it for open-ended questions that span repositories:

```bash
graphify global list                                            # repos and node counts
graphify query "<question>" --graph ~/.graphify/global-graph.json
```

Caveat: node labels are not namespaced. Two repositories defining the same class contribute two same-label nodes, and label-addressed verbs (`explain`, `path`, `affected`) resolve to only one of them. Keep symbol-addressed queries on the repository's own graph; use the global graph for `query`-style questions.

## Without shell access

Use the Graphify MCP tools when that server is configured: `query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `god_nodes`, `graph_stats`, `get_community`. They answer over the graph the server was started with (per-repo or global) — same read-only semantics.

## Hard rule: never lifecycle commands

Never run `graphify extract`, `update`, `watch`, `global add`, `global remove`, or any `graphify ... install` variant. They mutate state, and `update`/`watch` recreate `graphify-out/` at the repository root, outside `.ai/`. Building and refreshing belong to the `graphify-init` plugin; recovery belongs to the user.

## Fallback

When the graph or the tooling is unavailable, continue with the runtime's normal read, LSP, grep, and glob tools without friction, and state the fallback in your output. Needing more than ~3 files for one structural question usually means the graph query was too broad — narrow it before crawling files.
