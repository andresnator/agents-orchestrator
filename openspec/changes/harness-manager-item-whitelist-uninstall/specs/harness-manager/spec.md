# Harness Manager Item-Whitelist Uninstall Specification

## Purpose

Define safe item-level uninstall behavior for `scripts/harness-manager.sh` so shared target directories keep unrelated user and third-party content while this repository's currently managed installable items can be removed or backed up predictably.

## Requirements

### Requirement: Managed Item Whitelist Enumeration

The harness manager MUST compute uninstall candidates from the same managed item selection used by install/update, or from a demonstrably equivalent centralized source. Uninstall candidates MUST be item paths, not whole top-level asset directories.

The managed item whitelist MUST include only:

- `agents/primary/*.md` and `agents/subagents/*.md` installed under the target's `agents` tree;
- skill directories under `skills/*` that contain `SKILL.md`;
- command Markdown files under `commands/*.md`;
- top-level items under `recipes/*`, `scenarios/*`, and `templates/*`.

README files MUST NOT be uninstall candidates unless they are explicitly part of a whitelisted managed item other than a top-level README exclusion.

#### Scenario: Uninstall derives item-level candidates

- GIVEN the repository contains managed agents, skills, commands, recipes, scenarios, and templates
- WHEN `scripts/harness-manager.sh uninstall --target <target> --dry-run` is evaluated
- THEN the planned candidates are individual derived destination item paths
- AND the planned candidates are not the whole `<target>/agents`, `<target>/skills`, `<target>/commands`, `<target>/recipes`, `<target>/scenarios`, or `<target>/templates` directories

#### Scenario: README files are filtered from managed candidates

- GIVEN source asset directories contain `README.md` files used for repository documentation
- WHEN uninstall candidates are computed
- THEN top-level README documentation files are excluded from the managed candidate list
- AND uninstall does not plan removal or backup of target README files solely because they share an asset directory name

### Requirement: Item-Level Removal

Uninstall without `--backup` MUST remove only existing destination paths that match the managed item whitelist. Missing managed item paths MUST be reported as skipped and MUST NOT fail the uninstall solely because they are absent.

#### Scenario: Existing managed items are removed

- GIVEN a target contains destination paths corresponding to current managed whitelist items
- WHEN `scripts/harness-manager.sh uninstall --target <target>` runs without `--backup`
- THEN each existing managed destination item is removed
- AND the summary identifies removed items

#### Scenario: Missing managed items are skipped

- GIVEN a managed whitelist item does not exist in the target
- WHEN uninstall runs
- THEN that missing item is reported as skipped
- AND the run continues for remaining managed items

### Requirement: Backup Moves Only Managed Items

When `--backup` is supplied for uninstall, the harness manager MUST back up only existing destination paths that match the managed item whitelist. It MUST NOT back up whole top-level asset directories as a shortcut. Backup output MUST identify the source managed item path and backup destination path for rollback.

#### Scenario: Backup preserves rollback mapping

- GIVEN a target contains existing managed items and unrelated sibling content
- WHEN `scripts/harness-manager.sh uninstall --target <target> --backup` runs
- THEN only existing managed item paths are moved or copied to timestamped backup locations according to the script's backup model
- AND unrelated sibling content remains in the target
- AND the summary records a rollback mapping from each managed item path to its backup path

### Requirement: Dry-Run Has No Side Effects

Dry-run mode MUST report the exact managed item paths that would be removed, backed up, or skipped without removing, moving, creating, or modifying target files or backup files.

#### Scenario: Dry-run previews item-level uninstall

- GIVEN a target contains managed items and unrelated content
- WHEN `scripts/harness-manager.sh uninstall --target <target> --dry-run` runs
- THEN output lists item-level managed paths that would be removed
- AND output lists missing managed paths as skipped when applicable
- AND no target content is changed

#### Scenario: Dry-run previews backup without creating backups

- GIVEN `--backup` and `--dry-run` are both supplied
- WHEN uninstall is previewed
- THEN output lists item-level managed paths that would be backed up
- AND no backup directory or backup file is created
- AND no target content is changed

### Requirement: Preserve Unrelated Target Content

Uninstall MUST preserve files and directories that are not exact destination paths derived from the managed item whitelist, including user-authored and third-party content under shared asset parent directories.

#### Scenario: Unrelated sibling files remain after removal

- GIVEN `<target>/commands/custom.md` was not derived from this repository's managed command whitelist
- AND `<target>/commands/<managed>.md` was derived from the whitelist
- WHEN uninstall runs without backup
- THEN `<target>/commands/<managed>.md` is removed
- AND `<target>/commands/custom.md` remains unchanged

#### Scenario: Unrelated sibling directories remain after skill backup

- GIVEN `<target>/skills/third-party-skill/` is not a managed skill directory
- AND `<target>/skills/<managed-skill>/` is a managed skill directory
- WHEN uninstall runs with `--backup`
- THEN `<target>/skills/<managed-skill>/` is backed up
- AND `<target>/skills/third-party-skill/` remains unchanged

### Requirement: No Target Root or Parent Asset Directory Removal

Uninstall MUST NOT remove the configured target root. Uninstall MUST NOT require removal of shared parent asset directories, even when all managed items within a parent have been removed or backed up. Any future empty-directory cleanup MUST be separately specified and guarded.

#### Scenario: Target root is never removed

- GIVEN all managed items in a target are eligible for uninstall
- WHEN uninstall completes
- THEN the configured target root still exists

#### Scenario: Shared parent asset directories are retained

- GIVEN managed command items are removed from `<target>/commands`
- WHEN uninstall completes
- THEN `<target>/commands` remains present if it existed before uninstall
- AND the same parent-preservation rule applies to `agents`, `skills`, `recipes`, `scenarios`, and `templates`

### Requirement: Symlink-Safe Item Handling

Uninstall MUST treat each whitelisted destination path as the operation boundary whether the path is a regular file, directory, or symlink. For symlinked managed items, uninstall MUST remove or back up the symlink path itself and MUST NOT traverse the symlink to delete or move external referent content.

#### Scenario: Symlinked managed file removal does not affect referent

- GIVEN a managed destination item is a symlink to a source file outside the target
- WHEN uninstall removes that managed item
- THEN the symlink path in the target is removed
- AND the external referent file remains unchanged

#### Scenario: Symlinked managed directory backup does not traverse referent

- GIVEN a managed destination skill directory path is a symlink to a directory outside the target
- WHEN uninstall runs with `--backup`
- THEN the symlink path itself is backed up according to item-level backup behavior
- AND files in the external referent directory are not moved or deleted through traversal

### Requirement: Validation Constraints

Validation for this change MUST include shell syntax validation for `scripts/harness-manager.sh` and temporary-target smoke evidence for uninstall dry-run, removal, backup, symlink safety, unrelated-content preservation, README filtering, and target-root preservation. Validation MUST NOT depend on destructive operations against a real user agent configuration directory.

#### Scenario: Validation uses disposable targets

- GIVEN validation is executed for this change
- WHEN smoke checks exercise uninstall behavior
- THEN they use disposable temporary targets
- AND they demonstrate that unrelated content and the target root remain after uninstall

#### Scenario: Validation covers candidate filtering

- GIVEN validation is executed for this change
- WHEN dry-run or smoke output is reviewed
- THEN evidence shows whole parent asset directories are not planned as uninstall candidates
- AND README files excluded by the managed filters are not planned as uninstall candidates
