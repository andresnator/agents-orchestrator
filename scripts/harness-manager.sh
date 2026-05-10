#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TARGET="${HOME}/.config/opencode"
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

usage() {
  cat <<'USAGE'
Usage: scripts/harness-manager.sh [action] [options]

Manage this agent harness in a local agent configuration directory.

Actions:
  install              Install harness assets. Default when no action is passed.
  update               Refresh harness assets from this repository.
  uninstall            Remove known harness assets from the target.

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

count_installable_items() {
  local asset="$1"
  local src="$2"
  local count=0
  local path role

  case "$asset" in
    agents)
      for role in primary subagents; do
        for path in "$src/$role"/*.md; do
          [[ -f "$path" ]] || continue
          is_readme_file "$path" && continue
          count=$((count + 1))
        done
      done
      ;;
    skills)
      for path in "$src"/*; do
        [[ -d "$path" ]] || continue
        [[ -f "$path/SKILL.md" ]] || continue
        count=$((count + 1))
      done
      ;;
    commands)
      for path in "$src"/*.md; do
        [[ -f "$path" ]] || continue
        is_readme_file "$path" && continue
        count=$((count + 1))
      done
      ;;
    *)
      for path in "$src"/*; do
        [[ -e "$path" || -L "$path" ]] || continue
        is_readme_file "$path" && continue
        count=$((count + 1))
      done
      ;;
  esac

  printf '%s\n' "$count"
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

populate_agents_asset() {
  local src="$1"
  local dest="$2"
  local role path name

  plan_or_run mkdir -p "$dest"
  for role in primary subagents; do
    for path in "$src/$role"/*.md; do
      [[ -f "$path" ]] || continue
      is_readme_file "$path" && continue
      name="$(basename "$path")"
      copy_or_link_item "$path" "$dest/$name"
    done
  done
}

populate_skills_asset() {
  local src="$1"
  local dest="$2"
  local path name

  plan_or_run mkdir -p "$dest"
  for path in "$src"/*; do
    [[ -d "$path" ]] || continue
    [[ -f "$path/SKILL.md" ]] || continue
    name="$(basename "$path")"
    copy_or_link_item "$path" "$dest/$name"
  done
}

populate_commands_asset() {
  local src="$1"
  local dest="$2"
  local path name

  plan_or_run mkdir -p "$dest"
  for path in "$src"/*.md; do
    [[ -f "$path" ]] || continue
    is_readme_file "$path" && continue
    name="$(basename "$path")"
    copy_or_link_item "$path" "$dest/$name"
  done
}

populate_filtered_asset() {
  local asset="$1"
  local src="$2"
  local dest="$3"
  local path name

  case "$asset" in
    agents) populate_agents_asset "$src" "$dest" ;;
    skills) populate_skills_asset "$src" "$dest" ;;
    commands) populate_commands_asset "$src" "$dest" ;;
    *)
      plan_or_run mkdir -p "$dest"
      for path in "$src"/*; do
        [[ -e "$path" || -L "$path" ]] || continue
        is_readme_file "$path" && continue
        name="$(basename "$path")"
        copy_or_link_item "$path" "$dest/$name"
      done
      ;;
  esac
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

  if [[ "$ACTION" == "install" ]]; then
    if ! prepare_install_destination "$dest"; then
      return 0
    fi
  else
    if ! prepare_update_destination "$src" "$dest"; then
      return 0
    fi
  fi

  populate_filtered_asset "$asset" "$src" "$dest"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$MODE" == "copy" ]]; then
      record copied "$src -> $dest (filtered planned; $count item(s))"
    else
      record linked "$dest -> $src (filtered planned; $count item(s))"
    fi
  else
    if [[ "$existed" -eq 0 ]]; then
      record created "$dest"
    fi
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

prepare_install_destination() {
  local dest="$1"

  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    return 0
  fi

  if [[ "$BACKUP" -ne 1 ]]; then
    record skipped "$dest (already exists; use --backup to replace)"
    return 1
  fi

  backup_existing "$dest"
  return 0
}

prepare_update_destination() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    return 0
  fi

  if [[ "$MODE" == "symlink" ]] && is_same_symlink "$dest" "$src"; then
    record skipped "$dest (already linked to $src)"
    return 1
  fi

  if [[ "$BACKUP" -ne 1 ]]; then
    record skipped "$dest (update would replace existing content; rerun with --backup)"
    return 1
  fi

  backup_existing "$dest"
  return 0
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
      install|update|uninstall)
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
      -h|--help)
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

  for asset in "${ASSETS[@]}"; do
    src="$root/$asset"
    dest="$TARGET/$asset"

    if [[ ! -d "$src" ]]; then
      record skipped "$src (source directory not present)"
      continue
    fi

    install_or_update_asset "$asset" "$src" "$dest"
  done
}

run_uninstall() {
  local asset dest

  for asset in "${ASSETS[@]}"; do
    dest="$TARGET/$asset"
    uninstall_asset "$dest"
  done
}

main() {
  parse_args "$@"

  case "$MODE" in
    copy|symlink) ;;
    *) fail "invalid --mode '$MODE'; expected copy or symlink" ;;
  esac

  TARGET="$(expand_path "$TARGET")"
  ensure_safe_target

  local root
  root="$(repo_root)"

  case "$ACTION" in
    install|update) run_install_or_update "$root" ;;
    uninstall) run_uninstall ;;
    *) fail "invalid action '$ACTION'; expected install, update, or uninstall" ;;
  esac

  summary

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
