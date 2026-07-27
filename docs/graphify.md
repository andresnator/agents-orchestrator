# Use Graphify safely with OpenCode

Graphify is optional. Install only its CLI; the repository installer never edits your OpenCode MCP configuration. Once the `common` domain is installed, background graph building and refresh run by default in every session; opt out per session with `OPENCODE_GRAPHIFY_AUTOINIT=0`.

Compatibility target: OpenCode `1.18.5` and Graphify (`graphifyy`) `0.9.28`.

## Quick setup

1. Install the CLI (installs both `graphify` and `graphify-mcp`):

   ```bash
   uv tool install graphifyy
   # or, without uv:
   pipx install graphifyy
   ```

2. Open a repository normally. Background graph building is on by default. To silence it for one session, opt out:

   ```bash
   OPENCODE_GRAPHIFY_AUTOINIT=0 opencode
   ```

Do not run `graphify opencode install`. It writes a Graphify section into `AGENTS.md` and drops its own `tool.execute.before` plugin — that would fight the `graphify-init` plugin and can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink. The same applies to `graphify install --platform opencode` and to `graphify claude install`, which edits `CLAUDE.md` (a symlink to this repository's `AGENTS.md`).

## Where Graphify keeps state

- **Per repository**: everything lives under `<repo>/.ai/graphify-out/` — `graph.json`, the incremental manifest, cache, analysis artifacts, `graph.html`, `GRAPH_REPORT.md`. The `graphify-out` leaf name is fixed by the CLI; the plugin relocates it under `.ai/` (the repo convention for local tool state) by passing `--out <repo>/.ai`, and Git-excludes exactly `.ai/graphify-out`. (Graphify also honours a `GRAPHIFY_OUT` environment variable as an output override; the plugin does not use it and always passes `--out` explicitly.)
- **Machine-wide**: `~/.graphify/` holds `global-graph.json` (the cross-repository graph), `global-manifest.json`, `cache/`, and `repos/`. There is no config file; behavior is controlled by CLI flags and environment variables (`GRAPHIFY_FORCE`, backend API keys for semantic mode, `~/.graphify/providers.json` for custom backends).

## Background initializer

Installing the `common` domain installs `domains/common/plugins/graphify-init.ts`. It runs by default (opt out with `OPENCODE_GRAPHIFY_AUTOINIT=0`). On OpenCode startup the plugin returns immediately, then works in the background:

1. Decide what each root needs using only local signals — no Graphify process is spawned to answer this.
2. Stay silent when the graph is up to date. An already-indexed session never invokes Graphify at all.
3. When `.ai/graphify-out/graph.json` is missing, unparseable, or stamped with a different commit than `HEAD`, show one start toast and spawn `graphify extract <root> --code-only --out <root>/.ai` without a shell (plus `--global --as <tag>`, see below; `--code-only` is dropped when documentation indexing is opted in — see "Indexing documentation"). Extract is natively incremental — its manifest gate re-parses only changed files — so the same command serves both first builds and refreshes.
4. Add `.ai/graphify-out` to `.git/info/exclude` *before* indexing — Graphify honours that file, so the entry is what keeps a rebuild from walking its own previous output.
5. Re-read the graph and show one result toast carrying the node count.

There is no dialog, blocking spinner, or repeated progress notification. Toast delivery is best-effort through OpenCode's TUI channel; indexing continues if no TUI is connected.

**Never run `graphify update`.** It has no `--out` flag and recreates `graphify-out/` at the repository root, outside `.ai/`. The plugin never spawns it, and manual refreshes should use the extract command above instead — it is just as incremental. The same caution applies to `graphify watch`.

**Freshness signal.** Graphify stamps `built_at_commit` into `graph.json`, so freshness is an exact comparison against `git rev-parse HEAD` rather than a heuristic. Graphs without that stamp fall back to comparing the file's mtime against the last commit time. A root with no commits (or no Git at all) and an existing graph counts as fresh: there is no evidence of staleness, so the graph is left alone. Uncommitted edits do not trigger a rebuild; run `graphify extract . --code-only --out ./.ai` yourself when you need one.

**Repositories with nothing to index.** A documentation-only or spec-only repository is a normal thing to open, but Graphify reports it as a failure (exit 1, no `graph.json`). The plugin recognizes that case and reports it once as information instead of an error, recording the commit in `.ai/graphify-out/.opencode-empty-corpus` so reopening the same commit stays silent (roots with no resolvable `HEAD` — plain directories, repositories without commits — record the sentinel `none` instead). A new commit earns a fresh attempt, so a repo that later gains code is picked up automatically, and a successful build clears the marker so re-checking out the once-empty commit is re-examined honestly. A repository whose code is all *deleted* behaves the same way — the refreshing extract reports an empty corpus and leaves the previous graph on disk untouched; the marker (checked before the stale graph) is what keeps the plugin from retrying it every session. The old nodes also remain in the global graph, since a failed extract never merges; drop them with `graphify global remove <tag>` if they bother you.

**Unsafe roots.** Graphify has no unsafe-root refusal of its own, so the plugin owns the guard: a session opened on your home directory, an ancestor of it, or the filesystem root is refused outright — that walk is unbounded and would write artifacts far outside any project.

**Workspace roots.** When the session root is itself a Git repository (it has a `.git` entry), the plugin acts on that single root. When the root is a plain folder with no `.git` — an aggregator workspace holding cloned repos — the plugin discovers nested Git repositories up to two directory levels deep, skipping hidden directories, `node_modules`, and symlinked directories. It processes each one sequentially to bound CPU, emitting one aggregate start toast and one aggregate summary toast instead of per-repository notifications. Each nested repository keeps its own `.ai/graphify-out/` and is registered in the global graph under its own tag. A plain folder with no nested repositories falls back to acting on the folder itself.

| Condition | Notification | Automatic action |
|---|---|---|
| Opt-out (`=0`), unsafe root, graph built at the current commit, or nothing to index at the current commit | None | None |
| `.ai/graphify-out/graph.json` missing or unparseable | `info`, 5 seconds | Background `extract --code-only --out <root>/.ai` (+ global merge) |
| Graph built at a different commit than `HEAD` | `info`, 5 seconds | The same incremental extract, worded as a refresh |
| Build or refresh succeeds and the graph is readable | `success`, 5 seconds | Clear any stale empty-corpus marker (the Git exclude entry is written before indexing starts, not on success) |
| Repository holds no indexable code (extract exits 1) | `info`, 5 seconds, once per commit | Record `.ai/graphify-out/.opencode-empty-corpus` (`none` for HEAD-less roots) |
| Refresh exits zero with a 0-node graph | `info`, 5 seconds | None; the freshly stamped graph itself keeps reopens silent |
| Build exits zero but the graph is still missing or unreadable | `warning`, 8 seconds | None; recover manually |
| CLI missing | `warning`, 8 seconds | None |
| Build or refresh process fails | `error`, 8 seconds | None; the OpenCode session stays operational |
| Non-git workspace root with nested repos | One aggregate `info`/`success`/`warning` toast | Process each nested repo sequentially |

Environment controls:

| Variable | Use |
|---|---|
| `OPENCODE_GRAPHIFY_AUTOINIT=0` | Opts this OpenCode process out of the common-domain initializer. Unset or any other value keeps it on (default). |
| `OPENCODE_GRAPHIFY_GLOBAL=0` | Builds graphs for local use only; skips merging them into the cross-repository global graph. |
| `OPENCODE_GRAPHIFY_DOCS=1` | Opts the initializer into documentation indexing: extract runs without `--code-only`, so doc/paper/image files go through Graphify's semantic LLM pass. Needs a backend (see "Indexing documentation"). |
| `OPENCODE_GRAPHIFY_BACKEND=<name>` | Pins Graphify's `--backend` for docs-mode extracts, instead of relying on its API-key auto-detection. Ignored while docs mode is off. |
| `GRAPHIFY_FORCE=1` | Graphify's own escape hatch for `extract`: disables the incremental manifest gate and semantic-cache reads, forcing a full re-scan. It does **not** unlock shrink or incomplete-extraction refusals — that is `--allow-partial`. |

## Cross-repository global graph

Graphify supports one machine-wide graph natively. Each repository keeps its own `.ai/graphify-out/graph.json` inside the working tree (Git-excluded), and its nodes are additionally merged into `~/.graphify/global-graph.json` under a repository tag.

The initializer does this automatically unless `OPENCODE_GRAPHIFY_GLOBAL=0`: every build and refresh passes `--global --as <tag>`, so `extract` merges in the same call. The tag is the repository's real directory name with non `[A-Za-z0-9_-]` characters replaced by `-`. Two checkouts with the same directory name collide on one tag; re-registering simply replaces the previous entry.

Inspect and query it from anywhere:

```bash
graphify global list                  # repos and node counts
graphify global path                  # location of the global graph
graphify global remove <tag>          # drop one repo's nodes
graphify query "how does auth work" --graph ~/.graphify/global-graph.json
```

Global nodes carry a `repo` tag and repo-scoped ids, so source-bearing nodes from different repositories are never merged and answers stay attributable. External-library nodes (nodes with no source file, such as imported third-party symbols) are the exception: they are merged by label across repositories, which is what lets the global graph answer "which of my repos use this library". Labels are *not* namespaced, though: two repositories that both define a `TokenStore` contribute two distinct nodes with the same label, and a label-addressed query against the global graph (`explain`, `path`, `affected`) resolves to only one of them. Prefer the global graph for open-ended `query` questions and the per-repository graph when you are naming a specific symbol.

Removing a repository from disk does not remove it from the global graph; run `graphify global remove <tag>`.

## Querying the graph

Read-only CLI queries. The verbs default to `./graphify-out/graph.json`, which no longer exists after relocation, so always pass `--graph` explicitly — the per-repo graph (`.ai/graphify-out/graph.json` from the repo root) or the global one:

```bash
graphify query "where is the session token validated" --graph .ai/graphify-out/graph.json --budget 2000
graphify path "LoginController" "TokenStore" --graph .ai/graphify-out/graph.json
graphify explain "TokenStore" --graph .ai/graphify-out/graph.json
graphify affected "TokenStore" --depth 2 --graph .ai/graphify-out/graph.json
graphify god-nodes --top 10 --graph .ai/graphify-out/graph.json
```

`query` does a token-budgeted BFS traversal (`--dfs` for depth-first, `--context` to filter edge contexts); `affected` is the reverse-traversal impact query; `god-nodes` lists the most connected hubs. The `graphify-cli` skill (`skills/graphify-cli/`) packages these conventions for agents.

## MCP server (optional)

For agents without shell access, Graphify also serves the graph over MCP. The MCP transport is an optional dependency, so install it explicitly:

```bash
uv tool install "graphifyy[mcp]"
# already installed via pipx:
pipx inject graphifyy mcp
```

The `pipx inject graphifyy mcp` line covers the default stdio transport only; running the server with `--transport http` additionally needs `starlette` (or reinstall with `pipx install --force "graphifyy[mcp]"`).

Then merge this entry into your user or project `opencode.jsonc` — the repository installer never does it for you:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "graphify": {
      "type": "local",
      "command": ["graphify-mcp", "--graph", ".ai/graphify-out/graph.json"],
      "enabled": true
    }
  }
}
```

OpenCode spawns local MCP servers with the project directory as working directory, so the relative `--graph` path resolves to the current repository's graph. If your OpenCode version spawns servers elsewhere, point `--graph` at `~/.graphify/global-graph.json` instead — cross-repository answers, with the label-collision caveat above. Verified tools: `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`, plus three GitHub PR-impact tools (`list_prs`, `get_pr_impact`, `triage_prs`) that need a GitHub token and are unrelated to structural exploration. Every exposed tool adds its schema to each session's context; there is no per-tool allowlist flag, so enable this server only where MCP-only agents actually need it.

## Recovery

The initializer never retries on its own. When a toast reports a failure, recover manually:

```bash
graphify extract /path/to/repo --code-only --out /path/to/repo/.ai                   # full or incremental rebuild
graphify extract /path/to/repo --code-only --out /path/to/repo/.ai --allow-partial   # only if Graphify refuses an incomplete extraction
```

(`GRAPHIFY_FORCE=1` is not the remedy for a refusal: on `extract` it only disables the incremental gate and semantic-cache reads, producing an expensive full re-scan that gets refused again. `--allow-partial` is the flag that accepts an incomplete result.)

Never reach for `graphify update` here: it ignores `.ai/` and recreates `graphify-out/` at the repository root (see the initializer section).

Run these **from the repository root**: `built_at_commit` records the HEAD of the directory graphify is invoked from, not of the target path. A wrong stamp is not fatal — the initializer sees it as stale and heals it with one extra refresh on the next session — but it costs a needless rebuild cycle. (The plugin itself always spawns Graphify with the repository as its working directory.) Ordinary deletions do not need force; shrinking rebuilds were verified to succeed without it.

Other common checks:

- Missing CLI: `uv tool install graphifyy` (or `pipx install graphifyy`).
- `--code-only` needs no API key and no network. Omitting it enables semantic LLM extraction, which does; the initializer passes it unless documentation indexing is opted in (see the next section).
- Everything Graphify writes for a repo lives under `.ai/graphify-out/`, so the single `.ai/graphify-out` exclude entry covers the whole working tree.
- A stray `graphify-out/` at the repository root means someone ran `graphify update`, `watch`, or an `--out`-less `extract` by hand; delete it and rebuild with the command above.
- Stale global entry after deleting or renaming a repo: `graphify global remove <tag>`.

## Indexing documentation (opt-in)

By default the initializer indexes code only: `--code-only` is pure local AST parsing, needs no credentials, and sends nothing anywhere. Graphify can additionally index documentation — Markdown, papers, images — through a semantic LLM pass, which the plugin enables when **both** pieces are in place:

1. `OPENCODE_GRAPHIFY_DOCS=1` in the OpenCode server's environment. The plugin then omits `--code-only` from every extract.
2. An LLM backend Graphify can use. Without one, extract exits 1 with "no LLM API key found". Pin it with `OPENCODE_GRAPHIFY_BACKEND=<name>` (recommended — auto-detection picks the first provider whose API-key variable happens to be set, and a stray key should not decide where your corpus is sent).

Any provider Graphify auto-detects works (Gemini, Claude, OpenAI, DeepSeek, Ollama, …). To use an OpenAI-compatible gateway — for example an OpenCode Zen model — declare a custom provider in `~/.graphify/providers.json`:

```json
{
  "opencode": {
    "base_url": "https://opencode.ai/zen/go/v1",
    "env_key": "GRAPHIFY_OPENCODE_API_KEY",
    "model_env_key": "GRAPHIFY_OPENCODE_MODEL",
    "default_model": "glm-5"
  }
}
```

Then export the key and the opt-ins in your shell profile (the env names are Graphify-scoped on purpose — do not export `OPENCODE_API_KEY`, which could interfere with OpenCode's own auth):

```bash
export GRAPHIFY_OPENCODE_API_KEY=$(jq -r '."opencode-go".key // empty' ~/.local/share/opencode/auth.json)
export OPENCODE_GRAPHIFY_DOCS=1
export OPENCODE_GRAPHIFY_BACKEND=opencode
```

Notes:

- **Cost and latency**: semantic results are cached and gated by the same incremental manifest, so after the first full pass only changed documents trigger LLM calls. The calls happen in the plugin's background extract; nothing blocks the session.
- **Docs-only repositories change category**: with docs mode on, a Markdown-only repo yields a real graph of document nodes instead of the empty-corpus marker.
- **Security**: Graphify ignores a project-local `providers.json` unless `GRAPHIFY_ALLOW_LOCAL_PROVIDERS=1` is set — only your `~/.graphify/providers.json` is trusted by default, so a cloned repo cannot silently redirect your corpus to its own endpoint. Keep it that way.
- The recovery commands in the previous section mirror the active mode: in docs mode the failure toast advertises the extract without `--code-only` (plus `--backend` when pinned).

## Agent behavior

The installed global rules make structural exploration graph-first when a graph exists at `.ai/graphify-out/graph.json`. Agents use the read-only CLI queries above when they have shell access, the MCP tools when they do not and the server is configured, and normal LSP/filesystem tools as fallback. MCP-only agents (no bash) depend entirely on the `opencode.jsonc` MCP entry, which the installer never writes: until you add it yourself, those agents resolve `graphify: absent` even when a healthy graph sits on disk. The reusable contract lives in the `graphify-cli` skill; lifecycle commands (`extract`, `update`, `watch`, `global add|remove`, any `install`) belong to the `graphify-init` plugin alone. Domain-specific restrictions still win — SDD agents keep their stricter lifecycle and read-only rules.
