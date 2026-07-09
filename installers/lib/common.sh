# shellcheck shell=bash
# shellcheck disable=SC2034  # globals here form the cross-file installer interface
# Shared library for agents-orchestrator installers. Sourced, not executed.
#
# Each runtime installer sources this file and defines these hooks:
#   runtime_usage             print help text
#   runtime_init              resolve target roots from PROJECT_TARGET/TARGET_ARG;
#                             must set MANIFEST_ROOT (directory holding the manifest)
#   runtime_ensure_dirs M     create target directories, recording them in manifest M
#   runtime_dest TYPE NAME    set DEST_PATH for a component; empty DEST_PATH skips it
#   runtime_install_component TYPE NAME SRC DEST M
#   runtime_component_state TYPE NAME SRC DEST   print link/file state for status
#   runtime_install_global M
#   runtime_status_global     print the global-rules status row
# then calls: harness_main "$@"

MANIFEST_NAME=".agents-orchestrator-manifest"
VALID_STATUSES="backlog in-progress testing done"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIB_DIR/../.." && pwd)"

ACTION=""
DOMAIN_FILTER="all"
STATUS_FILTER="all"
PROJECT_TARGET=0
TARGET_ARG=""
DRY_RUN=0
FORCE=0
MANIFEST_ROOT=""
OLD_MANIFEST=""
DEST_PATH=""

warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

csv_contains() {
  local csv value item old_ifs
  csv="$1"
  value="$2"
  [ "$csv" = "all" ] && return 0
  old_ifs="$IFS"
  IFS=,
  for item in $csv; do
    [ "$item" = "$value" ] && { IFS="$old_ifs"; return 0; }
  done
  IFS="$old_ifs"
  return 1
}

valid_status() {
  case " $VALID_STATUSES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

validate_filters() {
  local item old_ifs domain_dir
  old_ifs="$IFS"
  if [ "$DOMAIN_FILTER" != "all" ]; then
    IFS=,
    for item in $DOMAIN_FILTER; do
      domain_dir="$REPO_ROOT/domains/$item"
      [ -d "$domain_dir" ] || die "unknown domain: $item"
    done
  fi
  if [ "$STATUS_FILTER" != "all" ]; then
    IFS=,
    for item in $STATUS_FILTER; do
      valid_status "$item" || die "unknown status: $item"
    done
  fi
  IFS="$old_ifs"
}

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

status_from_file() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ /^[[:space:]]*status:[[:space:]]*/ {
      sub(/^[[:space:]]*status:[[:space:]]*/, "")
      gsub(/["'\'']/, "")
      print
      exit
    }
  ' "$1"
}

status_allowed() {
  local status
  status="$1"
  valid_status "$status" || return 1
  csv_contains "$STATUS_FILTER" "$status"
}

skill_source_dir() {
  local file link_target
  file="$1"
  if [ -L "$file" ]; then
    link_target="$(readlink "$file")"
    case "$link_target" in
      /*) (cd -P "$link_target" && pwd -P) ;;
      *) (cd -P "$(dirname "$file")/$link_target" && pwd -P) ;;
    esac
  else
    (cd -P "$file" && pwd -P)
  fi
}

# Emits selected components as 5-column TSV: type, name, domain, status, src.
# Destination mapping is runtime-specific and happens later via runtime_dest.
discover_components() {
  local out domain domain_name type dir file name status src skill_file
  out="$1"
  : > "$out"

  for domain in "$REPO_ROOT"/domains/*; do
    [ -d "$domain" ] || continue
    domain_name="$(basename "$domain")"
    csv_contains "$DOMAIN_FILTER" "$domain_name" || continue

    for type in agents commands; do
      dir="$domain/$type"
      [ -d "$dir" ] || continue
      find "$dir" -maxdepth 1 -type f -name '*.md' | sort | while IFS= read -r file; do
        name="$(basename "$file")"
        status="-"
        src="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
        printf '%s\t%s\t%s\t%s\t%s\n' "$type" "$name" "$domain_name" "$status" "$src" >> "$out"
      done
    done

    dir="$domain/skills"
    if [ -d "$dir" ]; then
      find "$dir" -mindepth 1 -maxdepth 1 ! -type l | sort | while IFS= read -r file; do
        warn "$file: domain skill entries must be symlinks to skills/<skill>; skipped"
      done
      find "$dir" -mindepth 1 -maxdepth 1 -type l | sort | while IFS= read -r file; do
        name="$(basename "$file")"
        src="$(skill_source_dir "$file")"
        skill_file="$src/SKILL.md"
        if [ ! -f "$skill_file" ]; then
          warn "$file: skill link does not resolve to a SKILL.md; skipped"
          continue
        fi
        status="$(status_from_file "$skill_file")"
        if ! status_allowed "$status"; then
          valid_status "$status" || warn "$skill_file: missing or invalid metadata.status; skipped"
          continue
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "skills" "$name" "$domain_name" "$status" "$src" >> "$out"
      done
    fi

    dir="$domain/plugins"
    [ -d "$dir" ] || continue
    find "$dir" -type f -name '*.ts' | sort | while IFS= read -r file; do
      name="$(basename "$file")"
      src="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
      printf '%s\t%s\t%s\t%s\t%s\n' "plugins" "$name" "$domain_name" "-" "$src" >> "$out"
    done
  done
}

check_collisions() {
  local selected dup
  selected="$1"
  dup="$(awk -F '\t' '
    {
      key = $1 "\t" $2
      src = $5
      if (seen[key] != "" && seen[key] != src) {
        print key
        exit
      }
      seen[key] = src
    }
  ' "$selected")"
  [ -z "$dup" ] || die "component name collision: $dup"
}

ensure_dir() {
  local dir manifest
  dir="$1"
  manifest="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'mkdir -p %s\n' "$dir"
  else
    mkdir -p "$dir"
  fi
  printf 'dir\t%s\n' "$dir" >> "$manifest"
}

link_component() {
  local src dest manifest current
  src="$1"
  dest="$2"
  manifest="$3"

  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      printf 'link\t%s\n' "$dest" >> "$manifest"
      return 0
    fi
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" -ne 1 ]; then
      warn "$dest: exists and is not owned by this selection; skipped"
      return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'ln -sfn %s %s\n' "$src" "$dest"
      printf 'link\t%s\n' "$dest" >> "$manifest"
      return 0
    fi
    ln -sfn "$src" "$dest"
    printf 'link\t%s\n' "$dest" >> "$manifest"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'ln -s %s %s\n' "$src" "$dest"
  else
    ln -s "$src" "$dest"
  fi
  printf 'link\t%s\n' "$dest" >> "$manifest"
}

# True if the previous manifest already recorded dest as a generated file,
# i.e. this installer owns it and may overwrite it on sync.
manifest_owns_file() {
  local manifest dest
  manifest="$1"
  dest="$2"
  [ -f "$manifest" ] || return 1
  awk -F '\t' -v d="$dest" '$1 == "file" && $2 == d { found = 1; exit } END { exit found ? 0 : 1 }' "$manifest"
}

# Renders src through transform_fn and installs the result at dest as a
# regular file, honoring the same foreign-destination rules as link_component.
generate_file() {
  local src dest manifest transform_fn rendered tmp
  src="$1"
  dest="$2"
  manifest="$3"
  transform_fn="$4"

  rendered="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-render.XXXXXX")"
  "$transform_fn" "$src" > "$rendered" || { rm -f "$rendered"; die "$src: transform $transform_fn failed"; }

  if [ -L "$dest" ] || [ -d "$dest" ]; then
    if [ "$FORCE" -ne 1 ]; then
      warn "$dest: exists and is not a generated file owned by this selection; skipped"
      rm -f "$rendered"
      return 0
    fi
    if [ "$DRY_RUN" -eq 0 ]; then
      rm -rf "$dest"
    fi
  elif [ -f "$dest" ]; then
    if cmp -s "$rendered" "$dest"; then
      printf 'file\t%s\n' "$dest" >> "$manifest"
      rm -f "$rendered"
      return 0
    fi
    if ! manifest_owns_file "$OLD_MANIFEST" "$dest" && [ "$FORCE" -ne 1 ]; then
      warn "$dest: exists and is not a generated file owned by this selection; skipped"
      rm -f "$rendered"
      return 0
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'generate %s\n' "$dest"
    printf 'file\t%s\n' "$dest" >> "$manifest"
    rm -f "$rendered"
    return 0
  fi

  tmp="$(mktemp "$(dirname "$dest")/.agents-orchestrator-gen.XXXXXX")"
  cat "$rendered" > "$tmp"
  mv "$tmp" "$dest"
  printf 'file\t%s\n' "$dest" >> "$manifest"
  rm -f "$rendered"
}

link_state() {
  local src dest current
  src="$1"
  dest="$2"
  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    [ "$current" = "$src" ] && { printf 'linked'; return 0; }
    printf 'foreign'
    return 0
  fi
  [ -e "$dest" ] && { printf 'foreign'; return 0; }
  printf 'not linked'
}

# State of a generated file: compares dest against a fresh render of src.
file_state() {
  local src dest transform_fn rendered
  src="$1"
  dest="$2"
  transform_fn="$3"
  if [ -L "$dest" ]; then
    printf 'foreign'
    return 0
  fi
  if [ ! -e "$dest" ]; then
    printf 'not installed'
    return 0
  fi
  if [ ! -f "$dest" ]; then
    printf 'foreign'
    return 0
  fi
  rendered="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-render.XXXXXX")"
  "$transform_fn" "$src" > "$rendered" || { rm -f "$rendered"; die "$src: transform $transform_fn failed"; }
  if cmp -s "$rendered" "$dest"; then
    printf 'generated'
  else
    printf 'stale'
  fi
  rm -f "$rendered"
}

# Removes link/file entries present in the old manifest but absent from the
# new one. Type-guarded: a stale link is removed only if still a symlink, a
# stale file only if still a regular non-symlink file.
remove_stale() {
  local old_manifest new_manifest old_entries new_entries kind dest
  old_manifest="$1"
  new_manifest="$2"
  [ -f "$old_manifest" ] || return 0

  old_entries="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-old.XXXXXX")"
  new_entries="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-new.XXXXXX")"
  awk -F '\t' '$1 == "link" || $1 == "file"' "$old_manifest" | sort -u > "$old_entries"
  awk -F '\t' '$1 == "link" || $1 == "file"' "$new_manifest" | sort -u > "$new_entries"

  comm -23 "$old_entries" "$new_entries" | while IFS=$'\t' read -r kind dest; do
    [ -n "$dest" ] || continue
    case "$kind" in
      link)
        if [ -L "$dest" ]; then
          if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$dest"; else rm "$dest"; fi
        fi
        ;;
      file)
        if [ -f "$dest" ] && [ ! -L "$dest" ]; then
          if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$dest"; else rm "$dest"; fi
        fi
        ;;
    esac
  done

  rm -f "$old_entries" "$new_entries"
}

install_action() {
  local selected new_manifest manifest type name domain status src
  runtime_init
  selected="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-selected.XXXXXX")"
  new_manifest="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-manifest.XXXXXX")"
  : > "$new_manifest"

  manifest="$MANIFEST_ROOT/$MANIFEST_NAME"
  OLD_MANIFEST="$manifest"

  discover_components "$selected"
  check_collisions "$selected"

  runtime_ensure_dirs "$new_manifest"

  while IFS=$'\t' read -r type name domain status src; do
    DEST_PATH=""
    runtime_dest "$type" "$name"
    [ -n "$DEST_PATH" ] || continue
    runtime_install_component "$type" "$name" "$src" "$DEST_PATH" "$new_manifest"
  done < "$selected"

  runtime_install_global "$new_manifest"

  remove_stale "$manifest" "$new_manifest"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'write manifest %s\n' "$manifest"
  else
    mv "$new_manifest" "$manifest"
  fi
  rm -f "$selected" "$new_manifest"
}

uninstall_action() {
  local manifest entries dirs kind dest dir
  runtime_init
  manifest="$MANIFEST_ROOT/$MANIFEST_NAME"
  [ -f "$manifest" ] || { warn "$manifest: no manifest found"; return 0; }

  entries="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-links.XXXXXX")"
  dirs="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-dirs.XXXXXX")"
  awk -F '\t' '$1 == "link" || $1 == "file"' "$manifest" > "$entries"
  awk -F '\t' '$1 == "dir" { print $NF }' "$manifest" > "$dirs"

  while IFS=$'\t' read -r kind dest; do
    [ -n "$dest" ] || continue
    case "$kind" in
      link)
        if [ -L "$dest" ]; then
          if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$dest"; else rm "$dest"; fi
        fi
        ;;
      file)
        if [ -f "$dest" ] && [ ! -L "$dest" ]; then
          if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$dest"; else rm "$dest"; fi
        fi
        ;;
    esac
  done < "$entries"

  sort -r "$dirs" | while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    if [ -d "$dir" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then printf 'rmdir %s\n' "$dir"; else rmdir "$dir" 2>/dev/null || true; fi
    fi
  done

  if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$manifest"; else rm -f "$manifest"; fi
  rm -f "$entries" "$dirs"
}

status_action() {
  local selected type name domain status src state
  runtime_init
  selected="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-selected.XXXXXX")"
  discover_components "$selected"
  check_collisions "$selected"
  while IFS=$'\t' read -r type name domain status src; do
    DEST_PATH=""
    runtime_dest "$type" "$name"
    [ -n "$DEST_PATH" ] || continue
    state="$(runtime_component_state "$type" "$name" "$src" "$DEST_PATH")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$domain" "$type" "$name" "$status" "$state"
  done < "$selected"
  runtime_status_global
  rm -f "$selected"
}

# Default component state: symlink check. Runtimes with generated artifacts
# override this to route agents/commands through file_state.
runtime_component_state() {
  link_state "$3" "$4"
}

harness_main() {
  [ "$#" -gt 0 ] || { runtime_usage; exit 1; }
  case "$1" in
    -h|--help|help)
      runtime_usage
      exit 0
      ;;
  esac
  ACTION="$1"
  shift

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --domain) shift; [ "$#" -gt 0 ] || die "--domain requires a value"; DOMAIN_FILTER="$1" ;;
      --status) shift; [ "$#" -gt 0 ] || die "--status requires a value"; STATUS_FILTER="$1" ;;
      --project) PROJECT_TARGET=1 ;;
      --target) shift; [ "$#" -gt 0 ] || die "--target requires a value"; TARGET_ARG="$1" ;;
      --dry-run) DRY_RUN=1 ;;
      --force) FORCE=1 ;;
      -h|--help) runtime_usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  validate_filters

  case "$ACTION" in
    install) install_action ;;
    uninstall) uninstall_action ;;
    status) status_action ;;
    *) runtime_usage; die "unknown action: $ACTION" ;;
  esac
}
