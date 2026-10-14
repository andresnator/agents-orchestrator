# Apply OpenCode changes safely

The pinned plugins require OpenCode >=2.0.28 and <3. Restart after changing plugin registration or code. Do not treat legacy V1 disposal endpoints as V2 reload support.

## Quick path

- Save model/variant changes through `/models-profiles`; accept hot apply only when the connected runtime reports success.
- Reinstall changed agents, commands or skills with `installers/opencode.sh install`, then restart the session to refresh its catalog.
- `install --reload` is best-effort: on V2+ it warns that authenticated native reload is not integrated and requires restart. It never undoes a successful installation.

## Support matrix

| Change | Supported path | Limitation |
| --- | --- | --- |
| Model/variant assignments | Models Presets save and reported hot apply | Restart on fallback; other OpenCode processes may remain stale |
| Agents, commands and skills on V2 | Reinstall, then restart | Authenticated native reload integration remains unverified |
| Plugin registration or code | Reinstall, then restart | Always restart |
| Markdown-only installation on V1 | Legacy `--reload` best-effort disposal | Does not make pinned V2 plugins V1-compatible |

V2 has authenticated native reload facilities, but the end-to-end authenticated replacement has not been validated here. The installer deliberately does not call `/global/health` or `POST /global/dispose` on V2: an HTML 200 response is not health evidence, and legacy disposal is not a supported V2 contract. Unknown host versions also fall back to restart without probing.

## Legacy V1 behavior

For a V1 Markdown-only installation, `--reload` discovers local servers or uses explicit `OPENCODE_RELOAD_URLS`, requires the JSON healthy response, and attempts `POST /global/dispose`. Failure warns; installation remains saved. Legacy global disposal re-reads Markdown and project config, not plugin code or hand-edited global config.

A session-level model selection can override configured assignments. Verify the effective agent/model in a new session; a successful file write alone is not runtime proof.
