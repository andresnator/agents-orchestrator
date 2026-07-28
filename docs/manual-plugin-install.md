# Manual Plugin Installation (Without The Repo Installer)

Every plugin in this repository can be installed into OpenCode by hand, without `installers/opencode.sh`. The three runtime plugins are self-contained single files; the one TUI plugin needs three extra steps.

## Quick Start

Choose one target and create its plugin directory before running any procedure below:

```bash
TARGET="$HOME/.config/opencode"   # global; use "$PWD/.opencode" for this project only
mkdir -p "$TARGET/plugins" "$TARGET/commands"
```

## Shared Facts

- OpenCode loads runtime plugins from `{plugin,plugins}/*.{ts,js}` at the top level of its config directory: `~/.config/opencode` (global) or `./.opencode` (per project). This repo's installer uses `plugins/`; either name works for a manual install. `$TARGET` below means whichever config directory you chose.
- `@opencode-ai/plugin` is provided by OpenCode itself — runtime plugins need no `npm install`.
- Plugin code, `tui.json`, and `package.json` changes require an OpenCode restart; hot-reload does not cover them (see `docs/hot-reload.md`).
- Copy or symlink both work for runtime plugins. The repo's plugins already guard against the symlink pitfalls described in `docs/hot-reload.md` (type-only or dynamic imports), so a symlink pointing back into a checkout of this repo is fine and picks up repo updates on the next restart.
- Caution: manually placed files are foreign to the installer's manifest. A later `installers/opencode.sh install` of the same component will find the destination occupied and refuse to replace it, and `uninstall`/sync will never touch it. Pick one mechanism per file.

## `graphify-init` (runtime)

Source: `domains/common/plugins/graphify-init.ts`. Imports only Node builtins plus `@opencode-ai/plugin`. It writes per-repository graph state under `.ai/graphify-out/`, maintains the matching `.git/info/exclude` entry, and registers graphs under `~/.graphify/` unless `OPENCODE_GRAPHIFY_GLOBAL=0`.

1. Copy or symlink the single file to `$TARGET/plugins/graphify-init.ts`.
2. Install the Graphify CLI so `graphify` is on PATH: `uv tool install graphifyy` (or `pipx install graphifyy`). See `docs/graphify.md` for the full lifecycle and the warning against `graphify opencode install`.
3. Handle first indexing. The plugin is a **refresher only** — it rebuilds repositories that were already indexed and never performs the first extract, which is human-gated. Without the harness, either:
   - also copy `domains/common/commands/graphify-index.md` (equally standalone) to `$TARGET/commands/graphify-index.md` and run `/graphify-index` once per repository, or
   - run the extract by hand from the repository root and record the mode yourself:

     ```bash
     GRAPHIFY_OUT=.ai/graphify-out graphify extract . --code-only --global --as <dirname>
     printf '{"mode":"code-only"}' > .ai/graphify-out/.opencode-index-mode
     ```

     (For docs mode, drop `--code-only`, add `--backend <name>`, and record `{"mode":"docs","backend":"<name>"}`.)

Opt-outs per session: `OPENCODE_GRAPHIFY_AUTOINIT=0` disables the refresher, `OPENCODE_GRAPHIFY_GLOBAL=0` skips cross-repository global-graph registration.

## `recall-calc` (runtime)

Source: `domains/learning/plugins/recall-calc.ts`. No prerequisites and no other files.

1. Copy or symlink the single file to `$TARGET/plugins/recall-calc.ts`.

It exposes the read-only `recall_due` / `recall_schedule` tools. The learning domain's `mentor` agent consumes them for spaced-repetition date arithmetic (see `docs/learning-domain.md`), but the tools work in any session regardless of what else is installed.

## `skill-registry` (runtime)

Source: `domains/meta/plugins/skill-registry.ts`. No additional runtime prerequisites or files. Node >= 22.18 is required only by the repository's standalone test harness.

1. Copy or symlink the single file to `$TARGET/plugins/skill-registry.ts`.

On startup it scans OpenCode's standard skill locations (`~/.config/opencode/skills` plus project `.opencode/skills`, `.agents/skills`, and `skills/`) and generates `.ai/atl/skill-registry.md` in the project. It needs no harness state — though it only has something to index once skills exist in those directories, however they got there.

## `model-configurator` (TUI)

Source: `domains/meta/tui-plugins/model-configurator.tsx` plus its companion directory. This is the one plugin with real setup coupling; the steps below replicate what `installers/opencode.sh` does. Prerequisite: OpenCode >= 1.17.15.

1. Copy (do not symlink — the code resolves paths through the entrypoint's realpath) the entrypoint and its companion directory:

   ```bash
   cp domains/meta/tui-plugins/model-configurator.tsx "$TARGET/plugins/"
   mkdir -p "$TARGET/plugins/model-configurator/profiles"
   cp domains/meta/tui-plugins/model-configurator/*.{ts,tsx} "$TARGET/plugins/model-configurator/"
   cp profiles/*.json "$TARGET/plugins/model-configurator/profiles/"
   ```

   Profiles are optional: without the `profiles/` directory the wizard simply shows no Profiles rows.
2. Register the entrypoint in `$TARGET/tui.json` — the TUI loads it only through this exact path:

   ```json
   { "plugin": ["./plugins/model-configurator.tsx"] }
   ```

3. Pin the one npm dependency in `$TARGET/package.json` (comment-preserving JSONC edits need it):

   ```json
   { "dependencies": { "jsonc-parser": "3.3.1" } }
   ```

4. Restart OpenCode. The entrypoint and companion sitting inside `plugins/` are never picked up by the runtime plugin loader (it globs only top-level `*.ts`/`*.js`), so nothing double-loads.

Copies do not auto-update: re-copy after changing the plugin or `profiles/` in the repo. If the palette entry does not appear, see the `plugin_enabled` troubleshooting note in `docs/agent-models.md`.
