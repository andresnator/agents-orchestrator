---
description: "First-time Graphify indexing with explicit human consent: asks docs vs code-only, runs the extract, and records the per-repo mode the refresher plugin will honor."
argument-hint: "[path to repo or workspace folder; defaults to the current project root]"
---
You are running `/graphify-index` with raw arguments:
`$ARGUMENTS`

Build the first Graphify code graph for one repository — or for every repository under an aggregator workspace folder — with the human deciding whether to index and in which mode. After this command succeeds, the `graphify-init` plugin refreshes the graph automatically and incrementally on later sessions; it never performs a first indexing on its own.

## Hard constraints

- Use `graphify extract` only. Never run `graphify update` or `graphify watch`: both recreate `graphify-out/` at the repo root, outside `.ai/`.
- Every `graphify` invocation (including probes) must carry the environment variable `GRAPHIFY_OUT=.ai/graphify-out`. Never use the `--out` flag: it does not combine with `GRAPHIFY_OUT` (you would get `.ai/.ai/graphify-out`) and the MCP server would stop finding the graph.
- `.ai/` is a HIDDEN directory: default file globs skip dotfiles. When checking Graphify state, list or read explicit paths (`ls -la .ai/graphify-out`, `cat .ai/graphify-out/graph.json`) or search with hidden files enabled (`rg --hidden`). Never conclude state is missing based on a dot-skipping glob.
- Refuse to index unsafe roots: the filesystem root, the home directory, or any ancestor of the home directory. Suggest opening a concrete project folder instead.
- Ask questions in chat (plain conversational messages), not through a question tool, per the repo's chat-by-default question policy.

## Workflow

1. **Resolve the target root.** Use the argument path if given, else the current project root. If the root contains a `.git` entry it is a single repository. Otherwise treat it as an aggregator workspace: discover git repositories nested up to 2 directory levels below it, skipping hidden directories, `node_modules`, and symlinked directories. List what you found and confirm the set with the human before doing anything.
2. **Check preconditions.** Run `GRAPHIFY_OUT=.ai/graphify-out graphify --version`; if the binary is missing, stop and tell the human to install it (`uv tool install graphifyy` or `pipx install graphifyy`). For each target repo, check `.ai/graphify-out/graph.json`: if a healthy graph already exists, report it and skip that repo (the plugin keeps it fresh; re-indexing is only worth it if the human explicitly wants to change mode).
3. **Ask the indexing mode** (one question in chat, covering all target repos; offer per-repo overrides only if the human asks). If `OPENCODE_GRAPHIFY_DOCS=1` is exported, mention that the human's shell defaults to docs mode — but still ask; the environment never replaces the answer:
   - **Code-only (recommended):** pure local AST extraction. Takes seconds to a couple of minutes even on large repos. No credentials, no cost.
   - **Docs + code:** also routes documentation (Markdown, PDFs, images) through an LLM backend. Takes minutes (~8 minutes on a ~300-file repo) and spends real tokens (a reference run on this repo billed ~184k output tokens). Needs a configured backend: use `OPENCODE_GRAPHIFY_BACKEND` if set, otherwise ask which backend to pass to `--backend`.
   - Either way, tell the human the first pass is the slow one: later refreshes are incremental (unchanged files are never re-parsed; unchanged docs are never re-billed) and the plugin runs them automatically.
4. **Index each repo** (from that repo's root):
   - Ensure the exclude entry: append `.ai/graphify-out` to the file returned by `git rev-parse --git-path info/exclude` (this covers linked worktrees) if the entry is not already present.
   - Persist the decision FIRST at `.ai/graphify-out/.opencode-index-mode` as one JSON line: `{"mode":"code-only"}` or `{"mode":"docs","backend":"<backend>"}` (omit `backend` if none was passed). This file is the plugin's standing consent and mode source for every future refresh and rebuild — without it the plugin will not touch the repo. Writing it before the extract means an interrupted first pass is resumed automatically (and incrementally) by the plugin next session.
   - State the expected duration for the chosen mode, then run:
     `GRAPHIFY_OUT=.ai/graphify-out graphify extract . [--code-only | --backend <backend>] --global --as <tag>`
     where `<tag>` is the repo directory basename with every character outside `[A-Za-z0-9_-]` replaced by `-`. Omit `--global --as <tag>` when `OPENCODE_GRAPHIFY_GLOBAL=0`.
5. **Report.** For each repo: node count from `graph.json`, elapsed time, and mode recorded. Remind the human that refreshes now happen automatically each session and stay in the chosen mode regardless of environment variables.
