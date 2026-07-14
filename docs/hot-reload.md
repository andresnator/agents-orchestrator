# Applying Changes Without Restarting OpenCode

Status: adopted on OpenCode 1.17.15 (2026-07-14). The model-configurator wizard hot-applies model/variant writes, and `installers/opencode.sh install --reload` nudges running servers to re-read installed markdown artifacts. This document records the validated mechanism, including two corrections to the original investigation.

## Verdict

- **Viable today** for agent model/variant and other `opencode.json[c]` config changes, with one asymmetry between scopes (see below): the OpenCode server can hot-apply config without a process restart, and the wizard now does.
- **Viable today** for installed markdown artifacts (agents, commands, skills) and project config: disposing instances makes the server re-read them on the next request; `install --reload` does this for every discovered healthy server. A TUI session that already listed them may not refresh its client-side catalog until its next request.
- **Not viable** for plugin code (including TUI plugins), `tui.json`, and `package.json`: modules and plugin registration load once at process startup. Re-running `installers/opencode.sh install` plus a restart remains the only path for those.

## The Mechanism (validated empirically on 1.17.15)

- **`PATCH /global/config`** (`handlers/global.ts` → `Config.updateGlobal`): deep-merges the payload into the global `opencode.json[c]`, **preserving JSONC comments** via `patchJsonc`, and — when the on-disk bytes changed — invalidates the global config cache and **disposes all in-memory instances**. Running sessions resolve the new agent models on their next message. No restart. Two hard limits:
  - The deep-merge **cannot delete keys** (removing a `variant` or a whole agent entry); `null` is rejected by schema validation before anything is written.
  - A byte-identical merge reports success but **does not invalidate anything** — hot-apply needs at least one leaf whose value differs from what is already on disk.
- **`POST /global/dispose`** (`client.global.dispose()` in the v2 SDK; absent from the v1 SDK generation): disposes **all** instances. Their next request re-reads markdown artifacts and project `opencode.json[c]` files. **Correction to the original investigation:** it does **not** re-read the global `opencode.json[c]` — the global config is cached with an infinite TTL (`Effect.cachedInvalidateWithTTL(..., Duration.infinity)` in `Config.Service`) and only a byte-changing `PATCH /global/config` invalidates that cache. "Write the global file ourselves, then dispose" therefore does **not** work.
- **`POST /instance/dispose?directory=<dir>`** (`client.instance.dispose({ directory })` in the v2 SDK): disposes one instance without writing anything. The next request rebuilds it from the on-disk project config (still against the cached global config). This is the lever for project-scope writes.
- **`PATCH /config`** (instance-scoped, `client.config.update`): **avoid on 1.17.15.** It writes `<project>/config.json`, a file the config loader never re-reads, so the change reports success but has no effect (verified empirically).

The v1 loader has no file watcher: editing `opencode.json[c]` by hand changes nothing until the relevant invalidation above (or a restart). The dev-branch v2 adds a watcher plus a per-domain plugin reload API (`ctx.agent.reload()`, `ctx.skill.reload()`, `ctx.command.reload()`); the unmerged `EXPERIMENTAL_HOT_RELOAD` prototype (anomalyco/opencode#8751) covers markdown hot-reload until then.

### How a running TUI session picks the change up

- The TUI subscribes to server events and reacts to `server.instance.disposed` with a full `bootstrap()` (`packages/tui/src/context/sync.tsx`), re-fetching agents, config, and providers. A byte-changing `PATCH /global/config` disposes all instances, so the TUI refreshes its agent snapshot on its own — no restart, no manual step.
- The session's active model is resolved client-side (`packages/tui/src/context/local.tsx`) as: the in-memory per-agent override set by `/model` → the agent's configured model from the synced snapshot → fallbacks. The `/model` override is **not persisted** (only recents/favorites/variants are), which is why a restart always "applies" assignments: it clears the override. Consequence: if the user picked a model via `/model` for an agent in the current TUI session, that choice keeps shadowing a successfully hot-applied config assignment for that agent until they restart or pick another model.

## What Is Implemented

1. **model-configurator** (`domains/meta/tui-plugins/model-configurator/hot-apply.ts`), after the existing transactional write semantics:
   - **Client shape**: the TUI hands plugins the **v2 SDK** client (`createOpencodeClient` from `@opencode-ai/sdk/v2`, wired through `packages/tui/src/context/sdk.tsx` → `packages/tui/src/plugin/adapters.tsx`), whose generated groups take parameters directly. The bundled v1 SDK (`~/.config/opencode/node_modules/@opencode-ai/sdk`) neither generates the global group nor matches these signatures — it is not what TUI plugins receive. The v2 groups are **class instances whose methods read `this.client`**: invoke them on their receiver (`group.update(...)`); extracting a method into a variable and calling it detached throws `undefined is not an object (evaluating 'this.client')`.
   - **Project scope**: keep our comment-preserving JSONC write, then `client.instance.dispose({ directory })` for the project directory.
   - **Global scope**: removals (inherit, stale `variant` keys) are written locally first — the PATCH cannot express them — then the remaining `set` leaves go through `PATCH /global/config` via `client.global.config.update({ config })`. The byte change from those leaves triggers the cache invalidation and global disposal that also pick up the local removals. Removal-only change sets have no byte-changing leaf to ride on, so they fall back to the restart toast.
   - Every failure path degrades to the previous behavior: config written, toast says restart. A hot apply only reaches the OpenCode server process the wizard is connected to; other running OpenCode processes still need a restart, and the toast says so.
2. **Installer**: `installers/opencode.sh install --reload` POSTs `/global/dispose` to running servers after a committed install, so re-installed markdown artifacts are re-read. Servers come from `OPENCODE_RELOAD_URLS` (comma/space-separated base URLs) or from `lsof` discovery of listening `opencode` processes on localhost, each gated by a `GET /global/health` check. Best-effort: it runs after the install transaction and never fails or rolls back the install. Plugin code changes (including TUI plugins) still require a restart, and the output says so.
3. **OpenCode v2** (pending): replace the disposal nudges with `ctx.*.reload()` once the v2 plugin API ships in a stable release.

## PoC Results (isolated `opencode serve`, v1.17.15)

Scratch `XDG_*` dirs, a global `opencode.jsonc` with comments, one `poc-agent`:

1. `PATCH /global/config` flipping `poc-agent`'s model → `GET /global/config` **and** the instance `GET /config` both served the new model within ~2s, the process never restarted, and the on-disk `.jsonc` kept both comments. The merge preserved an untouched sibling `variant` key (proving deletions need the local write) and picked up prior hand-edits to the file (proving the cache reloads the whole file from disk).
2. Hand-editing the global `opencode.jsonc` was **not** picked up by `POST /global/dispose` nor by instance disposal — only a byte-changing `PATCH /global/config` reloaded it.
3. Writing a project `opencode.jsonc` override by hand changed nothing until `POST /instance/dispose?directory=<project>` → the next `GET /config` served the override.
4. A byte-identical `PATCH /global/config` reported success but invalidated nothing (a stale hand-edit stayed invisible).
5. Instance `PATCH /config` wrote `<project>/config.json` and the served config never picked it up.
