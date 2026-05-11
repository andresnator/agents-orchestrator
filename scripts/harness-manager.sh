#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TARGET="${HOME}/.config/opencode"
MANIFEST_VERSION="1"
MANIFEST_REPO="agents-orchestrator"
ACTION="install"
ACTION_SET=0
MODE="copy"
TARGET="$DEFAULT_TARGET"
DRY_RUN=0
BACKUP=0

ASSETS=(agents skills commands recipes scenarios templates)
CREATED=()
COPIED=()
LINKED=()
REMOVED=()
SKIPPED=()
BACKED_UP=()
ERRORS=()
MANIFEST_NEW_ENTRIES=()
MANIFEST_CURRENT_RELPATHS=()
MANIFEST_REMOVED_RELPATHS=()

usage() {
	cat <<'USAGE'
Usage: scripts/harness-manager.sh [action] [options]

Manage this agent harness in a local agent configuration directory.

Actions:
  install              Install harness assets. Default when no action is passed.
  update               Refresh harness assets from this repository.
  uninstall            Remove only manifest-proven harness item paths from the target.

Options:
  --target <path>       Target directory. Defaults to ~/.config/opencode
  --mode copy|symlink   Install/update by copying directories or creating symlinks. Defaults to copy
  --dry-run             Print planned operations without creating, moving, copying, linking, or removing files
  --backup              Move existing target paths to timestamped backups before replacement or removal
  -h, --help            Show this help text

Examples:
  scripts/harness-manager.sh --dry-run
  scripts/harness-manager.sh install --target ~/.agents --mode copy --backup
  scripts/harness-manager.sh update --target ~/.config/opencode --backup
  scripts/harness-manager.sh uninstall --target ~/.config/opencode --dry-run
USAGE
}

manifest_dir() {
	printf '%s/.harness-manager\n' "$TARGET"
}

manifest_path() {
	printf '%s/%s-manifest.tsv\n' "$(manifest_dir)" "$MANIFEST_REPO"
}

timestamp() {
	date +%Y%m%d%H%M%S
}

relative_path_for_dest() {
	local dest="$1"
	case "$dest" in
	"$TARGET"/*) printf '%s\n' "${dest#"$TARGET/"}" ;;
	*) return 1 ;;
	esac
}

is_valid_relative_path() {
	local rel="$1"
	[[ -n "$rel" ]] || return 1
	[[ "$rel" != /* ]] || return 1
	case "$rel" in
	.* | */.. | ../* | */../* | *$'\t'* | *$'\n'*) return 1 ;;
	esac
	return 0
}

manifest_target_path() {
	local rel="$1"
	is_valid_relative_path "$rel" || return 1
	printf '%s/%s\n' "$TARGET" "$rel"
}

manifest_field_safe() {
	local value="$1"
	case "$value" in
	*$'\t'* | *$'\n'*) return 1 ;;
	esac
	return 0
}

manifest_current_has_relpath() {
	local needle="$1"
	local rel
	set +u
	for rel in "${MANIFEST_CURRENT_RELPATHS[@]}"; do
		if [[ "$rel" == "$needle" ]]; then
			set -u
			return 0
		fi
	done
	set -u
	return 1
}

manifest_removed_has_relpath() {
	local needle="$1"
	local rel
	set +u
	for rel in "${MANIFEST_REMOVED_RELPATHS[@]}"; do
		if [[ "$rel" == "$needle" ]]; then
			set -u
			return 0
		fi
	done
	set -u
	return 1
}

manifest_record_current_relpath() {
	local asset="$1"
	local src="$2"
	local dest="$3"
	local rel
	if rel="$(relative_path_for_dest "$dest")" && is_valid_relative_path "$rel"; then
		MANIFEST_CURRENT_RELPATHS+=("$rel")
	fi
}

copy_evidence() {
	local path="$1"
	local checksum unused

	if ! command -v shasum >/dev/null 2>&1; then
		printf 'unverifiable:no-shasum\n'
		return 0
	fi

	if [[ -f "$path" ]]; then
		read -r checksum unused < <(shasum -a 256 "$path")
		printf 'sha256:file:%s\n' "$checksum"
		return 0
	fi

	if [[ -d "$path" ]]; then
		read -r checksum unused < <(
			cd "$path" && find . -type f -print | LC_ALL=C sort | while IFS= read -r item; do
				shasum -a 256 "$item"
			done | shasum -a 256
		)
		printf 'sha256:dir:%s\n' "$checksum"
		return 0
	fi

	printf 'unverifiable:unsupported-type\n'
}

evidence_for_path() {
	local mode="$1"
	local path="$2"

	if [[ "$mode" == "symlink" ]]; then
		[[ -L "$path" ]] || return 1
		readlink "$path"
		return 0
	fi

	[[ ! -L "$path" ]] || return 1
	copy_evidence "$path"
}

verify_manifest_entry() {
	local mode="$1"
	local dest="$2"
	local evidence="$3"
	local current

	if [[ ! -e "$dest" && ! -L "$dest" ]]; then
		return 2
	fi

	if [[ "$mode" == "symlink" ]]; then
		[[ -L "$dest" ]] || return 3
		current="$(readlink "$dest")"
		[[ "$current" == "$evidence" ]] || return 3
		return 0
	fi

	[[ "$mode" == "copy" ]] || return 3
	[[ ! -L "$dest" ]] || return 3
	case "$evidence" in
	unverifiable:*) return 3 ;;
	esac
	current="$(copy_evidence "$dest")"
	[[ "$current" == "$evidence" ]] || return 3
}

record_manifest_entry() {
	local asset="$1"
	local src="$2"
	local dest="$3"
	local rel evidence installed_at entry

	rel="$(relative_path_for_dest "$dest")" || {
		record skipped "$dest (manifest skipped: outside target)"
		return 0
	}
	is_valid_relative_path "$rel" || {
		record skipped "$dest (manifest skipped: unsafe relative path)"
		return 0
	}
	manifest_field_safe "$asset" && manifest_field_safe "$MODE" && manifest_field_safe "$rel" && manifest_field_safe "$src" || {
		record skipped "$dest (manifest skipped: unsupported tab/newline in path)"
		return 0
	}

	evidence="$(evidence_for_path "$MODE" "$dest")" || {
		record skipped "$dest (manifest skipped: evidence unavailable)"
		return 0
	}
	installed_at="$(timestamp)"
	printf -v entry '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$MANIFEST_VERSION" "$asset" "$MODE" "$rel" "$src" "$evidence" "$installed_at"
	MANIFEST_NEW_ENTRIES+=("$entry")
}

rewrite_manifest() {
	local manifest dir tmp line version asset mode rel src evidence installed_at
	manifest="$(manifest_path)"
	dir="$(manifest_dir)"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		printf '[dry-run] update manifest %s\n' "$manifest"
		return 0
	fi

	mkdir -p "$dir"
	tmp="${manifest}.tmp.$$"
	: >"$tmp"

	if [[ -f "$manifest" ]]; then
		while IFS=$'\t' read -r version asset mode rel src evidence installed_at; do
			[[ -n "${version:-}" ]] || continue
			manifest_current_has_relpath "$rel" && continue
			manifest_removed_has_relpath "$rel" && continue
			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$version" "$asset" "$mode" "$rel" "$src" "$evidence" "$installed_at" >>"$tmp"
		done <"$manifest"
	fi

	set +u
	for line in "${MANIFEST_NEW_ENTRIES[@]}"; do
		printf '%s\n' "$line" >>"$tmp"
	done
	set -u

	mv "$tmp" "$manifest"
}

fail() {
	printf 'Error: %s\n' "$1" >&2
	exit 1
}

expand_path() {
	case "$1" in
	'~') printf '%s\n' "$HOME" ;;
	'~/'*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
	*) printf '%s\n' "$1" ;;
	esac
}

repo_root() {
	local script_dir
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	cd "$script_dir/.." && pwd
}

plan_or_run() {
	if [[ "$DRY_RUN" -eq 1 ]]; then
		printf '[dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

record() {
	local bucket="$1"
	local value="$2"

	case "$bucket" in
	created) CREATED+=("$value") ;;
	copied) COPIED+=("$value") ;;
	linked) LINKED+=("$value") ;;
	removed) REMOVED+=("$value") ;;
	skipped) SKIPPED+=("$value") ;;
	backed_up) BACKED_UP+=("$value") ;;
	errors) ERRORS+=("$value") ;;
	esac
}

backup_path() {
	local dest="$1"
	local stamp
	stamp="$(date +%Y%m%d%H%M%S)"
	local candidate="${dest}.backup.${stamp}"
	local index=1

	while [[ -e "$candidate" || -L "$candidate" ]]; do
		candidate="${dest}.backup.${stamp}.${index}"
		index=$((index + 1))
	done

	printf '%s\n' "$candidate"
}

is_same_symlink() {
	local dest="$1"
	local src="$2"

	[[ -L "$dest" ]] || return 1
	[[ "$(readlink "$dest")" == "$src" ]]
}

is_readme_file() {
	[[ "$(basename "$1")" == "README.md" ]]
}

for_each_managed_item() {
	local root="$1"
	local target="$2"
	local callback="$3"
	local asset_filter="${4:-}"
	local asset src path role name

	asset="agents"
	if [[ -z "$asset_filter" || "$asset_filter" == "$asset" ]]; then
		src="$root/$asset"
		if [[ -d "$src" ]]; then
			for role in primary subagents; do
				for path in "$src/$role"/*.md; do
					[[ -f "$path" ]] || continue
					is_readme_file "$path" && continue
					name="$(basename "$path")"
					"$callback" "$asset" "$path" "$target/$asset/$name"
				done
			done
		fi
	fi

	asset="skills"
	if [[ -z "$asset_filter" || "$asset_filter" == "$asset" ]]; then
		src="$root/$asset"
		if [[ -d "$src" ]]; then
			for path in "$src"/*; do
				[[ -d "$path" ]] || continue
				[[ -f "$path/SKILL.md" ]] || continue
				name="$(basename "$path")"
				"$callback" "$asset" "$path" "$target/$asset/$name"
			done
		fi
	fi

	asset="commands"
	if [[ -z "$asset_filter" || "$asset_filter" == "$asset" ]]; then
		src="$root/$asset"
		if [[ -d "$src" ]]; then
			for path in "$src"/*.md; do
				[[ -f "$path" ]] || continue
				is_readme_file "$path" && continue
				name="$(basename "$path")"
				"$callback" "$asset" "$path" "$target/$asset/$name"
			done
		fi
	fi

	for asset in recipes scenarios templates; do
		if [[ -n "$asset_filter" && "$asset_filter" != "$asset" ]]; then
			continue
		fi
		src="$root/$asset"
		[[ -d "$src" ]] || continue
		for path in "$src"/*; do
			[[ -e "$path" || -L "$path" ]] || continue
			is_readme_file "$path" && continue
			name="$(basename "$path")"
			"$callback" "$asset" "$path" "$target/$asset/$name"
		done
	done
}

COUNT_INSTALLABLE_ITEMS=0

count_managed_item() {
	COUNT_INSTALLABLE_ITEMS=$((COUNT_INSTALLABLE_ITEMS + 1))
}

count_installable_items() {
	local asset="$1"
	local src="$2"
	local root
	root="$(dirname "$src")"

	COUNT_INSTALLABLE_ITEMS=0
	for_each_managed_item "$root" "$TARGET" count_managed_item "$asset"
	printf '%s\n' "$COUNT_INSTALLABLE_ITEMS"
}

copy_or_link_item() {
	local src="$1"
	local dest="$2"

	if [[ "$MODE" == "copy" ]]; then
		plan_or_run cp -R "$src" "$dest"
	else
		plan_or_run ln -s "$src" "$dest"
	fi
}

existing_item_matches_desired_state() {
	local src="$1"
	local dest="$2"
	local src_evidence dest_evidence

	if [[ "$MODE" == "symlink" ]]; then
		is_same_symlink "$dest" "$src"
		return $?
	fi

	[[ -e "$dest" && ! -L "$dest" ]] || return 1
	src_evidence="$(copy_evidence "$src")"
	dest_evidence="$(copy_evidence "$dest")"
	case "$src_evidence" in
	unverifiable:*) return 1 ;;
	esac
	[[ "$src_evidence" == "$dest_evidence" ]]
}

prepare_asset_container() {
	local dest="$1"

	if [[ ! -e "$dest" && ! -L "$dest" ]]; then
		plan_or_run mkdir -p "$dest"
		if [[ "$DRY_RUN" -eq 0 ]]; then
			record created "$dest"
		fi
		return 0
	fi

	if [[ -d "$dest" && ! -L "$dest" ]]; then
		return 0
	fi

	if [[ "$BACKUP" -ne 1 ]]; then
		record skipped "$dest (asset container exists but is not a directory; use --backup to replace)"
		return 1
	fi

	backup_existing "$dest"
	plan_or_run mkdir -p "$dest"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		record created "$dest"
	fi
	return 0
}

prepare_item_destination() {
	local src="$1"
	local dest="$2"

	if [[ ! -e "$dest" && ! -L "$dest" ]]; then
		return 0
	fi

	if existing_item_matches_desired_state "$src" "$dest"; then
		if [[ "$DRY_RUN" -eq 1 ]]; then
			record skipped "$dest (already matches $MODE install; manifest write planned)"
		else
			record_manifest_entry "${CURRENT_ASSET:?}" "$src" "$dest"
			record skipped "$dest (already matches $MODE install; manifest recorded)"
		fi
		return 1
	fi

	if [[ "$BACKUP" -ne 1 ]]; then
		if [[ "$ACTION" == "install" ]]; then
			record skipped "$dest (already exists; use --backup to replace)"
		else
			record skipped "$dest (update would replace existing content; rerun with --backup)"
		fi
		return 1
	fi

	backup_existing "$dest"
	return 0
}

populate_managed_item() {
	local asset="$1"
	local src="$2"
	local dest="$3"

	if ! prepare_item_destination "$src" "$dest"; then
		return 0
	fi

	copy_or_link_item "$src" "$dest"
	if [[ "$DRY_RUN" -eq 1 ]]; then
		record skipped "$dest (manifest write planned)"
	else
		record_manifest_entry "$asset" "$src" "$dest"
	fi
}

populate_filtered_asset() {
	local asset="$1"
	local src="$2"
	local dest="$3"
	local root
	root="$(dirname "$src")"

	CURRENT_ASSET="$asset"
	for_each_managed_item "$root" "$TARGET" populate_managed_item "$asset"
	CURRENT_ASSET=""
}

install_or_update_asset() {
	local asset="$1"
	local src="$2"
	local dest="$3"
	local count existed=0

	count="$(count_installable_items "$asset" "$src")"
	if [[ "$count" -eq 0 ]]; then
		record skipped "$src (no installable items)"
		return 0
	fi

	if [[ -e "$dest" || -L "$dest" ]]; then
		existed=1
	fi

	if ! prepare_asset_container "$dest"; then
		return 0
	fi

	populate_filtered_asset "$asset" "$src" "$dest"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		if [[ "$MODE" == "copy" ]]; then
			record copied "$src -> $dest (filtered planned; $count item(s))"
		else
			record linked "$dest -> $src (filtered planned; $count item(s))"
		fi
	else
		if [[ "$MODE" == "copy" ]]; then
			record copied "$src -> $dest (filtered; $count item(s))"
		else
			record linked "$dest -> $src (filtered; $count item(s))"
		fi
	fi
}

backup_existing() {
	local dest="$1"
	local backup
	backup="$(backup_path "$dest")"

	plan_or_run mv "$dest" "$backup"
	record backed_up "$dest -> $backup"
}

uninstall_asset() {
	local dest="$1"

	if [[ ! -e "$dest" && ! -L "$dest" ]]; then
		record skipped "$dest (not installed)"
		return 0
	fi

	if [[ "$BACKUP" -eq 1 ]]; then
		backup_existing "$dest"
	else
		plan_or_run rm -rf "$dest"
		if [[ "$DRY_RUN" -eq 1 ]]; then
			record removed "$dest (planned)"
		else
			record removed "$dest"
		fi
	fi
}

print_group() {
	local title="$1"
	shift
	local items=("$@")

	printf '\n%s (%d)\n' "$title" "${#items[@]}"
	if [[ ${#items[@]} -eq 0 ]]; then
		printf '  - none\n'
		return 0
	fi

	local item
	for item in "${items[@]}"; do
		printf '  - %s\n' "$item"
	done
}

summary() {
	printf '\nHarness manager summary\n'
	printf 'Action: %s\n' "$ACTION"
	printf 'Target: %s\n' "$TARGET"
	printf 'Mode: %s\n' "$MODE"
	if [[ "$DRY_RUN" -eq 1 ]]; then
		printf 'Dry run: yes; no filesystem changes were made.\n'
	else
		printf 'Dry run: no\n'
	fi

	# macOS ships Bash 3.2, where expanding an empty array under `set -u`
	# can be treated as an unbound variable. Disable nounset only while
	# rendering summary groups so zero-count groups remain safe and explicit.
	set +u
	print_group 'Created paths' "${CREATED[@]}"
	print_group 'Copied paths' "${COPIED[@]}"
	print_group 'Linked paths' "${LINKED[@]}"
	print_group 'Removed paths' "${REMOVED[@]}"
	print_group 'Backed-up paths' "${BACKED_UP[@]}"
	print_group 'Skipped paths' "${SKIPPED[@]}"
	print_group 'Errors' "${ERRORS[@]}"
	set -u
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		install | update | uninstall)
			[[ "$ACTION_SET" -eq 0 ]] || fail "multiple actions provided: $ACTION and $1"
			ACTION="$1"
			ACTION_SET=1
			shift
			;;
		--target)
			[[ $# -ge 2 ]] || fail '--target requires a path'
			TARGET="$2"
			shift 2
			;;
		--mode)
			[[ $# -ge 2 ]] || fail '--mode requires copy or symlink'
			MODE="$2"
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--backup)
			BACKUP=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			fail "unknown option or action: $1"
			;;
		esac
	done
}

ensure_safe_target() {
	[[ -n "$TARGET" ]] || fail 'target cannot be empty'
	[[ "$TARGET" != "/" ]] || fail 'target cannot be the filesystem root'
}

ensure_target_root() {
	local target_exists=0
	if [[ -e "$TARGET" || -L "$TARGET" ]]; then
		target_exists=1
	fi

	if [[ "$DRY_RUN" -eq 1 ]]; then
		printf '[dry-run] mkdir -p %s\n' "$TARGET"
	else
		mkdir -p "$TARGET"
		if [[ "$target_exists" -eq 0 ]]; then
			record created "$TARGET"
		fi
	fi
}

run_install_or_update() {
	local root="$1"
	local asset src dest

	ensure_target_root
	for_each_managed_item "$root" "$TARGET" manifest_record_current_relpath

	for asset in "${ASSETS[@]}"; do
		src="$root/$asset"
		dest="$TARGET/$asset"

		if [[ ! -d "$src" ]]; then
			record skipped "$src (source directory not present)"
			continue
		fi

		install_or_update_asset "$asset" "$src" "$dest"
	done

	if [[ "$DRY_RUN" -ne 1 ]]; then
		rewrite_manifest
	else
		record skipped "$(manifest_path) (manifest update planned; dry-run preserved filesystem)"
	fi
}

uninstall_manifest_entry() {
	local version="$1"
	local asset="$2"
	local mode="$3"
	local rel="$4"
	local src="$5"
	local evidence="$6"
	local installed_at="$7"
	local dest parent verify_status

	if [[ "$version" != "$MANIFEST_VERSION" ]]; then
		record skipped "$rel (manifest version $version unsupported)"
		return 0
	fi

	if ! dest="$(manifest_target_path "$rel")"; then
		record skipped "$rel (manifest entry rejected: unsafe or outside target)"
		return 0
	fi

	parent="$(dirname "$dest")"
	if [[ -L "$parent" ]]; then
		record skipped "$parent (asset directory is a symlink; preserved to avoid traversing external content)"
		return 0
	fi

	if verify_manifest_entry "$mode" "$dest" "$evidence"; then
		:
	else
		verify_status=$?
		case "$verify_status" in
		2)
			record skipped "$dest (manifest entry stale: target path missing)"
			return 0
			;;
		*)
			record skipped "$dest (manifest evidence mismatch; preserved)"
			return 0
			;;
		esac
	fi

	uninstall_asset "$dest"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		MANIFEST_REMOVED_RELPATHS+=("$rel")
	fi
}

run_uninstall() {
	local manifest version asset mode rel src evidence installed_at extra line_count=0
	manifest="$(manifest_path)"

	if [[ ! -f "$manifest" || ! -r "$manifest" ]]; then
		record skipped "$manifest (missing or unreadable; ownership could not be proven, so uninstall preserved target. Re-run install/update to adopt or clean up manually.)"
		return 0
	fi

	while IFS=$'\t' read -r version asset mode rel src evidence installed_at extra; do
		[[ -n "${version:-}" ]] || continue
		line_count=$((line_count + 1))
		if [[ -n "${extra:-}" ]]; then
			record skipped "$manifest line $line_count (invalid manifest entry: too many fields)"
			continue
		fi
		uninstall_manifest_entry "$version" "$asset" "$mode" "$rel" "$src" "$evidence" "$installed_at"
	done <"$manifest"

	if [[ "$DRY_RUN" -eq 0 ]]; then
		rewrite_manifest
	fi
}

main() {
	parse_args "$@"

	case "$MODE" in
	copy | symlink) ;;
	*) fail "invalid --mode '$MODE'; expected copy or symlink" ;;
	esac

	TARGET="$(expand_path "$TARGET")"
	ensure_safe_target

	local root
	root="$(repo_root)"

	case "$ACTION" in
	install | update) run_install_or_update "$root" ;;
	uninstall) run_uninstall "$root" ;;
	*) fail "invalid action '$ACTION'; expected install, update, or uninstall" ;;
	esac

	summary

	if [[ ${#ERRORS[@]} -gt 0 ]]; then
		exit 1
	fi
}

main "$@"
