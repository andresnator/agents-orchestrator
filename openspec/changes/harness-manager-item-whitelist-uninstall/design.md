# Design: Harness Manager Item-Whitelist Uninstall

## Technical Approach

Refactor `scripts/harness-manager.sh` around a single managed-item enumerator that derives installable source items and their destination paths. Install/update will continue to use the existing asset filters, but the filter logic should be centralized so uninstall can consume the exact same item list instead of operating on whole target asset directories.

Uninstall will iterate derived destination item paths, treating each path as the operation boundary. Existing paths are removed or backed up per item. Missing paths are skipped. Parent asset directories and the target root are preserved.

## Architecture Decisions

| Decision              | Options considered                                                                                      | Tradeoff                                                                                                                                                                                                                  | Choice                                                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Candidate source      | Current fixed `ASSETS` directory removal; persistent install manifest; derive from current repo filters | Directory removal is unsafe in shared targets. A manifest could handle removed/renamed legacy items but adds state and migration scope. Current filters match the proposal scope but cannot identify stale renamed items. | Derive uninstall candidates from current repo-managed installable items. Do not add a manifest in this change.                                |
| Filter reuse          | Duplicate uninstall filters; central enumerator; ad hoc shell glob checks per action                    | Duplicating filters risks install/uninstall drift. A central enumerator slightly reshapes install code but makes behavior auditable.                                                                                      | Add one central managed-item enumeration path used by install/update/uninstall.                                                               |
| Uninstall granularity | Whole asset parent; per asset type; per destination item                                                | Parent-level operations are unsafe. Per item is more verbose but preserves unrelated content and provides a precise rollback map.                                                                                         | Uninstall one managed destination item at a time.                                                                                             |
| Backup model          | One backup directory; timestamped sibling per item; no backup for symlinks                              | One directory changes rollback semantics. Existing script already uses timestamped sibling backups. Symlinks must be backed up as links, not dereferenced.                                                                | Reuse timestamped sibling backup behavior per managed item.                                                                                   |
| Parent cleanup        | Remove empty parent asset dirs; preserve all parents                                                    | Cleanup is convenient but risks deleting shared directories and is outside spec.                                                                                                                                          | Preserve target root and parent asset directories.                                                                                            |
| Shell compatibility   | Bash 4 associative arrays/mapfile; Bash 3.2-safe loops and indexed arrays                               | Bash 4 features simplify records but break macOS default Bash.                                                                                                                                                            | Keep Bash 3.2-compatible indexed arrays, simple `for` loops, and no `mapfile`, associative arrays, or process-substitution-dependent designs. |

## Managed-Item Enumerator

Introduce a central enumerator conceptually named `for_each_managed_item` or equivalent. It should traverse the repository asset directories and emit records containing:

| Field   | Meaning                                                                                                                       |
| ------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `asset` | Top-level asset group: `agents`, `skills`, `commands`, `recipes`, `scenarios`, or `templates`.                                |
| `src`   | Source file/directory path in the repository.                                                                                 |
| `dest`  | Exact destination file/directory path under `$TARGET`.                                                                        |
| `kind`  | Optional human-readable type such as `file`, `directory`, or `symlink-capable item`; used only for output clarity if helpful. |

Enumerator filters must mirror current install behavior:

- `agents`: enumerate `agents/primary/*.md` and `agents/subagents/*.md`, flattening to `$TARGET/agents/<basename>.md`; skip READMEs.
- `skills`: enumerate `skills/*` directories only when they contain `SKILL.md`, mapping to `$TARGET/skills/<skill-name>`.
- `commands`: enumerate `commands/*.md`, mapping to `$TARGET/commands/<basename>.md`; skip READMEs.
- `recipes`, `scenarios`, `templates`: enumerate top-level items under each source directory, mapping to the same basename under the target asset directory; skip top-level `README.md`.

The existing `count_installable_items` and `populate_*` paths should either call this enumerator or be rewritten so their filter source is demonstrably shared. The important contract is that a future filter change is made in one place and affects install/update/uninstall consistently.

## Data Flow

```text
repo root + ASSETS + TARGET
        │
        ▼
managed-item enumerator
        │ emits (asset, src, dest)
        ├───────────────┬───────────────────┐
        ▼               ▼                   ▼
install              update              uninstall
ensure parent        ensure parent        check exact dest
copy/link item       backup/replace       remove or backup exact item
        │               │                   │
        └───────────────┴─────────────── summary records
```

For uninstall, the action-specific flow is:

```text
for each managed item destination
  if dest does not exist and is not a symlink:
    record skipped "<dest> (not installed)"
  else if --backup:
    compute timestamped sibling backup path for this exact dest
    dry-run: print mv plan only
    real run: mv dest backup
    record "<dest> -> <backup>"
  else:
    dry-run: print rm plan only
    real run: rm -rf dest
    record removed item
```

## File Changes

| File                                                                  | Action                | Description                                                                                                                                  |
| --------------------------------------------------------------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/harness-manager.sh`                                          | Modify later          | Add centralized managed-item enumeration; route install/update population and uninstall through exact item paths; keep Bash 3.2-safe syntax. |
| `docs/installation.md`                                                | Modify later          | Replace directory-level uninstall wording with item-level safety model, backup rollback examples, and dry-run guidance.                      |
| `README.md`                                                           | Optional modify later | Add a concise safety note only if current installation entry-point wording still implies whole-directory management.                         |
| `openspec/config.yaml`                                                | Optional modify later | Refine validation command descriptions if smoke evidence expectations change.                                                                |
| `openspec/changes/harness-manager-item-whitelist-uninstall/design.md` | Create                | This design artifact.                                                                                                                        |

## Interfaces / Contracts

### Enumerator contract

The enumerator must produce destination paths, not parent asset directories. No emitted uninstall candidate may equal:

- `$TARGET/agents`
- `$TARGET/skills`
- `$TARGET/commands`
- `$TARGET/recipes`
- `$TARGET/scenarios`
- `$TARGET/templates`

except if a future explicitly whitelisted managed item itself has that exact path, which is out of scope for the current asset model.

### Uninstall contract

- Operates only on emitted `dest` paths.
- Uses `[[ -e "$dest" || -L "$dest" ]]` existence checks so broken symlinks are still handled.
- Uses `rm -rf "$dest"` only on exact item paths, never on target root or parent asset directories.
- Uses existing backup path generation per exact item path.
- Records skipped missing paths without failing the run.
- Keeps summary records item-specific so dry-run output is reviewable.

### Symlink contract

A destination symlink is the item. Removal deletes the link path. Backup moves the link path to the timestamped backup path. The implementation must not traverse a symlinked managed directory to delete or move referent contents.

## Bash 3.2 Compatibility

Implementation must avoid Bash features unavailable in macOS default Bash 3.2:

- no associative arrays;
- no `mapfile` / `readarray`;
- no namerefs (`local -n`);
- no `globstar` dependency;
- no reliance on empty-array expansion under `set -u` without the existing guard pattern.

Prefer callback-style enumeration or simple delimited indexed-array records. If records are serialized, paths should not be split on whitespace; pass fields as function arguments where possible.

## Documentation Update Plan

Update `docs/installation.md` to say that uninstall removes or backs up only current repo-managed installable items, not whole shared asset directories. The safety model should explicitly state that unrelated sibling files/directories under `agents`, `skills`, `commands`, `recipes`, `scenarios`, and `templates` are preserved, and that parent asset directories remain.

Update rollback examples so backup paths are per item, for example restoring a backed-up skill directory or command file rather than restoring `skills.backup.*` as a whole asset directory. Keep dry-run as the recommended first step.

## Validation Plan

Validation should use disposable targets only and record commands plus exit statuses.

| Check                       | Evidence expected                                                                                                                                               |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shell syntax                | `bash -n scripts/harness-manager.sh` succeeds.                                                                                                                  |
| Help/argument smoke         | `scripts/harness-manager.sh --help` succeeds; invalid mode still fails before target mutation.                                                                  |
| Dry-run candidate filtering | `uninstall --dry-run` output lists item paths and does not list whole parent asset directories as removal/backup candidates.                                    |
| README filtering            | Dry-run output does not include top-level README files excluded by managed filters.                                                                             |
| Removal smoke               | Temporary target with managed and unrelated sibling content: uninstall removes managed items and preserves unrelated content plus target root.                  |
| Backup smoke                | Temporary target with managed and unrelated sibling content: `uninstall --backup` moves only managed items to item-level backups and reports rollback mappings. |
| Symlink safety              | Temporary symlinked managed file/directory item: removal or backup affects the symlink path only; referent remains unchanged.                                   |
| Missing items               | Missing managed destinations are reported as skipped and do not fail the run.                                                                                   |

## Rollout

This is a local script behavior change. Roll out by implementing the central enumerator first, then switch uninstall to consume it, then update docs and run the validation plan against temporary targets. No migration is required. Users with legacy installed items that were renamed or removed from the repository may need manual cleanup because this change intentionally avoids deleting paths that cannot be derived from the current managed whitelist.

## Open Questions

None blocking. The known limitation is legacy cleanup for repo items that no longer exist in the current whitelist; that remains out of scope unless a future manifest-based uninstall is specified.
