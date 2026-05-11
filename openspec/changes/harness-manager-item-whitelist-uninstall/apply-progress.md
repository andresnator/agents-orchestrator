# Apply Progress: Harness Manager Item-Whitelist Uninstall

## Status

Applied focused fix for `harness-manager-item-whitelist-uninstall`.

## Completed Tasks

- 1. Established baseline: pre-change uninstall dry-run targeted six parent asset directories: `$TARGET/agents`, `$TARGET/skills`, `$TARGET/commands`, `$TARGET/recipes`, `$TARGET/scenarios`, `$TARGET/templates`.
- 2. Added Bash 3.2-compatible managed-item enumeration in `scripts/harness-manager.sh`.
- 3. Refactored install/update counting and population to reuse the centralized item selection while preserving asset-level install/update replacement semantics.
- 4. Changed uninstall to operate on exact managed destination item paths and report missing items as skipped.
- 5. Validated symlink-safe removal/backup behavior against disposable paths.
- 6. Updated help text summary for item-level uninstall.
- 7. Updated `docs/installation.md` safety model.
- 8. Updated rollback guidance to show per-item backup mappings.
- 9. Reviewed `README.md`; no installation/uninstall wording found, so left unchanged.
- 10. Reviewed `openspec/config.yaml`; validation descriptions remain accurate, so left unchanged.
- 11-16. Ran smoke validation commands listed below.
- 17. Rollback remains file-scoped to `scripts/harness-manager.sh` and `docs/installation.md`.

## Files Changed

- `scripts/harness-manager.sh`
  - Added `for_each_managed_item` callback enumerator.
  - Reused enumerator for install/update item counting and population.
  - Routed uninstall through exact managed item destinations instead of parent asset directories.
  - Kept `[[ -e "$dest" || -L "$dest" ]]` item-boundary handling and per-item backup/removal.
- `docs/installation.md`
  - Documented item-level uninstall safety model.
  - Updated rollback examples to restore per-item backups.
- `openspec/changes/harness-manager-item-whitelist-uninstall/tasks.md`
  - Marked implementation, documentation, and validation tasks complete.
- `openspec/changes/harness-manager-item-whitelist-uninstall/apply-progress.md`
  - Recorded apply and validation evidence.

## Validation Evidence

| Check                    | Command / Observation                                                                                                                                                        |  Exit | Evidence                                                                                                                                                                                                          |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----: | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Baseline                 | `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh uninstall --target "$target" --dry-run` before edits                                                             |     0 | Skipped six parent directories: `agents`, `skills`, `commands`, `recipes`, `scenarios`, `templates`.                                                                                                              |
| Syntax                   | `bash -n scripts/harness-manager.sh`                                                                                                                                         |     0 | Shell syntax valid.                                                                                                                                                                                               |
| Help                     | `scripts/harness-manager.sh --help`                                                                                                                                          |     0 | Help says uninstall removes known harness item paths.                                                                                                                                                             |
| Invalid mode             | `scripts/harness-manager.sh --mode move --target "$tmp/opencode"`                                                                                                            |     1 | Failed before target creation (`target_exists:no`).                                                                                                                                                               |
| Dry-run install          | `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh --dry-run --target "$target"`                                                                                    |     0 | Filtered counts reported: agents 7, skills 15, commands 1, scenarios 5, templates 6; recipes skipped as no installable items. No README paths shown.                                                              |
| Dry-run update/uninstall | `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh update --target "$target" --backup --dry-run; scripts/harness-manager.sh uninstall --target "$target" --dry-run` | 0 / 0 | Uninstall listed item paths like `$target/agents/*.md`, `$target/skills/*`, `$target/commands/doc.md`; no whole parent directory candidates and no README paths.                                                  |
| Removal preservation     | Disposable install, add `$target/commands/custom.md` and `$target/skills/third-party-skill`, then `scripts/harness-manager.sh uninstall --target "$target"`                  |     0 | Target root yes; commands parent yes; unrelated custom file yes; third-party skill yes; managed `commands/doc.md` removed.                                                                                        |
| Backup preservation      | Disposable install, add unrelated content, then `scripts/harness-manager.sh uninstall --target "$target" --backup`                                                           |     0 | 34 item-level `.backup.` mappings; unrelated content and parent dirs remained. Examples included `skills/prompt-evaluator -> skills/prompt-evaluator.backup.*` and `commands/doc.md -> commands/doc.md.backup.*`. |
| Symlink removal          | Managed destination symlinks for `commands/doc.md` and `skills/prompt-evaluator`, then uninstall                                                                             |     0 | Symlink paths removed; external referent file and skill directory remained.                                                                                                                                       |
| Symlink backup           | Managed destination symlinks for `commands/doc.md` and `skills/prompt-evaluator`, then `uninstall --backup`                                                                  |     0 | Backup paths are symlinks; external referent file and skill directory remained.                                                                                                                                   |

## TDD Cycle Evidence

Strict TDD is disabled in `openspec/config.yaml`; no RED/GREEN/REFACTOR table required. Validation used shell smoke checks and disposable temp targets per project config.

## Deviations From Design

- None intentional. The implementation uses a callback enumerator as designed and keeps Bash 3.2-compatible syntax.
- Install/update still perform replacement decisions at the asset parent level, preserving previous install/update semantics while sharing item filtering for counts and population.

## Remaining Tasks

- None for the approved focused fix.

## Workload / PR Boundary

Single focused PR boundary: `scripts/harness-manager.sh`, `docs/installation.md`, and OpenSpec apply tracking/task status for `harness-manager-item-whitelist-uninstall`. Estimated/reviewed scope stayed within the approved medium-risk single-PR path; no chained PR needed.
