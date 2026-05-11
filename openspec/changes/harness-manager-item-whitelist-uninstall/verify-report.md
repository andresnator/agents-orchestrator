# Verify Report: harness-manager-item-whitelist-uninstall

## Status

**PASS with review-workload warning**

Re-verification after the parent asset-directory symlink fix confirms the prior critical blocker is resolved. When `$TARGET/commands`, `$TARGET/skills`, `$TARGET/agents`, `$TARGET/scenarios`, or `$TARGET/templates` is itself a symlink, uninstall now skips operations for that asset parent instead of removing or backing up referent contents through the symlink.

No functional blocker remains for the focused item-whitelist uninstall behavior verified here.

## Spec Coverage

| Requirement                                      | Status | Evidence                                                                                                                                                                           |
| ------------------------------------------------ | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Managed item whitelist enumeration               | PASS   | Dry-run uninstall lists managed item paths such as `$target/commands/doc.md` and missing item skips; no whole parent asset-directory candidates and no README candidates observed. |
| Item-level removal                               | PASS   | Disposable install + uninstall removed 34 managed items while preserving target root, parent directories, unrelated command file, and third-party skill.                           |
| Backup moves only managed items                  | PASS   | Disposable install + `uninstall --backup` produced 34 item-level backups and preserved unrelated sibling content.                                                                  |
| Dry-run has no side effects                      | PASS   | Dry-run install did not create target; dry-run update/uninstall reported planned/skipped item paths only.                                                                          |
| Preserve unrelated target content                | PASS   | Normal sibling content remained; parent asset-directory symlink referent content remained in removal and backup modes.                                                             |
| No target root or parent asset directory removal | PASS   | Target root and parent directories remained for normal uninstall; symlinked parent asset directories remained as symlinks.                                                         |
| Symlink-safe item handling                       | PASS   | Destination item symlinks were removed/backed up as links with referents preserved. Symlinked asset parents were skipped, preserving external referents.                           |
| Validation constraints                           | PASS   | Verification used disposable temporary targets only.                                                                                                                               |

## Task Completion Status

Tasks are marked complete in `tasks.md` and `apply-progress.md`. Re-verification confirms task 15 now covers the prior missing parent asset-directory symlink case in removal and backup modes.

## Test / Validation Commands

- `bash -n scripts/harness-manager.sh`  
  Exit: 0. Shell syntax valid.

- `scripts/harness-manager.sh --help >/tmp/hm_help.out`  
  Exit: 0. Help contains `Remove known harness item paths`.

- `tmp="$(mktemp -d)"; scripts/harness-manager.sh --mode move --target "$tmp/opencode" >/tmp/hm_invalid.out 2>/tmp/hm_invalid.err`  
  Exit: 1. Target was not created; stderr: `Error: invalid --mode 'move'; expected copy or symlink`.

- `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh --dry-run --target "$target" >/tmp/hm_dry_install.out`  
  Exit: 0. Target was not created. Filtered planned counts observed: agents 7, skills 15, commands 1, scenarios 5, templates 6. README mentions: 0.

- `target="$(mktemp -d)/opencode"; scripts/harness-manager.sh update --target "$target" --backup --dry-run >/tmp/hm_update_dry.out; scripts/harness-manager.sh uninstall --target "$target" --dry-run >/tmp/hm_uninstall_dry.out`  
  Exit: 0 / 0. Parent asset removal/backup candidates: 0. README mentions: 0. `commands/doc.md` appeared as an item-level skipped path.

- Removal preservation smoke: temp copy install, add `$target/commands/custom.md` and `$target/skills/third-party-skill`, then `scripts/harness-manager.sh uninstall --target "$target"`.  
  Exit: 0. Root yes; commands parent yes; skills parent yes; custom file yes; third-party skill yes; managed `commands/doc.md` no; managed `skills/prompt-evaluator` no; removed count 34.

- Backup preservation smoke: temp copy install, add unrelated siblings, then `scripts/harness-manager.sh uninstall --target "$target" --backup`.  
  Exit: 0. Root yes; commands parent yes; custom file yes; third-party skill yes; managed `commands/doc.md` original no; command item backup count 1; skill item backup count 1; backed-up count 34.

- Destination item symlink removal smoke: create `$target/commands/doc.md` and `$target/skills/prompt-evaluator` as symlinks to external referents, then `scripts/harness-manager.sh uninstall --target "$target"`.  
  Exit: 0. Item links removed; external doc and external skill file remained.

- Destination item symlink backup smoke: create `$target/commands/doc.md` and `$target/skills/prompt-evaluator` as symlinks to external referents, then `scripts/harness-manager.sh uninstall --target "$target" --backup`.  
  Exit: 0. Original links moved away; backup paths are symlinks; external doc and external skill file remained.

- Parent asset-directory symlink removal smoke for commands: create `$target/commands -> $external_commands`, create `$external_commands/doc.md`, then `scripts/harness-manager.sh uninstall --target "$target"`.  
  Exit: 0. `$target/commands` remained a symlink; `$external_commands/doc.md` remained; `$external_commands/custom.md` remained; one skipped parent entry recorded; no rm/mv line in output.

- Parent asset-directory symlink backup smoke for commands: create `$target/commands -> $external_commands`, create `$external_commands/doc.md`, then `scripts/harness-manager.sh uninstall --target "$target" --backup`.  
  Exit: 0. `$target/commands` remained a symlink; `$external_commands/doc.md` remained; external backup count 0; target parent backup count 0; one skipped parent entry recorded.

- Parent asset-directory symlink removal/backup smoke for skills: create `$target/skills -> $external_skills`, create `$external_skills/prompt-evaluator/SKILL.md`, then run uninstall with and without `--backup`.  
  Exit: 0 / 0. `$target/skills` remained a symlink; external skill file remained; external backup count 0 in backup mode; skipped parent entries recorded.

- Parent asset-directory symlink removal/backup smoke across `agents`, `scenarios`, and `templates`: create `$target/<asset> -> $external_<asset>` with representative managed item names, then run uninstall with and without `--backup`.  
  Exit: 0 for all. Parent symlink remained; representative external item remained; external backup count 0 in backup mode; skipped parent entries recorded.

## Strict TDD Compliance

Strict TDD is disabled in `openspec/config.yaml`; no RED/GREEN/REFACTOR evidence is required. `apply-progress.md` includes a `TDD Cycle Evidence` section stating strict TDD is disabled.

## Assertion Quality Findings

Strict TDD is inactive and no automated test files were changed. The smoke checks are behavior-focused and non-tautological: they inspect filesystem state after removal/backup/dry-run operations, including external symlink referents.

## Review Workload / PR Boundary Findings

- `tasks.md` forecast: estimated changed lines 220-340; 400-line budget risk Medium; chained PRs not recommended; chain strategy pending.
- Actual tracked diff for reviewed implementation/docs files: `docs/installation.md` 25 insertions / 24 deletions; `scripts/harness-manager.sh` 365 insertions / 364 deletions; total 390 insertions / 388 deletions across those files.
- Scope stayed inside the assigned boundary (`scripts/harness-manager.sh`, `docs/installation.md`, and OpenSpec tracking). No chained PR appears required by scope.
- **WARNING:** line churn remains much larger than the forecast because `scripts/harness-manager.sh` appears substantially reformatted. No `size:exception` is recorded. This is review-workload risk, not a functional verification blocker.

## Required Fixes / Blockers

None functionally required for the prior blocker. The parent asset-directory symlink traversal issue is fixed in the verified working tree.

Recommended before final review, if feasible: reduce unrelated formatting churn in `scripts/harness-manager.sh` or explicitly record a `size:exception`/review note explaining why the large line churn is acceptable.
