# Apply Changes Without Restarting OpenCode

Validated on OpenCode 1.17.15. Model assignments and installed Markdown artifacts can reload; plugin registration and code still require a restart.

## Quick path

- Save model or variant changes through `/models-profiles`; it hot-applies when supported.
- Reinstall agents, commands, or skills with `installers/opencode.sh install --reload`.
- Restart after plugin registration or code changes, or when the tool reports fallback.

## Support matrix

| Change | Live mechanism | Restart condition |
|---|---|---|
| Global model or variant set | `PATCH /global/config` | Server failure or another OpenCode process |
| Global key removal | Local JSONC write plus a changed set leaf | Removal-only update |
| Project `opencode.json[c]` | Write then `POST /instance/dispose?directory=<dir>` | Disposal failure |
| Installed Markdown artifacts | `POST /global/dispose` through `install --reload` | Client catalog stays stale |
| Plugin registration or code | None | Always |

## Mechanism and limits

`PATCH /global/config` preserves JSONC comments, deep-merges changes, invalidates the global config cache, and disposes instances only when bytes change. It cannot delete keys, and an identical patch does not invalidate state.

`POST /instance/dispose?directory=<dir>` reloads project config for one instance. `POST /global/dispose` reloads Markdown artifacts and project config for all instances, but not hand-edited global config because that cache is separate.

Avoid instance `PATCH /config` on 1.17.15: it writes `<project>/config.json`, which the loader does not re-read.

A disposed TUI instance refreshes agents, config, and providers on its next bootstrap. A session-level `/model` choice still overrides the configured agent model until the user changes it or restarts.

## Repository behavior

The pinned `opencode-models-presets` package keeps transactional JSONC writes. Project changes dispose the target instance. Global removals are written locally, then a changed set leaf triggers `PATCH /global/config`; removal-only changes request a restart. Failure leaves the config saved and reports that restart is required.

`installers/opencode.sh install --reload` discovers healthy local servers or uses `OPENCODE_RELOAD_URLS`, then calls global disposal after a successful install. Reload is best-effort and never rolls back installation.

Only the connected server receives Models Presets hot apply. Restart any other running OpenCode process that needs the change.
