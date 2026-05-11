# Tasks: Harness Manager Item-Whitelist Uninstall

## Review Workload Forecast

| Field                   | Value       |
| ----------------------- | ----------- |
| Estimated changed lines | 220-340     |
| 400-line budget risk    | Medium      |
| Chained PRs recommended | No          |
| Suggested split         | single PR   |
| Delivery strategy       | ask-on-risk |
| Chain strategy          | pending     |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

## Implementation Tasks

- [x] 1. Establish current behavior baseline for `scripts/harness-manager.sh`.
  - Inspect `ASSETS`, `count_installable_items`, `populate_agents_asset`, `populate_skills_asset`, `populate_commands_asset`, `populate_filtered_asset`, `install_or_update_asset`, `uninstall_asset`, and `run_uninstall`.
  - Record current dry-run output for `scripts/harness-manager.sh uninstall --target "$(mktemp -d)/opencode" --dry-run` as pre-change evidence.
  - Verification: baseline shows uninstall currently targets `$TARGET/{agents,skills,commands,recipes,scenarios,templates}` parent directories.

- [x] 2. Add a Bash 3.2-compatible managed-item enumeration path in `scripts/harness-manager.sh`.
  - Create a callback-style helper such as `for_each_managed_item "$root" <callback>` or equivalent, passing `asset`, `src`, and exact `dest` as function arguments.
  - Centralize existing filters: `agents/primary/*.md`, `agents/subagents/*.md`, `skills/*` with `SKILL.md`, `commands/*.md`, and top-level `recipes/*`, `scenarios/*`, `templates/*`.
  - Preserve README exclusions and whitespace-safe quoting.
  - Avoid associative arrays, `mapfile`, namerefs, `globstar`, and unsafe empty-array expansion under `set -u`.
  - Verification: enumerator never emits `$TARGET/agents`, `$TARGET/skills`, `$TARGET/commands`, `$TARGET/recipes`, `$TARGET/scenarios`, or `$TARGET/templates` as uninstall candidates.

- [x] 3. Refactor install/update population in `scripts/harness-manager.sh` to reuse the centralized item selection.
  - Replace or adapt `count_installable_items` and `populate_filtered_asset`/`populate_*_asset` so install/update and uninstall derive candidates from the same filter source.
  - Keep current install/update user-visible semantics unless required by the shared enumerator.
  - Ensure parent asset directories are created before copying/linking item destinations.
  - Verification: install/update dry-run still reports filtered item counts and does not start installing README files.

- [x] 4. Change uninstall to operate on exact managed destination items.
  - Update `run_uninstall` to compute the repository root and iterate managed item destinations instead of iterating top-level `ASSETS` parent directories.
  - Keep `uninstall_asset` item-boundary behavior with `[[ -e "$dest" || -L "$dest" ]]`, `rm -rf "$dest"` only for exact item paths, and `backup_existing "$dest"` only for exact item paths.
  - Report missing managed destinations as skipped without failing.
  - Verification: `uninstall --dry-run` lists item paths and skipped missing items, not parent asset directories.

- [x] 5. Preserve symlink-safe uninstall and backup behavior in `scripts/harness-manager.sh`.
  - Confirm removal deletes a destination symlink path without traversing its referent.
  - Confirm `--backup` moves the symlink path itself to an item-level timestamped backup path.
  - Verification: external referent files/directories remain unchanged after removal and backup smoke checks.

- [x] 6. Review script summaries and help text in `scripts/harness-manager.sh`.
  - Update help text from directory-level wording to item-level wording if needed.
  - Ensure summary groups remain item-specific for removed, skipped, and backed-up paths.
  - Verification: `scripts/harness-manager.sh --help` describes safe item-level uninstall behavior clearly.

## Documentation Tasks

- [x] 7. Update `docs/installation.md` safety model.
  - Replace wording that says uninstall removes known harness asset directories.
  - State that uninstall removes or backs up only current repo-managed installable item paths.
  - State that unrelated sibling content and parent asset directories under `agents`, `skills`, `commands`, `recipes`, `scenarios`, and `templates` are preserved.
  - Keep dry-run review as the recommended first step.

- [x] 8. Update rollback guidance in `docs/installation.md`.
  - Change examples from whole asset directory backup/restore to per-item backup mappings.
  - Include at least one file item example and one skill directory item example if space allows.
  - Verification: rollback text matches item-level `Backed-up paths` summary output.

- [x] 9. Review `README.md` for installation/uninstall wording.
  - If it implies whole-directory uninstall or broad target ownership, update it with a concise item-level safety note.
  - If no such wording exists, leave `README.md` unchanged and mention that in verification notes.

- [x] 10. Review `openspec/config.yaml` validation descriptions.
  - Update smoke command purposes only if implementation changes evidence expectations.
  - Do not change project context or strict TDD settings unless discovered inaccurate.

## Smoke Validation Commands

- [x] 11. Run syntax and argument smoke checks.
  - `bash -n scripts/harness-manager.sh`
  - `scripts/harness-manager.sh --help`
  - `scripts/harness-manager.sh --mode move`
  - Verification: syntax/help succeed; invalid mode exits non-zero before filesystem mutation.

- [x] 12. Run dry-run install/update/uninstall checks against disposable targets.
  - `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh --dry-run --target "$target"`
  - `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh update --target "$target" --backup --dry-run; scripts/harness-manager.sh uninstall --target "$target" --dry-run`
  - Verification: uninstall dry-run lists managed item destinations, excludes README files, and does not list whole parent asset directories as removal or backup candidates.

- [x] 13. Run removal preservation smoke check against a disposable target.
  - Create a temp target, install with `scripts/harness-manager.sh install --target "$target" --mode copy`, add unrelated sibling files/directories under at least `commands/` and `skills/`, then run `scripts/harness-manager.sh uninstall --target "$target"`.
  - Verification: managed items are removed, unrelated sibling content remains, and target root plus parent asset directories remain.

- [x] 14. Run backup preservation smoke check against a disposable target.
  - Create a temp target, install managed items, add unrelated sibling content, then run `scripts/harness-manager.sh uninstall --target "$target" --backup`.
  - Verification: only managed item paths are moved to timestamped item-level backups; unrelated content remains; summary records source-to-backup mappings.

- [x] 15. Run symlink safety smoke checks against disposable paths.
  - Create external referent file/directory paths, place managed destination symlinks in a temp target, then run uninstall removal and backup modes.
  - Verification: symlink paths are removed or backed up as items, and external referents remain unchanged.

- [x] 16. Record validation evidence.
  - Capture exact commands, exit statuses, and short observations for syntax, help, invalid mode, dry-run filtering, removal, backup, symlink safety, unrelated-content preservation, README filtering, and target-root preservation.

## Rollback Boundary

- [x] 17. Keep rollback simple and file-scoped.
  - Revert `scripts/harness-manager.sh` to the previous parent-directory uninstall behavior only if the item enumerator causes regressions before release.
  - Revert `docs/installation.md`, optional `README.md`, and optional `openspec/config.yaml` wording changes together with the script change if backing out.
  - Do not perform destructive validation against real user agent configuration directories.
