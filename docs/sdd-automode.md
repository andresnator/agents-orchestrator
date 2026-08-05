# SDD Auto Mode (OpenCode)

Turn off tool-permission prompts for the sdd domain in one command:

```bash
scripts/sdd-automode.sh on     # zero tool-permission prompts during SDD runs
scripts/sdd-automode.sh off    # remove auto-mode overrides
scripts/sdd-automode.sh show   # per-agent state: on / custom / off
```

Options: `--dry-run` (print the resulting config, write nothing), `--project` (target `./.opencode`), `--target DIR` (explicit target), `--no-general` (`on` skips the built-in `general` agent).

Restart OpenCode sessions after `on`/`off`; the config is read at startup.

## What `on` writes

A complete `agent.<name>.permission` block in the selected target config (preferring `opencode.jsonc` when present) for every agent under `domains/sdd/agents/` plus the built-in `general` agent. Agents are discovered by glob, so new sdd agents are covered without editing the script. Every OpenCode permission key is set to `allow`, except keys the agent's repo frontmatter already sets, which are copied verbatim:

- `jd-judge-a`, `jd-judge-b`, `jd-solo`, `sdd-explore`, `sdd-verify` keep `edit`/`write: deny`.
- `sdd-proposal`, `sdd-spec`, `sdd-tasks` keep `bash: deny`.
- Every SDD agent, including the `orchestraitor` coordinator, keeps `question: deny`.
- The orchestraitor's `task` map (`"*": deny` plus the sdd subagent allowlist) is copied as-is.
- Every agent's nested `skill` map (`"*": deny` plus its per-agent allowlist) is copied as-is, like the `task` map.

Invariants:

- Workflow gates still ask when SDD runs through the SDLC POC. The `sdlc-orchestrator` primary owns kickoff, proposal/design confirmation, and judgment re-judge questions, while the `orchestraitor` returns `needs_input` receipts. This SDD-only toggle does not modify the primary's frontmatter `question: allow`; only tool-permission prompts disappear.
- `agent.<name>.model`/`variant` assignments (however they were written — the model configurator TUI or by hand), non-sdd agents, and top-level config keys are never touched (see [agent-models.md](agent-models.md)).
- Repo agent frontmatter is never modified; the toggle is user-side config only.

`off` deletes exactly those `permission` blocks (`general` included, always, even with `--no-general`) and prunes emptied objects; agents then use frontmatter plus global config. It does not restore overwritten custom blocks. Recover those from the timestamped backup described below.

## Caveats

- **`general` is global**: the built-in `general` agent runs in every OpenCode session, not just SDD, and its all-allow block applies everywhere. Use `--no-general` to skip it — but the orchestraitor delegates auxiliary chores to `general`, so some prompts may come back.
- **Two real safety relaxations**: `external_directory: allow` (file access outside the project) and `doom_loop: allow` (disables the repeated-action circuit breaker). That is what "zero prompts" costs.
- A pre-existing `permission` block on a target agent is overwritten with a warning; recover from the timestamped `opencode.json.bak.<ts>` backup.
- Config blocks for agents you have not installed are inert and harmless.
- If OpenCode adds new permission keys, update the `PERMISSION_KEYS` constant in `scripts/sdd-automode.sh` — the script's one drift point.
