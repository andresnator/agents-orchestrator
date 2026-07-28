# Use Graphify safely with OpenCode

Graphify is optional. Install only its CLI; the repository installer never edits your OpenCode MCP configuration. Once the `common` domain is installed, the lifecycle splits in two: **first indexing is human-gated behind the `/graphify-index` command** (it asks whether to index and in which mode), and the `graphify-init` plugin keeps already-indexed repositories fresh in the background by default; opt the refresher out per session with `OPENCODE_GRAPHIFY_AUTOINIT=0`.

Compatibility target: OpenCode `1.18.5` and Graphify (`graphifyy`) `0.9.28`.

## Quick setup

1. Install the CLI (installs both `graphify` and `graphify-mcp`):

   ```bash
   uv tool install graphifyy
   # or, without uv:
   pipx install graphifyy
   ```

2. Open a repository and run `/graphify-index` once. It asks whether to index code-only (recommended: seconds, local, free) or docs + code (minutes, spends LLM tokens), runs the first extract, and records the decision in `.ai/graphify-out/.opencode-index-mode`. From then on the plugin refreshes the graph automatically each session. A repository that never ran the command gets one informational toast per session and is never indexed behind your back. To silence the refresher for one session, opt out:

   ```bash
   OPENCODE_GRAPHIFY_AUTOINIT=0 opencode
   ```

Do not run `graphify opencode install`. It writes a Graphify section into `AGENTS.md` and drops its own `tool.execute.before` plugin — that would fight the `graphify-init` plugin and can replace the installer-managed `~/.config/opencode/AGENTS.md` symlink. The same applies to `graphify install --platform opencode` and to `graphify claude install`, which edits `CLAUDE.md` (a symlink to this repository's `AGENTS.md`).

## Where Graphify keeps state

- **Per repository**: everything lives under `<repo>/.ai/graphify-out/` — `graph.json`, the incremental manifest, cache, analysis artifacts, `graph.html`, `GRAPH_REPORT.md`. The plugin relocates the whole output tree under `.ai/` (the repo convention for local tool state) by exporting `GRAPHIFY_OUT=.ai/graphify-out` on every Graphify call, and Git-excludes exactly `.ai/graphify-out`.
- **`GRAPHIFY_OUT`, not `--out`.** The env var and the flag are not interchangeable and never override each other:
  - `--out` moves only where `extract` *writes*. The MCP server never sees it, so a `project_path` query still resolves `<project_path>/<GRAPHIFY_OUT>/graph.json` and misses a graph relocated with the flag alone. That mismatch is why agents report "no graph" on a repository that has one.
  - The two **concatenate**: `GRAPHIFY_OUT=.ai/graphify-out` together with `--out <repo>/.ai` writes to `<repo>/.ai/.ai/graphify-out/`. Use the variable alone.
  - Export it in your shell profile too (`export GRAPHIFY_OUT=.ai/graphify-out`), so hand-run CLI verbs and the MCP server agree with the plugin.
- **Machine-wide**: `~/.graphify/` holds `global-graph.json` (the cross-repository graph), `global-manifest.json`, `cache/`, and `repos/`. There is no config file; behavior is controlled by CLI flags and environment variables (`GRAPHIFY_FORCE`, backend API keys for semantic mode, `~/.graphify/providers.json` for custom backends).

## First indexing: the `/graphify-index` command

The first indexing of any root happens only on explicit human request, through the `graphify-index` command installed with the `common` domain (it declares `agent: build` so it runs under OpenCode's permissive built-in primary — restricted primaries like `architect` or `deep-planner` cannot run Graphify or write `.ai/`). The command asks two things in chat before touching anything: whether to index at all, and in which mode — **code-only** (recommended: pure local AST, seconds, no credentials) or **docs + code** (semantic LLM pass over documentation: minutes and real token spend — a reference docs pass over this ~300-file repository billed ~184k output tokens). It states the expected duration up front, notes that later passes are incremental, runs the extract, and records the decision at `.ai/graphify-out/.opencode-index-mode` (`{"mode":"code-only"}` or `{"mode":"docs","backend":"<name>"}`).

The extract runs under the same `.opencode-extract-lock` the plugin honors, taken in the same shell invocation *before* the mode file is written. Order matters: the mode file is standing consent, so a second OpenCode session opened mid-extract would otherwise see consent plus no graph and start a duplicate, token-spending extraction; with the lock already held it skips silently instead.

Changing an existing repository's mode is direction-sensitive. **docs → code-only** requires a purge first (`graphify global remove <tag>`, then delete the contents of `.ai/graphify-out/`) because Graphify deliberately preserves document/paper/image nodes across a `--code-only` incremental rebuild — without the purge the recorded mode would lie about the graph's contents. **code-only → docs** needs no purge: the incremental semantic pass adds document nodes on top of the unchanged code.

That mode file is the contract between the command and the plugin: its presence is standing consent to rebuild, and its content decides the flags of every future refresh. Environment variables never override it — a repository indexed code-only stays code-only even in a shell exporting `OPENCODE_GRAPHIFY_DOCS=1`.

On an aggregator workspace (a plain folder holding cloned repos), the command discovers nested Git repositories up to two levels deep — skipping hidden directories, `node_modules`, and symlinks — lists them, confirms the set, and indexes each one with the same recorded-mode contract.

## Background refresher

Installing the `common` domain installs `domains/common/plugins/graphify-init.ts` (to install this plugin manually without the repo installer, see `docs/manual-plugin-install.md`). It runs by default (opt out with `OPENCODE_GRAPHIFY_AUTOINIT=0`). On OpenCode startup the plugin returns immediately, then works in the background:

1. Decide what each root needs using only local signals — no Graphify process is spawned to answer this.
2. Stay silent when the graph is up to date. An already-indexed session never invokes Graphify at all.
3. **Never perform a first indexing.** A root with no readable `graph.json` and no `.opencode-index-mode` gets one informational toast per session pointing at `/graphify-index`, and zero Graphify processes.
4. When the graph is stamped with a different commit than `HEAD`, refresh it with the flags derived from `.opencode-index-mode`. Graphs indexed before the mode file existed fall back to the semantic marker: `.graphify_semantic_marker` present ⇒ docs mode (backend pinned by `OPENCODE_GRAPHIFY_BACKEND`, matching what built them), absent ⇒ code-only. After any successful run the plugin re-persists the mode file, so the fallback is only ever used once.
5. When `graph.json` is missing or unparseable but `.opencode-index-mode` exists, rebuild automatically — the consent is on record. Deleting `graph.json` is therefore a safe way to force a rebuild.
6. Add `.ai/graphify-out` to `.git/info/exclude` *before* indexing — Graphify honours that file, so the entry is what keeps a rebuild from walking its own previous output.
7. Re-read the graph and show one result toast carrying the node count.

There is no dialog, blocking spinner, or repeated progress notification. Toast delivery is best-effort through OpenCode's TUI channel; indexing continues if no TUI is connected. Toasts are deferred until the TUI is actually subscribed — bus events published before the subscription are silently lost, and the TUI attaches a second or two after the plugin has already scanned — so the plugin queues them and flushes on the first client-driven event or at most ~10 seconds after startup, whichever comes first.

**Concurrency lock.** Before spawning an extract the plugin takes `.ai/graphify-out/.opencode-extract-lock` with the session's PID, then adds the spawned extract child's PID as a second line once it is running. A second session opening the same repository mid-extract sees the live lock and skips silently — the first session owns the toasts. The lock is stale only when **every** PID it lists is dead (crashed or killed session *and* no surviving extract child); only then is it replaced. The lock is removed when the extract finishes. The `/graphify-index` command takes the same lock for the first extraction.

**Shutdown kills the extract.** Spawned Graphify processes are tracked and killed when the OpenCode process exits or receives SIGHUP/SIGINT/SIGTERM, so closing OpenCode mid-extract no longer leaves an orphan burning CPU (and, in docs mode, LLM tokens). A hard `kill -9` of the server still orphans the child — but the lock also names the child's PID, so the next session sees the orphan still alive and skips instead of starting a duplicate extraction beside it. Once the orphan finishes or dies, the all-PIDs-dead check repairs the lock on the following session, and Graphify's incremental manifest plus semantic cache make the retry cheap.

**Never run `graphify update`.** It ignores the relocation and recreates `graphify-out/` at the repository root, outside `.ai/`. The plugin never spawns it, and manual refreshes should use the extract command above instead — it is just as incremental. The same caution applies to `graphify watch`.

**Freshness signal.** Graphify stamps `built_at_commit` into `graph.json`, so freshness is an exact comparison against `git rev-parse HEAD` rather than a heuristic. Graphs without that stamp fall back to comparing the file's mtime against the last commit time. The stamp is written at *export* time, after scanning — so a commit that lands mid-extract would produce a graph carrying the new HEAD over content read from the old tree, and the exact comparison would call it fresh forever. The plugin closes that hole: it captures HEAD before spawning, re-reads it after the extract, and on a mismatch re-runs the extract once (incremental, so cheap); if HEAD moves again during the retry it reports the build as failed so the next session picks it up. A root with no commits (or no Git at all) and an existing graph counts as fresh: there is no evidence of staleness, so the graph is left alone. Uncommitted edits do not trigger a rebuild; run `GRAPHIFY_OUT=.ai/graphify-out graphify extract . --code-only` yourself when you need one.

**Repositories with nothing to index.** A documentation-only or spec-only repository is a normal thing to open, but Graphify reports it as a failure (exit 1, no `graph.json`). The plugin recognizes that case by Graphify's own end-of-run signal — the `extraction produced no nodes` line — never by the census counts (`found N code, N docs, …`), which are ambiguous: a docs-mode run that dies on a backend or credential error also reports `0 code`, and that is a fixable failure that must keep its error toast and its retry, not an empty corpus. The genuine empty corpus is reported once as information instead of an error, recording the commit in `.ai/graphify-out/.opencode-empty-corpus` so reopening the same commit stays silent (roots with no resolvable `HEAD` — plain directories, repositories without commits — record the sentinel `none` instead). A new commit earns a fresh attempt, so a repo that later gains code is picked up automatically, and a successful build clears the marker so re-checking out the once-empty commit is re-examined honestly. A repository whose code is all *deleted* behaves the same way — the refreshing extract reports an empty corpus and leaves the previous graph on disk untouched; the marker (checked before the stale graph) is what keeps the plugin from retrying it every session. The old nodes also remain in the global graph, since a failed extract never merges; drop them with `graphify global remove <tag>` if they bother you.

**Unsafe roots.** The plugin carries no unsafe-root guard: it never indexes without a recorded mode file, so the worst a session opened on your home directory can produce is a hint toast. The refusal lives where resources are actually spent — `/graphify-index` declines to index the filesystem root, the home directory, or any ancestor of it, and suggests opening a concrete project folder instead.

**Workspace roots.** When the session root is itself a Git repository (it has a `.git` entry), the plugin acts on that single root. When the root is a plain folder with no `.git` — an aggregator workspace holding cloned repos — the plugin discovers nested Git repositories up to two directory levels deep, skipping hidden directories, `node_modules`, and symlinked directories. Nested repositories with a recorded mode are refreshed sequentially to bound CPU, with one aggregate start toast and one aggregate summary toast instead of per-repository notifications; nested repositories that were never indexed are counted in a single informational toast pointing at `/graphify-index`. Each nested repository keeps its own `.ai/graphify-out/` and is registered in the global graph under its own tag. A plain folder with no nested repositories falls back to acting on the folder itself — which, without a mode file, means a hint toast and nothing else.

| Condition | Notification | Automatic action |
|---|---|---|
| Opt-out (`=0`), graph built at the current commit, or nothing to index at the current commit | None | None |
| No readable graph and no `.opencode-index-mode` | `info`, 8 seconds, once per session | **None — the plugin never performs a first indexing.** The toast points at `/graphify-index` |
| `.ai/graphify-out/graph.json` missing or unparseable, `.opencode-index-mode` present | `info`, 5 seconds | Automatic rebuild with the recorded mode's flags under `GRAPHIFY_OUT=.ai/graphify-out` (+ global merge) |
| Graph built at a different commit than `HEAD` | `info`, 5 seconds | Incremental refresh with the recorded mode's flags (fallback for pre-mode-file graphs: semantic marker ⇒ docs, none ⇒ `--code-only`) |
| Build or refresh succeeds and the graph is readable | `success`, 5 seconds | Clear any stale empty-corpus marker and re-persist `.opencode-index-mode` (the Git exclude entry is written before indexing starts, not on success) |
| Repository holds no indexable code (extract exits 1) | `info`, 5 seconds, once per commit | Record `.ai/graphify-out/.opencode-empty-corpus` (`none` for HEAD-less roots) |
| Refresh exits zero with a 0-node graph | `info`, 5 seconds | None; the freshly stamped graph itself keeps reopens silent |
| Build exits zero but the graph is still missing or unreadable | `warning`, 8 seconds | None; recover manually |
| Build succeeds but the `--global` merge fails (Graphify warns on stderr and still exits 0) | `success` for the local graph plus `warning`, 8 seconds, advertising `graphify global add … --as <tag>` | None; the local graph is fresh, so re-register by hand |
| CLI missing | `warning`, 8 seconds | None |
| Build or refresh process fails | `error`, 8 seconds | None; the OpenCode session stays operational |
| Another live session holds `.opencode-extract-lock` for the repo | None | Skip; the session holding the lock owns the toasts |
| Non-git workspace root with nested repos | One aggregate `info`/`success`/`warning` toast for refreshes, plus one `info` toast listing never-indexed repos | Refresh each mode-recorded nested repo sequentially |

Environment controls:

| Variable | Use |
|---|---|
| `OPENCODE_GRAPHIFY_AUTOINIT=0` | Opts this OpenCode process out of the common-domain refresher. Unset or any other value keeps it on (default). |
| `OPENCODE_GRAPHIFY_GLOBAL=0` | Builds graphs for local use only; skips merging them into the cross-repository global graph. |
| `OPENCODE_GRAPHIFY_DOCS=1` | Default the `/graphify-index` command offers for the docs question. **Refreshes ignore it**: the per-repo `.opencode-index-mode` decides. |
| `OPENCODE_GRAPHIFY_BACKEND=<name>` | Default backend the `/graphify-index` command offers for docs mode, and the backend pin used when refreshing a legacy docs graph that predates the mode file. Recorded modes carry their own backend. |
| `GRAPHIFY_OUT=.ai/graphify-out` | Graphify's own output-tree location, resolved relative to the indexed root. The initializer exports it on every Graphify call; export it in your shell profile as well so hand-run verbs and the MCP server resolve the same path. Never combine it with `--out` — the two concatenate. |
| `GRAPHIFY_FORCE=1` | Graphify's own escape hatch for `extract`: disables the incremental manifest gate and semantic-cache reads, forcing a full re-scan. It does **not** unlock shrink or incomplete-extraction refusals — that is `--allow-partial`. |

## Cross-repository global graph

Graphify supports one machine-wide graph natively. Each repository keeps its own `.ai/graphify-out/graph.json` inside the working tree (Git-excluded), and its nodes are additionally merged into `~/.graphify/global-graph.json` under a repository tag.

The `/graphify-index` command and the background refresher both do this automatically unless `OPENCODE_GRAPHIFY_GLOBAL=0`: every build and refresh passes `--global --as <tag>`, so `extract` merges in the same call. The tag is the repository's real directory name with non `[A-Za-z0-9_-]` characters replaced by `-`. Two checkouts with the same directory name collide on one tag; re-registering simply replaces the previous entry. Graphify swallows a failed merge — it prints `[graphify global] warning: failed to merge…` to stderr and still exits 0 — so the plugin watches for that line and raises a warning toast with the manual re-registration command (`graphify global add <repo>/.ai/graphify-out/graph.json --as <tag>`); the local graph is genuinely fresh in that case, so nothing retries the merge automatically.

Inspect and query it from anywhere:

```bash
graphify global list                  # repos and node counts
graphify global path                  # location of the global graph
graphify global remove <tag>          # drop one repo's nodes
graphify query "how does auth work" --graph ~/.graphify/global-graph.json
```

Global nodes carry a `repo` tag and repo-scoped ids, so source-bearing nodes from different repositories are never merged and answers stay attributable. External-library nodes (nodes with no source file, such as imported third-party symbols) are the exception: they are merged by label across repositories, which is what lets the global graph answer "which of my repos use this library". Labels are *not* namespaced, though: two repositories that both define a `TokenStore` contribute two distinct nodes with the same label, and a label-addressed query against the global graph (`explain`, `path`, `affected`) resolves to only one of them. Prefer the global graph for open-ended `query` questions and the per-repository graph when you are naming a specific symbol.

The global graph also answers "where does that repository live": `~/.graphify/global-manifest.json` records each tag's `source_path` (the repo's `.ai/graphify-out/graph.json`, so the repository root is two directories up). Agents read it when a question names another indexed repository — the tie-break against treating the name as a public library — and answer content questions (documentation, file text) from the files at that location.

Reading `~/.graphify/` or another repository's files trips OpenCode's `external_directory` permission (default `ask`) on every different target path — a per-repo allowlist does not scale since the target repository depends on the question. Grant it globally once in `~/.config/opencode/opencode.jsonc`:

```jsonc
"permission": {
  "external_directory": "allow",
  "edit": { "~/.graphify/**": "deny" }
}
```

Removing a repository from disk does not remove it from the global graph; run `graphify global remove <tag>`.

## Querying the graph

The division of query paths is deliberate:

| Graph | Path | Who |
|---|---|---|
| Repository's own (`.ai/graphify-out/graph.json`) | `graphify` MCP tools (`query_graph`, `get_neighbors`, …) | Agents |
| Cross-repository global (`~/.graphify/global-graph.json`) | `graphify-global` MCP tools + `~/.graphify/global-manifest.json` | Agents |
| Either graph, by hand | Read-only CLI with explicit `--graph` | Humans only |
| Lifecycle (first indexing, refresh) | `/graphify-index` command + `graphify-init` plugin | Human and plugin only — never agents |

The read-only CLI is hand-run only. Its verbs default to `./<GRAPHIFY_OUT>/graph.json`, which resolves correctly only when `GRAPHIFY_OUT=.ai/graphify-out` is exported and you are standing at the repository root. Pass `--graph` explicitly anyway — it is the one form that works in either environment — naming the per-repo graph (`.ai/graphify-out/graph.json` from the repo root) or the global one:

```bash
graphify query "where is the session token validated" --graph .ai/graphify-out/graph.json --budget 2000
graphify path "LoginController" "TokenStore" --graph .ai/graphify-out/graph.json
graphify explain "TokenStore" --graph .ai/graphify-out/graph.json
graphify affected "TokenStore" --depth 2 --graph .ai/graphify-out/graph.json
graphify god-nodes --top 10 --graph .ai/graphify-out/graph.json
```

`query` does a token-budgeted BFS traversal (`--dfs` for depth-first, `--context` to filter edge contexts); `affected` is the reverse-traversal impact query; `god-nodes` lists the most connected hubs. The `graphify-cli` skill (`skills/graphify-cli/`) packages these conventions for agents.

## MCP server

The MCP tools are the agent path to both graphs — the repository's own and the global one. The MCP transport is an optional dependency of the CLI package, so install it explicitly:

```bash
uv tool install "graphifyy[mcp]"
# already installed via pipx:
pipx inject graphifyy mcp
```

The `pipx inject graphifyy mcp` line covers the default stdio transport only; running the server with `--transport http` additionally needs `starlette` (or reinstall with `pipx install --force "graphifyy[mcp]"`).

Then merge these entries into your user or project `opencode.jsonc` — the repository installer never does it for you:

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
      "enabled": true
    }
  }
}
```

OpenCode spawns local MCP servers with the project directory as working directory, so the relative `--graph` path of the `graphify` entry resolves to the current repository's graph; the `graphify-global` entry takes an absolute path (no `~` expansion in the command array) and works from anywhere.

**`project_path` bypasses `--graph`.** Every tool takes an optional `project_path`, and when it is present the server ignores its own `--graph` and resolves `<project_path>/<GRAPHIFY_OUT>/graph.json` from its *own* environment. Without `GRAPHIFY_OUT` exported where OpenCode launches, that lands on the non-existent `<project_path>/graphify-out/graph.json` and the tool answers that the repository has no graph — while `.ai/graphify-out/graph.json` sits right there. Export `GRAPHIFY_OUT=.ai/graphify-out` in your shell profile so the server inherits it; agents that omit `project_path` are unaffected.

Verified tools: `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`, plus three GitHub PR-impact tools (`list_prs`, `get_pr_impact`, `triage_prs`) that need a GitHub token and are unrelated to structural exploration. Every exposed tool adds its schema to each session's context; there is no per-tool allowlist flag, so enable this server only where MCP-only agents actually need it.

## Recovery

The refresher never retries within a session. Two automatic paths cover the common cases: reopening the session retries a failed refresh, and deleting `.ai/graphify-out/graph.json` while `.opencode-index-mode` is present triggers a full automatic rebuild next session. When a toast reports a failure you want fixed now, recover manually:

```bash
GRAPHIFY_OUT=.ai/graphify-out graphify extract /path/to/repo --code-only                   # full or incremental rebuild
GRAPHIFY_OUT=.ai/graphify-out graphify extract /path/to/repo --code-only --allow-partial   # only if Graphify refuses an incomplete extraction
```

(`GRAPHIFY_FORCE=1` is not the remedy for a refusal: on `extract` it only disables the incremental gate and semantic-cache reads, producing an expensive full re-scan that gets refused again. `--allow-partial` is the flag that accepts an incomplete result.)

Never reach for `graphify update` here: it ignores `.ai/` and recreates `graphify-out/` at the repository root (see the initializer section).

Run these **from the repository root**: `built_at_commit` records the HEAD of the directory graphify is invoked from, not of the target path. A wrong stamp is not fatal — the initializer sees it as stale and heals it with one extra refresh on the next session — but it costs a needless rebuild cycle. (The plugin itself always spawns Graphify with the repository as its working directory.) Ordinary deletions do not need force; shrinking rebuilds were verified to succeed without it.

Other common checks:

- Missing CLI: `uv tool install graphifyy` (or `pipx install graphifyy`).
- `--code-only` needs no API key and no network. Omitting it enables semantic LLM extraction, which does; the refresher passes it unless the repository's recorded mode is docs (see the next section).
- Everything Graphify writes for a repo lives under `.ai/graphify-out/`, so the single `.ai/graphify-out` exclude entry covers the whole working tree.
- A stray `graphify-out/` at the repository root means someone ran `graphify update`, `watch`, or an `extract` without `GRAPHIFY_OUT` by hand; delete it and rebuild with the command above.
- A `.ai/.ai/graphify-out/` tree means `GRAPHIFY_OUT` and `--out` were combined; delete it and rebuild with the variable alone.
- Stale global entry after deleting or renaming a repo: `graphify global remove <tag>`.

## Indexing documentation (opt-in)

The recommended mode is code-only: `--code-only` is pure local AST parsing, needs no credentials, and sends nothing anywhere. Graphify can additionally index documentation — Markdown, papers, images — through a semantic LLM pass. Docs mode is chosen per repository when running `/graphify-index` (the command offers `OPENCODE_GRAPHIFY_DOCS=1` / `OPENCODE_GRAPHIFY_BACKEND=<name>` as defaults for the question), recorded in `.opencode-index-mode`, and honoured by every later refresh. It needs:

1. An explicit yes to the command's docs question — the environment alone never turns docs mode on for refreshes.
2. An LLM backend Graphify can use. Without one, extract exits 1 with "no LLM API key found". Pin it (recommended — auto-detection picks the first provider whose API-key variable happens to be set, and a stray key should not decide where your corpus is sent); the chosen backend is stored in the mode file alongside the mode.

Any provider Graphify auto-detects works (Gemini, Claude, OpenAI, DeepSeek, Ollama, …). To use an OpenAI-compatible gateway — for example an OpenCode Zen model — declare a custom provider in `~/.graphify/providers.json`:

```json
{
  "opencode": {
    "base_url": "https://opencode.ai/zen/go/v1",
    "env_key": "GRAPHIFY_OPENCODE_API_KEY",
    "model_env_key": "GRAPHIFY_OPENCODE_MODEL",
    "default_model": "deepseek-v4-flash"
  }
}
```

Then export the key and, optionally, the command defaults in your shell profile (the env names are Graphify-scoped on purpose — do not export `OPENCODE_API_KEY`, which could interfere with OpenCode's own auth). `OPENCODE_GRAPHIFY_DOCS`/`BACKEND` only seed the `/graphify-index` question and the legacy-graph fallback; they never switch a refresh's mode:

```bash
export GRAPHIFY_OUT=.ai/graphify-out
export GRAPHIFY_OPENCODE_API_KEY=$(jq -r '."opencode-go".key // empty' ~/.local/share/opencode/auth.json)
export OPENCODE_GRAPHIFY_DOCS=1
export OPENCODE_GRAPHIFY_BACKEND=opencode
```

Notes:

- **Cost and latency**: semantic results are cached and gated by the same incremental manifest, so after the first full pass only changed documents trigger LLM calls. Refresh calls happen in the plugin's background extract; nothing blocks the session. Budget for the first pass: a documentation-heavy repository of ~300 files takes on the order of ten minutes, one LLM call per document chunk (a reference pass over this repository billed ~184k output tokens). Closing OpenCode cleanly mid-refresh kills the child process (the plugin tracks and terminates its extracts on exit and on SIGHUP/SIGINT/SIGTERM); the next session resumes, and the semantic cache means already-billed documents are not re-billed.
- **Model choice matters**: the semantic pass demands strict JSON. A model that drifts makes Graphify log "LLM returned invalid JSON, skipping chunk" and halve the chunk, which multiplies both time and cost. Prefer a model with reliable structured output.
- **Docs-only repositories change category**: indexed in docs mode, a Markdown-only repo yields a real graph of document nodes instead of the empty-corpus marker.
- **Security**: Graphify ignores a project-local `providers.json` unless `GRAPHIFY_ALLOW_LOCAL_PROVIDERS=1` is set — only your `~/.graphify/providers.json` is trusted by default, so a cloned repo cannot silently redirect your corpus to its own endpoint. Keep it that way.
- The recovery commands in the previous section mirror the repository's recorded mode: for a docs-mode repo the failure toast advertises the extract without `--code-only` (plus `--backend` when recorded).

## Agent behavior

The installed global rules make repository exploration graph-first when a graph exists at `.ai/graphify-out/graph.json`. Agents query the current repository through the `graphify` MCP tools and other indexed repositories through the `graphify-global` MCP tools (tie-break via `~/.graphify/global-manifest.json`), falling back directly to normal LSP/filesystem tools when the tools are unavailable; the read-only CLI is hand-run only. The MCP paths depend entirely on the `opencode.jsonc` MCP entries, which the installer never writes: until you add them yourself, agents resolve `graphify: absent` even when a healthy graph sits on disk. The reusable contract lives in the `graphify-cli` skill; lifecycle commands (`extract`, `update`, `watch`, `global add|remove`, any `install`) are off-limits to agents — first indexing belongs to the human-invoked `/graphify-index` command and refreshing to the `graphify-init` plugin. Domain-specific restrictions still win — SDD agents keep their stricter lifecycle and read-only rules. Cross-repo routing depends on the model's instruction-following: small-model agents may fall back to library-documentation tools despite the rules, so direct questions about other repositories to a frontier agent.
