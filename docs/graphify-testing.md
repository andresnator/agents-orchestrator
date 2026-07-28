# Graphify test plan — functional scenarios and regression suite

How to validate the Graphify integration end to end: two automated regression scripts plus the manual scenarios per functional area. Run the regression scripts after touching the plugin, the `/graphify-index` command, the `graphify-cli` skill, or any agent Graphify block; run the manual scenarios that match the area you changed. Status reflects the last full validation pass (2026-07-28).

## Regression (run first)

```bash
bash scripts/test-graphify-init.sh   # isolated regression cases against a real `opencode serve`
bash scripts/validate-harness.sh     # agents, commands, skills, profiles, plugins, and script syntax
```

- [ ] `test-graphify-init.sh` ends with `PASS: graphify-init consent, refresh, and notification contracts`
- [ ] `validate-harness.sh` ends with `PASS: ... deterministic contracts OK`

The suite runs hermetically (own HOME/XDG, fake `graphify` binary) and covers what manual testing should not repeat: mode-file precedence over environment variables, marker fallbacks, empty-corpus handling, lock replacement, toast queueing. Manual scenarios below cover what the suite cannot: a real TUI, a real graph, and real agent behavior.

## A. Consent and first indexing (`/graphify-index`)

| ID | Scenario | Expected | Status |
|---|---|---|---|
| A1 | Open OpenCode on a repo with no graph and no mode file | One info toast (8 s) pointing at `/graphify-index`, once per session; zero extracts, zero files written | ✅ 2026-07-28 |
| A2 | `/graphify-index`, code-only mode | Asks mode in chat; takes the lock, writes `.opencode-index-mode`, then extracts; Git-excludes `.ai/graphify-out`; builds graph; merges into the global graph under the repo tag | ✅ 2026-07-28 |
| A3 | `/graphify-index`, docs mode | States duration and token cost before running; records `{"mode":"docs","backend":"<b>"}`; docs indexed as document/concept nodes | ✅ 2026-07-28 |
| A4 | `/graphify-index` on an already-indexed repo | Reports the healthy graph and skips — no re-index without an explicit mode change | ✅ 2026-07-28 |
| A5 | `/graphify-index` on an aggregator folder with nested repos | Discovers git repos ≤2 levels deep (skips hidden dirs, `node_modules`, symlinks), lists them, confirms the set before acting | ✅ 2026-07-28 |
| A6 | `/graphify-index` on `~`, `/`, or an ancestor of `~` | Refuses and suggests a concrete project folder. The **plugin** carries no such guard — a session opened there shows at most the hint toast | ✅ 2026-07-28 |
| A7 | `/graphify-index` on a plain folder with no nested repos | Refuses with "no target repos"; the session itself shows only the hint toast | ✅ 2026-07-28 |

## B. Background refresh (plugin)

| ID | Scenario | Expected | Status |
|---|---|---|---|
| B1 | Reopen a repo whose graph matches `HEAD` | Total silence; no Graphify process spawned | ✅ 2026-07-28 |
| B2 | New commit since the graph was built | Incremental refresh with the recorded mode's flags + result toast with node count | ✅ 2026-07-28 |
| B3 | Docs-mode repo refreshed in a shell **without** docs env vars | Stays docs — mode file wins over environment | ✅ 2026-07-28 |
| B4 | Code-only repo refreshed in a shell **with** `OPENCODE_GRAPHIFY_DOCS=1` | Stays code-only — environment never decides mode | ✅ 2026-07-28 |
| B5 | Delete `graph.json` but keep `.opencode-index-mode` | Automatic rebuild next session (mode file = standing consent) | ✅ 2026-07-28 |
| B6 | `OPENCODE_GRAPHIFY_AUTOINIT=0 opencode` | Plugin does nothing: no toasts, no processes | ✅ 2026-07-28 |

## C. Toast delivery

| ID | Scenario | Expected | Status |
|---|---|---|---|
| C1 | Open an unindexed repo and touch nothing | Hint toast appears within ~10 s (fallback timer) | ✅ 2026-07-28 |
| C2 | Open an unindexed repo and type immediately | Hint arrives with the first interaction (client-event flush), before the timer | ✅ 2026-07-28 |

## D. Concurrency and shutdown

| ID | Scenario | Expected | Status |
|---|---|---|---|
| D1 | Two sessions on the same repo mid-extract | Only the lock-holding session extracts and toasts; the second stays silent | ✅ 2026-07-28 |
| D2 | Close OpenCode mid-extract (docs mode makes it visible) | Child `graphify` process dies with the server; next session resumes incrementally via the stale-lock check | ✅ 2026-07-28 |

## E. Agent query paths (local and cross-repository MCP)

| ID | Scenario | Expected | Status |
|---|---|---|---|
| E1 | Structural question in an indexed repo ("who calls X?") | Agent uses the Graphify MCP tools (`query_graph`, …) before grep/glob, then verifies call sites with filesystem tools | ✅ 2026-07-28 |
| E2 | Documentation question in a **docs-mode** repo | Agent reads `.opencode-index-mode`, sees `docs`, and queries the graph (document/concept nodes) before crawling `.md` files | ✅ 2026-07-28 |
| E3 | Documentation question in a **code-only** repo | Agent checks the literal graph path, then answers from filesystem — the graph holds no docs | ✅ 2026-07-28 |
| E4 | Exhaustive file inventory ("list ALL files of X") | Graphify as first discovery step, completeness verified with filesystem tools | ✅ 2026-07-28 |
| E5 | Question naming another indexed repo (e.g. "¿qué dice la documentación de X?" about a repo other than the cwd) | Agent reads `~/.graphify/global-manifest.json` (tie-break vs Context7/web), then answers via the `graphify-global` MCP tools (structural) or by reading files at the manifest's repo root (content) — never Context7, web search, or a clarifying question first | ✅ 2026-07-28 (orchestraitor / GPT-5.6 Sol: manifest read → `graphify-global.query_graph` → read the repo's actual `.md` files) |
| E6 | MCP tools unavailable (server removed from `opencode.jsonc`) | Agent falls back to filesystem directly — never runs `graphify query` on the local graph via bash | ✅ 2026-07-28 |

Known limitation (accepted): small-model agents (e.g. the built-in Build agent on Codex Spark) may ignore the cross-repo routing and answer from Context7/web even with `graphify-global` connected — a model instruction-following floor, not a Graphify defect. Ask cross-repo questions through a frontier agent (orchestraitor).

## F. Environment contract

| ID | Scenario | Expected | Status |
|---|---|---|---|
| F1 | Fresh shell with `export GRAPHIFY_OUT=.ai/graphify-out` (zshrc) | Hand-run CLI verbs and the MCP server's `project_path` resolution both find `.ai/graphify-out/graph.json` | ✅ 2026-07-28 |
| F2 | Any session, any repo | Agents never run lifecycle commands (`extract`, `update`, `watch`, `global add\|remove`, `install`) — standing invariant to watch in every scenario above | ✅ continuous |

## Invariants to watch in every scenario

- [ ] No `graphify-out/` directory ever appears at the repo root (only `.ai/graphify-out/`).
- [ ] No first indexing runs without `.opencode-index-mode`; a pre-existing legacy graph may refresh once from its semantic marker and then persist the mode file.
- [ ] Environment variables never change a recorded mode.
- [ ] Reinstalled prompt changes are applied with `install --reload` when available; otherwise start a new session. Plugin and TUI code changes always require a restart.

## Next step

When a scenario fails, capture the OpenCode log (`~/.local/share/opencode/log/`, timestamps in UTC) and the repo's `.ai/graphify-out/` listing before retrying — the mode file, markers, and lock file are the evidence that explains almost every behavior. Contracts live in `docs/graphify.md`; the query contract lives in `skills/graphify-cli/SKILL.md`.
