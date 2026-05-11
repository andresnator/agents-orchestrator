# Proposal: Harness Manager Item-Whitelist Uninstall

## Intent

Make `scripts/harness-manager.sh uninstall` safe for shared agent configuration directories by removing or backing up only project-managed installable item paths derived from this repository's current asset filters, instead of operating on whole top-level target asset directories.

## Scope

### In Scope

- Change the expected uninstall behavior for the harness manager.
- Define uninstall as item-aware and filter-aligned with install/update selection:
  - `agents`: managed agent files installed from `agents/primary/*.md` and `agents/subagents/*.md`, excluding READMEs.
  - `skills`: managed skill directories that contain `SKILL.md`.
  - `commands`: managed command Markdown files, excluding READMEs.
  - `recipes`, `scenarios`, `templates`: managed top-level items, excluding top-level `README.md`.
- Require `--backup` to back up only those managed item paths, not the whole target asset directory.
- Preserve unrelated user or third-party content under `$TARGET/agents`, `$TARGET/skills`, `$TARGET/commands`, `$TARGET/recipes`, `$TARGET/scenarios`, and `$TARGET/templates`.
- Update documentation and validation expectations for safe uninstall dry-runs and smoke checks.

### Out of Scope

- Implementing the behavior in this phase.
- Introducing a persistent install manifest or package database unless later design proves it is necessary.
- Changing install/update filtering semantics beyond what is required to reuse the same managed item selection for uninstall.
- Removing empty parent asset directories as a required behavior; this can be considered later only if it is proven safe.
- Deleting or backing up content that cannot be derived from current repo-managed installable item paths.

## Current Finding

Exploration found that install/update already use asset-aware filters, but uninstall currently iterates the fixed asset directory names and removes or backs up whole `$TARGET/{agents,skills,commands,recipes,scenarios,templates}` paths. In shared targets such as `~/.config/opencode`, those top-level directories can contain user-authored or third-party assets unrelated to this repository, so the current uninstall path can remove or move unrelated content.

## Desired Behavior

Uninstall should compute the same project-managed item paths that install/update would place in the target, then remove or back up only those exact target paths when present. Missing managed items should be reported as skipped. Shared parent directories should remain in place, along with any unrelated contents.

## Affected Areas

| Area                         | Impact                  | Description                                                                                                           |
| ---------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `scripts/harness-manager.sh` | Modified later          | Uninstall planning should become item-aware and reuse/centralize current installable asset filtering.                 |
| `docs/installation.md`       | Modified later          | Safety model, rollback notes, and examples should describe item-level uninstall behavior.                             |
| `README.md`                  | Possibly modified later | Installation entry-point wording may need a concise safety update if it currently implies directory-level management. |
| `openspec/config.yaml`       | Possibly modified later | Validation guidance may be refined if smoke commands or evidence expectations change.                                 |

## Risks

| Risk                                                                                            | Likelihood | Mitigation                                                                                                                        |
| ----------------------------------------------------------------------------------------------- | ---------: | --------------------------------------------------------------------------------------------------------------------------------- |
| A repo item was renamed or removed, so current filters no longer derive an older installed path |     Medium | Document that uninstall is based on current repo-managed installable paths; consider design options for legacy cleanup if needed. |
| Symlink and copy installs need consistent uninstall handling                                    |     Medium | Treat target paths uniformly: remove/back up the derived destination item path whether it is a file, directory, or symlink.       |
| Empty shared parent directories accumulate after uninstall                                      |        Low | Prefer preserving parents for safety; optional cleanup should be explicitly designed and guarded if added later.                  |
| Filter logic diverges between install/update and uninstall                                      |     Medium | Centralize path enumeration so all actions use the same managed item selection.                                                   |
| Dry-run output becomes more verbose                                                             |        Low | Keep summaries grouped and item-specific so reviewers can verify exactly what would be touched.                                   |

## Rollback Plan

If the later implementation causes regressions, restore the previous uninstall behavior in `scripts/harness-manager.sh` and revert related documentation changes. For any run made with `--backup`, restore affected managed item paths from the timestamped backup locations reported in the summary. No implementation is included in this proposal artifact.

## Success Criteria

- [ ] `uninstall --dry-run` reports only derived managed item paths, not whole `$TARGET/{agents,skills,commands,recipes,scenarios,templates}` directories.
- [ ] `uninstall` without `--backup` removes only existing managed item paths and preserves unrelated sibling content in shared target asset directories.
- [ ] `uninstall --backup` moves only existing managed item paths to timestamped backups and preserves unrelated sibling content.
- [ ] Missing managed items are reported as skipped without failing the run.
- [ ] Install/update and uninstall derive managed paths from one shared or demonstrably equivalent filter source.
- [ ] Documentation states that uninstall is item-level and recommends dry-run review before removal.
- [ ] Validation evidence includes shell syntax check plus dry-run or temporary-target smoke checks that demonstrate unrelated target content is preserved.
