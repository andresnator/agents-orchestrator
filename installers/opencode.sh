#!/usr/bin/env bash
set -euo pipefail

MANIFEST_NAME=".agents-orchestrator-manifest"
VALID_STATUSES="backlog in-progress testing done"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ACTION=""
DOMAIN_FILTER="all"
STATUS_FILTER="all"
PROJECT_TARGET=0
TARGET_ARG=""
DRY_RUN=0
FORCE=0

warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  opencode.sh <install|uninstall|status> [--domain d1,d2] [--status s1,s2]
              [--project] [--target DIR] [--dry-run] [--force]

Actions:
  install     Sync selected domain components into an OpenCode target as symlinks.
  uninstall   Remove symlinks recorded in the target manifest, then remove the manifest.
  status      List selected components and whether each target link is linked, not linked, or foreign.

Targets:
  default      ~/.config/opencode
  --project   ./.opencode from the current working directory
  --target    Explicit alternate target, useful for tests and scratch installs

Filters:
  --domain    Comma-separated domains, or all.
              Current domains: common, docs, meta, refactor, sdd.
              Domain skills are symlinks to the top-level skills/ directory.
  --status    Comma-separated skill lifecycle states, or all.
              Valid statuses: backlog, in-progress, testing, done.
              Agents, commands, and plugins are not status-filtered because
              OpenCode frontmatter for executable components cannot carry
              repository-only metadata.

Defaults:
  --domain all
  --status all

Options:
  --dry-run   Print planned mkdir/link/rm/manifest actions without changing files.
  --force     Replace an existing non-matching destination symlink/file during install.
  -h, --help  Show this help.

Examples:
  installers/opencode.sh install
      Install every domain and every lifecycle state into ~/.config/opencode.

  installers/opencode.sh install --project
      Install into ./.opencode for the current project.

  installers/opencode.sh install --domain refactor --status done,testing
      Install only done/testing refactor components.

  installers/opencode.sh install --domain sdd,common --target /tmp/opencode-test --dry-run
      Preview a scratch install for selected domains.

  installers/opencode.sh status --domain meta
      Show meta components and link state in the default target.

  installers/opencode.sh uninstall --project
      Remove manifest-owned project-local OpenCode links.

Manifest:
  The installer writes .agents-orchestrator-manifest in the target. A later
  install is a sync: links from the old manifest that are no longer selected
  are removed if they are still symlinks.
EOF
}

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

target_root() {
  if [ -n "$TARGET_ARG" ]; then
    absolute_path "$TARGET_ARG"
  elif [ "$PROJECT_TARGET" -eq 1 ]; then
    printf '%s/.opencode\n' "$PWD"
  else
    printf '%s/.config/opencode\n' "$HOME"
  fi
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

discover_components() {
  local out domain domain_name type dir file name status src dest target skill_file
  out="$1"
  target="$2"
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
        dest="$target/$type/$name"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$type" "$name" "$domain_name" "$status" "$src" "$dest" >> "$out"
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
        dest="$target/skills/$name"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "skills" "$name" "$domain_name" "$status" "$src" "$dest" >> "$out"
      done
    fi

    dir="$domain/plugins"
    [ -d "$dir" ] || continue
    find "$dir" -type f -name '*.ts' | sort | while IFS= read -r file; do
      name="$(basename "$file")"
      src="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
      dest="$target/plugins/$name"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "plugins" "$name" "$domain_name" "-" "$src" "$dest" >> "$out"
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

remove_stale_links() {
  local old_manifest new_manifest old_links new_links dest
  old_manifest="$1"
  new_manifest="$2"
  [ -f "$old_manifest" ] || return 0

  old_links="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-old.XXXXXX")"
  new_links="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-new.XXXXXX")"
  awk -F '\t' '$1 == "link" { print $NF }' "$old_manifest" | sort -u > "$old_links"
  awk -F '\t' '$1 == "link" { print $NF }' "$new_manifest" | sort -u > "$new_links"

  comm -23 "$old_links" "$new_links" | while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ -L "$dest" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'rm %s\n' "$dest"
      else
        rm "$dest"
      fi
    fi
  done

  rm -f "$old_links" "$new_links"
}

install_action() {
  local target selected new_manifest manifest type name domain status src dest
  target="$(target_root)"
  selected="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-selected.XXXXXX")"
  new_manifest="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-manifest.XXXXXX")"
  : > "$new_manifest"

  discover_components "$selected" "$target"
  check_collisions "$selected"

  ensure_dir "$target/agents" "$new_manifest"
  ensure_dir "$target/commands" "$new_manifest"
  ensure_dir "$target/skills" "$new_manifest"
  ensure_dir "$target/plugins" "$new_manifest"

  while IFS=$'\t' read -r type name domain status src dest; do
    link_component "$src" "$dest" "$new_manifest"
  done < "$selected"

  manifest="$target/$MANIFEST_NAME"
  remove_stale_links "$manifest" "$new_manifest"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'write manifest %s\n' "$manifest"
  else
    mv "$new_manifest" "$manifest"
  fi
  rm -f "$selected" "$new_manifest"
}

uninstall_action() {
  local target manifest links dirs dest dir
  target="$(target_root)"
  manifest="$target/$MANIFEST_NAME"
  [ -f "$manifest" ] || { warn "$manifest: no manifest found"; return 0; }

  links="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-links.XXXXXX")"
  dirs="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-dirs.XXXXXX")"
  awk -F '\t' '$1 == "link" { print $NF }' "$manifest" > "$links"
  awk -F '\t' '$1 == "dir" { print $NF }' "$manifest" > "$dirs"

  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ -L "$dest" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$dest"; else rm "$dest"; fi
    fi
  done < "$links"

  sort -r "$dirs" | while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    if [ -d "$dir" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then printf 'rmdir %s\n' "$dir"; else rmdir "$dir" 2>/dev/null || true; fi
    fi
  done

  if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$manifest"; else rm -f "$manifest"; fi
  rm -f "$links" "$dirs"
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

status_action() {
  local target selected type name domain status src dest state
  target="$(target_root)"
  selected="$(mktemp "${TMPDIR:-/tmp}/agents-orchestrator-selected.XXXXXX")"
  discover_components "$selected" "$target"
  check_collisions "$selected"
  while IFS=$'\t' read -r type name domain status src dest; do
    state="$(link_state "$src" "$dest")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$domain" "$type" "$name" "$status" "$state"
  done < "$selected"
  rm -f "$selected"
}

[ "$#" -gt 0 ] || { usage; exit 1; }
case "$1" in
  -h|--help|help)
    usage
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
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

validate_filters

case "$ACTION" in
  install) install_action ;;
  uninstall) uninstall_action ;;
  status) status_action ;;
  *) usage; die "unknown action: $ACTION" ;;
esac
