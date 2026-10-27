---
name: oc-graphify
description: Query a Graphify code graph safely — MCP tools for both the repository's own graph and the cross-repository global graph, read-only CLI for hand-run use, availability detection, and graceful fallback. Use whenever a flow needs structural answers (callers, impact, flows, hubs) from an indexed repository.
license: MIT
metadata:
  author: andresnator
  version: "2.1.0"
  status: testing
---

# Graphify CLI

## Intent

- **Goal:** Answer structural questions (callers, impact, flows, hubs) from an indexed Graphify code graph, or degrade gracefully without one.
- **Limits:**
  - The graph is read-only material: find it, query it, never build it.
  - Never run `graphify extract`, `update`, `watch`, `global add`, `global remove`, or any `graphify ... install` variant. They mutate state, and `update`/`watch` recreate `graphify-out/` at the repository root, outside `.ai/`. First indexing belongs to the human-invoked `/graphify-index` command, refreshing belongs to the `graphify-init` plugin, and recovery belongs to the user.
  - The read-only CLI verbs are for humans only, never an agent path.
- **Fails if:** "No graph" is concluded from a wildcard search (patterns like `**/graphify-out/graph.json` miss dot-directories; an empty glob is inconclusive); a graph answer is cited without the underlying `file:line`; impact or blast-radius conclusions rest on a stale graph alone.

## Context

- **Reads:** `.ai/graphify-out/graph.json`, `.ai/graphify-out/.opencode-extract-lock`, `.ai/graphify-out/.opencode-index-mode`, `.ai/graphify-out/.graphify_semantic_marker`, `~/.graphify/global-manifest.json`, and `git rev-parse HEAD`.
- **Never reads:** Wildcard glob results as proof of graph absence.
- **Persona:** Careful graph querier that treats the graph as a locator, not evidence.
- **Scope:** Any flow needing structural answers from an indexed repository, through MCP tools for the repository's own graph and the cross-repository global graph.

| Graph | Path | Who |
|---|---|---|
| Repository's own (`.ai/graphify-out/graph.json`) | `graphify` MCP tools (`query_graph`, `get_neighbors`, …) | Agents |
| Cross-repository global (`~/.graphify/global-graph.json`) | `graphify-global` MCP tools + `~/.graphify/global-manifest.json` | Agents |
| Either graph, by hand | Read-only CLI with explicit `--graph` | Humans only |
| Lifecycle (first indexing, refresh) | `/graphify-index` command + `graphify-init` plugin | Human and plugin only, never agents |

## Expectations

- **Scenarios:**
  - WHEN `.ai/graphify-out/graph.json` (literal path) exists and parses THEN record `graphify: available`.
  - WHEN it is missing THEN record `graphify: absent`, skip Graphify, mention `/graphify-index` to the user once as the way to enable it, and continue without it.
  - WHEN the graph's `built_at_commit` differs from `git rev-parse HEAD` or `.ai/graphify-out/.opencode-extract-lock` exists THEN record `graphify: stale`: still query, but verify every claim against current files before citing it. Never refresh it yourself; the plugin refreshes it next session.
  - WHEN a question names a repository or project other than the current one THEN read `~/.graphify/global-manifest.json` before Context7, web search, or a clarifying question; an indexed tag means a local repo question and wins over library documentation.
  - WHEN the graph or MCP tools are unavailable THEN continue with the runtime's read, LSP, grep, and glob tools and state the fallback.
- **Done means:** Answers cite `file:line`, and the output records the availability state (`available`, `absent`, `stale`) and any fallback.
- **Quality needs:** Needing more than ~3 files for one structural question usually means the query was too broad; narrow it before crawling files.

## Method

### Documentation coverage

Read `.ai/graphify-out/.opencode-index-mode` (one JSON line): `docs` means documents are indexed as document and concept nodes, so documentation questions are graph-first; `code-only` means docs questions go straight to filesystem tools. When the mode file is missing, `.ai/graphify-out/.graphify_semantic_marker` present means `docs`, absent means `code-only`. Documentation, paper, and image nodes are treated like any other node.

### Local graph (MCP)

Tools: `query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `god_nodes`, `graph_stats`, `get_community`, read-only over the graph the server was started with.

- Omit the optional `project_path` argument unless you genuinely need another repository. Passing it makes the server resolve `<project_path>/<GRAPHIFY_OUT>/graph.json` from its own environment; without `GRAPHIFY_OUT` exported it reports no graph for a repository that has one. When a `project_path` call comes back empty, retry without it before concluding anything.
- If the MCP tools are unavailable, use the filesystem tools directly; the CLI is not an agent fallback.

### Global graph (MCP)

`~/.graphify/global-graph.json` merges every indexed repository under a repo tag; `graphify-global` exposes the same tool set. Answer structural questions with it. For content questions, the tag's `source_path` points at that repo's `.ai/graphify-out/graph.json`; the repository root is two directories up, so read and cite the actual files there. Node labels are not namespaced, so keep symbol-addressed queries on the repository's own graph and use the global graph for open-ended questions.

### Manual CLI verbs (human use)

Read-only verbs: `query`, `explain`, `path`, `affected`, `god-nodes`. Always pass `--graph`; the default `./<GRAPHIFY_OUT>/graph.json` resolves only with `GRAPHIFY_OUT=.ai/graphify-out` exported from the repo root.

```bash
graphify global list                                                  # repos and node counts
graphify query "<question>" --graph ~/.graphify/global-graph.json
graphify query "<question>" --graph .ai/graphify-out/graph.json --budget 2000
graphify explain "<NodeLabel>" --graph .ai/graphify-out/graph.json
```
