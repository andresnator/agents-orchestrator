# 2026-07-07: SDD Phase Agents and `.ai/` State

## Why

SDD state was split across two local roots: `.orchestraitor/` for OpenSpec-style artifacts and `.atl/` for the generated skill registry. SDD also delegated drafting, implementation, and verification to OpenCode's generic `general` subagent, which made it impossible to set `model:` differently per phase because OpenCode supports `model:` on concrete agent frontmatter.

## What Changed

- Unified local state under `.ai/`:
  - SDD artifacts now live under `.ai/orchestrator/`.
  - The generated skill registry now lives under `.ai/atl/`.
- Added six SDD phase agents:
  - `sdd-proposal`
  - `sdd-spec`
  - `sdd-design`
  - `sdd-tasks`
  - `sdd-implement`
  - `sdd-verify`
- Expanded the `orchestraitor` task allowlist from 5 named subagents to 11 named subagents.
- Kept `general` allowlisted only for auxiliary self-contained chores.
- Added `/judgment` by renaming the untracked `/judment` command.
- Imported `skill-registry` into `skills/skill-registry/` and linked it from `domains/meta/skills/skill-registry`.
- Replaced `~/.agents/skills/skill-registry` with a symlink to this repo's `skills/skill-registry/`.

## Runtime Migrations

- `orchestraitor` migrates `.orchestraitor/` or `.orchestrator/` into `.ai/orchestrator/` at change start or resume. If both old and new roots exist, it moves only missing entries and reports conflicts.
- `skill-registry.ts` migrates `.atl/` to `.ai/atl/` when `.ai/atl/` does not already exist. If `.ai/atl/` exists, it leaves `.atl/` intact.
- The repo's local `.atl/` state was moved to `.ai/atl/`.

## What Did Not Change

- `installers/opencode.sh` was not changed; it does not reference SDD or registry state paths.
- `jd-judge-a`, `jd-judge-b`, and `jd-fix` remain the judgment-day agents. `jd-fix` now treats `.ai/orchestrator/` as the protected artifact zone.
- `sdd-draft-*` skill contracts stayed the same except for path wording from `.orchestraitor/` to `.ai/orchestrator/`.
- `FORMAT_VERSION` in the registry plugin remains `3`; registry contents do not embed `.atl` paths in the generated format.

## Out of Scope

`.ia-refactor/` is still the refactor planning state root. A future migration to `.ai/refactor/` is a separate change. (Superseded: the refactor planner rework later moved this state to `.ai/refactor-planner/changes/`; `.ia-refactor/**` is now legacy and ignored.)
