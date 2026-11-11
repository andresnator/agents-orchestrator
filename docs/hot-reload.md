# Apply Changes Without Restarting OpenCode

Validated on OpenCode 1.17.15 and not checked again on 2.x. The installer needs OpenCode 2.0.28 or later for the repository-local TUI plugin. Model assignments and Markdown artifacts can reload. Plugin registration and plugin code need a restart.

## Quick path

- Save model or variant changes through `/models-profiles`.
- Install agents, commands, or skills again with `installers/opencode.sh install --reload`.
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

`PATCH /global/config` deep-merges changes and keeps JSONC comments. It disposes instances only when the bytes change. It cannot delete keys.

`POST /global/dispose` does not reload a hand-edited global config.

Do not use instance `PATCH /config` on 1.17.15. It writes `<project>/config.json`, and the loader does not read that file again.

A session-level `/model` choice overrides the configured agent model until you change it or restart.

## Repository behavior

If a live apply fails, the config stays saved and the tool asks for a restart.

`installers/opencode.sh install --reload` finds healthy local servers or uses `OPENCODE_RELOAD_URLS`. Reload is best-effort and never rolls back the install.

Only the connected server gets the hot apply. Restart each other OpenCode process.
