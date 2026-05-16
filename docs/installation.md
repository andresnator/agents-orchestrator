# Harness Management

Use `scripts/harness-manager.sh` to install, update, or uninstall this Markdown-first agent harness in a local agent configuration directory. The script has no build step and only manages known repo-derived harness asset items on disk.

## Quick start

Preview the default install into `~/.config/opencode`:

```bash
scripts/harness-manager.sh --dry-run
```

Install by copying directories:

```bash
scripts/harness-manager.sh install --target ~/.config/opencode --mode copy
```

Update an existing install, backing up replaced assets first:

```bash
scripts/harness-manager.sh update --target ~/.config/opencode --backup
```

Preview an uninstall without removing anything:

```bash
scripts/harness-manager.sh uninstall --target ~/.config/opencode --dry-run
```

## Command reference

```bash
scripts/harness-manager.sh [install|update|uninstall] [--target PATH] [--mode copy|symlink] [--dry-run] [--backup] [--help]
```

If no action is passed, `install` is used so simple usage stays short.

| Action      | Purpose                                                                                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `install`   | Add harness assets to the target. Existing asset paths are skipped unless `--backup` is used.                                                                 |
| `update`    | Refresh target assets from this repository. Existing asset paths are replaced only with `--backup`; otherwise they are skipped. Missing assets are installed. |
| `uninstall` | Remove only manifest-proven installable item paths from the target. The target root and shared parent asset directories are never removed.                   |

| Option            | Purpose                                                                                   |
| ----------------- | ----------------------------------------------------------------------------------------- |
| `--target <path>` | Destination directory. Defaults to `~/.config/opencode`. Leading `~` is expanded.         |
| `--mode copy`     | Copies harness directories into the target for install/update. This is the default.       |
| `--mode symlink`  | Creates target symlinks back to this repository for install/update.                       |
| `--dry-run`       | Prints planned operations without creating, moving, copying, linking, or removing paths.  |
| `--backup`        | Moves existing target paths to timestamped sibling backups before replacement or removal. |
| `--help`          | Prints usage and exits without touching the target.                                       |

The manager manages only two top-level asset types: `agents` and `commands`.

Install and update use asset-aware filters instead of copying every Markdown file blindly:

- `agents`: installs only agent files from `primary/` and `subagents/` into a flat `agents/` target, because OpenCode derives the agent name from the Markdown file path; section READMEs are skipped.
- `commands`: installs only command Markdown files; the commands README is skipped.

Skills, recipes, scenarios, and templates are not managed by this installer. See [Installing skills separately](#installing-skills-separately) for the recommended skill-installation path.

Agent Markdown frontmatter is kept OpenCode-compatible. Repository agent templates intentionally avoid skill-only fields such as `metadata`, because OpenCode passes unsupported agent fields to the model request.

## Safety model

The script is intentionally conservative.

- If a destination path already exists and `--backup` is not set, that path is skipped.
- `update` replaces existing asset paths only when `--backup` is set. Without a backup it installs missing assets and skips existing ones.
- If `--backup` is set, the existing path is moved to a timestamped sibling backup before replacement or removal.
- `install` and `update` maintain a repo-specific manifest at `<target>/.harness-manager/agents-orchestrator-manifest.tsv` for successfully managed paths.
- `uninstall` uses that manifest as the ownership source of truth. Same relative paths are not ownership proof.
- If the manifest is missing or unreadable, uninstall preserves the target and reports that ownership could not be proven. Running `install` or `update` records missing items and adopts existing items only when they already match the requested mode; use `--backup` to replace non-matching legacy paths, or clean them up manually after review.
- Manifest entries are verified before removal or backup. Missing, unsafe, outside-target, unverifiable, or user-modified paths are skipped and reported.
- `uninstall` preserves unrelated sibling files/directories and keeps the target root plus parent asset directories (`agents` and `commands`) in place.
- Every run ends with a summary of created, copied, linked, removed, skipped, and backed-up paths.
- `--dry-run` is the recommended first step for install, update, and uninstall.

## Copy vs symlink

| Mode      | Best when                                                                           | Tradeoff                                                                                                         |
| --------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `copy`    | You want an install that survives moving or deleting this repository.               | Installed files do not update automatically when the repo changes. Run `update --backup` to refresh them safely. |
| `symlink` | You want local edits in this repo to be immediately visible to the host agent tool. | Links break if this repository moves, is renamed, or is deleted.                                                 |

Copy mode is the safer default. Symlink mode is useful for active harness development.

## Installing skills separately

Skills are not managed by `harness-manager.sh`. The manager only handles agents and commands. Install skills separately using the external skills CLI:

```bash
# Install a specific skill from a local checkout
npx skills add . --skill <skill-name>

# Install a specific skill from this repository URI
npx skills add https://github.com/andresnator/agents-orchestrator --skill <skill-name>
```

Refer to the `npx skills` documentation for all supported sources and platform-specific options. If your agent platform provides its own skill installer, follow that platform's guidance after installing the skill package.

## Validation examples

Check supported flags:

```bash
scripts/harness-manager.sh --help
```

Confirm invalid modes fail before touching the target:

```bash
scripts/harness-manager.sh --mode move
```

Preview an install into a temporary target:

```bash
target="$(mktemp -d)/opencode"
scripts/harness-manager.sh --dry-run --target "$target"
```

Run a disposable copy install:

```bash
target="$(mktemp -d)/opencode"
scripts/harness-manager.sh install --target "$target" --mode copy
test -f "$target/.harness-manager/agents-orchestrator-manifest.tsv"
```

Run a disposable symlink install:

```bash
target="$(mktemp -d)/opencode"
scripts/harness-manager.sh install --target "$target" --mode symlink
test -f "$target/.harness-manager/agents-orchestrator-manifest.tsv"
```

Preview update and uninstall operations. Dry-run uninstall uses the manifest but does not remove, back up, or rewrite anything:

```bash
target="$(mktemp -d)/opencode"
scripts/harness-manager.sh update --target "$target" --backup --dry-run
scripts/harness-manager.sh uninstall --target "$target" --dry-run
```

Confirm a same-name legacy path is preserved when no manifest exists:

```bash
target="$(mktemp -d)/opencode"
mkdir -p "$target/commands"
printf 'user owned\n' > "$target/commands/doc.md"
scripts/harness-manager.sh uninstall --target "$target"
test -f "$target/commands/doc.md"
```

Confirm mismatched manifest entries are skipped conservatively:

```bash
target="$(mktemp -d)/opencode"
scripts/harness-manager.sh install --target "$target" --mode copy
printf 'user edit\n' >> "$target/commands/doc.md"
scripts/harness-manager.sh uninstall --target "$target" --dry-run
test -f "$target/commands/doc.md"
```

This repository has no runtime application, build system, or automated test framework. Validation is script smoke checks, dry-run review, safe temporary-target checks, and documentation review.

## Rollback and uninstall

To remove installed harness assets, use the `uninstall` action. It only acts on paths recorded in this repository's target manifest and verified against their recorded copy checksum or symlink target:

```bash
scripts/harness-manager.sh uninstall --target ~/.config/opencode --dry-run
scripts/harness-manager.sh uninstall --target ~/.config/opencode
```

For a rollback-friendly uninstall, keep backups of removed item paths:

```bash
scripts/harness-manager.sh uninstall --target ~/.config/opencode --backup
```

If you used `--backup`, restore a previous item by moving the reported backup path back into place:

```bash
mv ~/.config/opencode/commands/doc.md.backup.YYYYMMDDHHMMSS ~/.config/opencode/commands/doc.md
```

Keep the installation summary from any run that uses `--backup`; the `Backed-up paths` section is the per-item rollback map.

If uninstall reports a missing manifest, no destructive action was taken. Run `install` or `update` into that target to create provenance for missing or already-matching items. Non-matching legacy paths are preserved unless you rerun with `--backup` after reviewing the planned replacements.
