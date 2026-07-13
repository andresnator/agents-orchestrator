#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034  # MANIFEST_ROOT/DEST_PATH are read by lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installers/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

TARGET=""
MIN_TUI_OPENCODE_VERSION="1.17.15"
MODEL_CONFIGURATOR_SPEC="./tui-plugins/model-configurator.tsx"
JSONC_PARSER_VERSION="3.3.1"
JSONC_EDITOR="$REPO_ROOT/scripts/jsonc-array.py"
INSTALL_TX_DIR=""
INSTALL_TX_RECORDS=""

runtime_usage() {
  cat <<'EOF'
Usage:
  opencode.sh <install|uninstall|status> [--domain d1,d2] [--status s1,s2]
              [--project] [--target DIR] [--dry-run] [--force]

Actions:
  install     Sync selected domain components into an OpenCode target as symlinks.
              TUI plugins are also registered by exact path in tui.json.
              Always links global/AGENTS.md to $TARGET/AGENTS.md (global rules),
              regardless of --domain/--status filters. A pre-existing foreign
              AGENTS.md in the target is skipped with a warning unless --force.
  uninstall   Remove symlinks recorded in the target manifest, then remove the manifest.
  status      List selected components and whether each target link is linked, not linked, or foreign.

Targets:
  default      ~/.config/opencode
  --project   ./.opencode from the current working directory
  --target    Explicit alternate target, useful for tests and scratch installs

Filters:
  --domain    Comma-separated domains, or all.
              Domains are discovered dynamically from domains/
              (currently: architecture, common, docs, meta, plan, refactor, sdd).
              Domain skills are symlinks to the top-level skills/ directory.
  --status    Comma-separated skill lifecycle states, or all.
              Valid statuses: backlog, in-progress, testing, done.
               Agents, commands, plugins, and TUI plugins are not status-filtered because
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

runtime_init() {
  if [ -n "$TARGET_ARG" ]; then
    TARGET="$(absolute_path "$TARGET_ARG")"
  elif [ "$PROJECT_TARGET" -eq 1 ]; then
    TARGET="$PWD/.opencode"
  else
    TARGET="$HOME/.config/opencode"
  fi
  MANIFEST_ROOT="$TARGET"
}

runtime_ensure_dirs() {
  ensure_dir "$TARGET/agents" "$1"
  ensure_dir "$TARGET/commands" "$1"
  ensure_dir "$TARGET/skills" "$1"
  ensure_dir "$TARGET/plugins" "$1"
  ensure_dir "$TARGET/tui-plugins" "$1"
}

runtime_dest() {
  DEST_PATH="$TARGET/$1/$2"
}

runtime_install_component() {
  local type="$1" src="$3" dest="$4" manifest="$5" companion support profile profiles_dest
  if [ "$type" != "tui-plugins" ]; then
    link_component "$src" "$dest" "$manifest"
    return 0
  fi

  install_tui_source "$src" "$dest" "$manifest"
  companion="${src%.tsx}"
  if [ -d "$companion" ]; then
    prepare_tui_directory "${dest%.tsx}" "$manifest"
    for support in "$companion"/*.ts "$companion"/*.tsx; do
      [ -f "$support" ] || continue
      install_tui_source "$support" "${dest%.tsx}/$(basename "$support")" "$manifest"
    done
    profiles_dest="${dest%.tsx}/profiles"
    prepare_tui_directory "$profiles_dest" "$manifest"
    for profile in "$REPO_ROOT"/profiles/*.json; do
      [ -f "$profile" ] || continue
      install_tui_source "$profile" "$profiles_dest/$(basename "$profile")" "$manifest"
    done
    generate_file "$REPO_ROOT" "${dest%.tsx}/agents.json" "$manifest" render_agent_catalog
  fi
  maybe_fail_install "after-links"
  ensure_managed_array_entry "$TARGET/tui.json" plugin "$MODEL_CONFIGURATOR_SPEC" "$manifest"
  maybe_fail_install "after-managed-array"
  ensure_managed_object_entry "$TARGET/package.json" dependencies.jsonc-parser "$JSONC_PARSER_VERSION" "$manifest"
  maybe_fail_install "after-managed-object"
}

runtime_component_state() {
  local type="$1" src="$3" dest="$4" state companion companion_state compatibility support support_state profile
  state="$(link_state "$src" "$dest")"
  [ "$type" = "tui-plugins" ] || { printf '%s' "$state"; return 0; }
  state="$(file_state "$src" "$dest" copy_source)"
  companion="${src%.tsx}"
  companion_state="generated"
  if [ -d "$companion" ]; then
    for support in "$companion"/*.ts "$companion"/*.tsx; do
      [ -f "$support" ] || continue
      support_state="$(file_state "$support" "${dest%.tsx}/$(basename "$support")" copy_source)"
      [ "$support_state" = "generated" ] || companion_state="$support_state"
    done
    for profile in "$REPO_ROOT"/profiles/*.json; do
      [ -f "$profile" ] || continue
      support_state="$(file_state "$profile" "${dest%.tsx}/profiles/$(basename "$profile")" copy_source)"
      [ "$support_state" = "generated" ] || companion_state="$support_state"
    done
    support_state="$(file_state "$REPO_ROOT" "${dest%.tsx}/agents.json" render_agent_catalog)"
    [ "$support_state" = "generated" ] || companion_state="$support_state"
  fi
  if [ "$state" = "generated" ] && [ "$companion_state" = "generated" ] &&
    managed_array_has "$TARGET/tui.json" plugin "$MODEL_CONFIGURATOR_SPEC" &&
    managed_object_has "$TARGET/package.json" dependencies.jsonc-parser "$JSONC_PARSER_VERSION"; then
    compatibility="$(opencode_compatibility)"
    if [ "$compatibility" = "compatible" ]; then
      printf 'generated+registered'
    else
      printf 'generated+registered; %s' "$compatibility"
    fi
  elif [ "$state" = "foreign" ] || [ "$companion_state" = "foreign" ]; then
    printf 'foreign'
  else
    printf 'not installed'
  fi
}

runtime_pre_install() {
  local selected="$1" type name domain status src dest companion
  awk -F '\t' '$1 == "tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" || return 0
  command -v python3 >/dev/null 2>&1 || die "python3 is required to preserve tui.json comments"
  command -v jq >/dev/null 2>&1 || die "jq is required to manage the OpenCode plugin dependency"
  [ -f "$JSONC_EDITOR" ] || die "JSONC editor not found: $JSONC_EDITOR"
  check_opencode_version
  validate_managed_files

  while IFS=$'\t' read -r type name domain status src; do
    [ "$type" = "tui-plugins" ] || continue
    dest="$TARGET/$type/$name"
    preflight_tui_source "$src" "$dest"
    companion="${src%.tsx}"
    if [ -d "$companion" ]; then
      preflight_tui_directory "${dest%.tsx}"
      for support in "$companion"/*.ts "$companion"/*.tsx; do
        [ -f "$support" ] || continue
        preflight_tui_source "$support" "${dest%.tsx}/$(basename "$support")"
      done
      preflight_tui_directory "${dest%.tsx}/profiles"
      for profile in "$REPO_ROOT"/profiles/*.json; do
        [ -f "$profile" ] || continue
        preflight_tui_source "$profile" "${dest%.tsx}/profiles/$(basename "$profile")"
      done
      preflight_generated_source "$REPO_ROOT" "${dest%.tsx}/agents.json" render_agent_catalog
    fi
  done < "$selected"
}

runtime_remove_managed_entry() {
  local kind="$1" file="$2" field="$3" value="$4"
  case "$kind" in
    managed-array) remove_managed_array_entry "$file" "$field" "$value" ;;
    managed-object) remove_managed_object_entry "$file" "$field" "$value" ;;
  esac
}

runtime_begin_install() {
  local selected="$1" manifest="$2" type name domain status src companion kind owned_path field value
  [ "$DRY_RUN" -eq 0 ] || return 0
  INSTALL_TX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-orchestrator-install.XXXXXX")"
  INSTALL_TX_RECORDS="$INSTALL_TX_DIR/records.tsv"
  : > "$INSTALL_TX_RECORDS"

  snapshot_created_directory "$TARGET"
  snapshot_created_directory "$TARGET/agents"
  snapshot_created_directory "$TARGET/commands"
  snapshot_created_directory "$TARGET/skills"
  snapshot_created_directory "$TARGET/plugins"
  snapshot_created_directory "$TARGET/tui-plugins"
  snapshot_install_path "$TARGET/tui.json"
  snapshot_install_path "$TARGET/tui.json.bak"
  snapshot_install_path "$TARGET/package.json"
  snapshot_install_path "$TARGET/package.json.bak"
  snapshot_install_path "$manifest"

  while IFS=$'\t' read -r type name domain status src; do
    DEST_PATH=""
    runtime_dest "$type" "$name"
    [ -n "$DEST_PATH" ] || continue
    snapshot_install_path "$DEST_PATH"
    if [ "$type" = "tui-plugins" ]; then
      companion="${src%.tsx}"
      [ ! -d "$companion" ] || snapshot_install_path "${DEST_PATH%.tsx}"
    fi
  done < "$selected"
  snapshot_install_path "$TARGET/AGENTS.md"
  if [ -f "$manifest" ]; then
    while IFS=$'\t' read -r kind owned_path field value; do
      case "$kind" in
        link|file) snapshot_install_path "$owned_path" ;;
      esac
    done < "$manifest"
  fi
}

runtime_commit_install() {
  [ -z "$INSTALL_TX_DIR" ] || rm -rf "$INSTALL_TX_DIR"
  INSTALL_TX_DIR=""
  INSTALL_TX_RECORDS=""
}

runtime_abort_install() {
  local reversed kind dest payload
  [ -n "$INSTALL_TX_DIR" ] && [ -f "$INSTALL_TX_RECORDS" ] || return 0
  reversed="$INSTALL_TX_DIR/reversed.tsv"
  awk '{ rows[NR] = $0 } END { for (i = NR; i >= 1; i--) print rows[i] }' "$INSTALL_TX_RECORDS" > "$reversed"
  while IFS=$'\t' read -r kind dest payload; do
    [ -n "$dest" ] || continue
    case "$kind" in
      absent)
        if [ -L "$dest" ] || [ -f "$dest" ]; then rm -f "$dest"; elif [ -d "$dest" ]; then rm -rf "$dest"; fi
        ;;
      absent-dir)
        [ ! -d "$dest" ] || rmdir "$dest" 2>/dev/null || true
        ;;
      symlink)
        if [ -e "$dest" ] || [ -L "$dest" ]; then rm -rf "$dest"; fi
        mkdir -p "$(dirname "$dest")"
        ln -s "$payload" "$dest"
        ;;
      file)
        if [ -e "$dest" ] || [ -L "$dest" ]; then rm -rf "$dest"; fi
        mkdir -p "$(dirname "$dest")"
        cp -p "$payload" "$dest"
        ;;
      directory)
        if [ -e "$dest" ] || [ -L "$dest" ]; then rm -rf "$dest"; fi
        mkdir -p "$(dirname "$dest")"
        cp -pR "$payload" "$dest"
        ;;
    esac
  done < "$reversed"
  runtime_commit_install
}

runtime_before_manifest_commit() {
  maybe_fail_install "before-manifest"
}

runtime_after_manifest_commit() {
  maybe_fail_install "after-manifest"
}

snapshot_created_directory() {
  local directory="$1"
  if [ ! -e "$directory" ] && [ ! -L "$directory" ]; then
    printf 'absent-dir\t%s\t-\n' "$directory" >> "$INSTALL_TX_RECORDS"
  fi
}

snapshot_install_path() {
  local target="$1" index payload
  awk -F '\t' -v target="$target" '$2 == target { found = 1; exit } END { exit found ? 0 : 1 }' "$INSTALL_TX_RECORDS" && return 0
  index="$(wc -l < "$INSTALL_TX_RECORDS" | tr -d ' ')"
  payload="$INSTALL_TX_DIR/payload-$index"
  if [ -L "$target" ]; then
    printf 'symlink\t%s\t%s\n' "$target" "$(readlink "$target")" >> "$INSTALL_TX_RECORDS"
  elif [ -f "$target" ]; then
    cp -p "$target" "$payload"
    printf 'file\t%s\t%s\n' "$target" "$payload" >> "$INSTALL_TX_RECORDS"
  elif [ -d "$target" ]; then
    cp -pR "$target" "$payload"
    printf 'directory\t%s\t%s\n' "$target" "$payload" >> "$INSTALL_TX_RECORDS"
  else
    printf 'absent\t%s\t-\n' "$target" >> "$INSTALL_TX_RECORDS"
  fi
}

maybe_fail_install() {
  local step="$1"
  if [ "${AGENTS_ORCHESTRATOR_TEST_FAIL_STEP:-}" = "$step" ]; then
    die "injected installer failure at $step"
  fi
}

check_opencode_version() {
  local compatibility
  compatibility="$(opencode_compatibility)"
  [ "$compatibility" = "compatible" ] || die "$compatibility"
}

opencode_compatibility() {
  local binary version
  binary="${OPENCODE_BIN:-$(command -v opencode || true)}"
  if [ -z "$binary" ]; then
    printf 'opencode >= %s is required for TUI plugins' "$MIN_TUI_OPENCODE_VERSION"
    return 0
  fi
  version="$($binary --version 2>/dev/null | tr -d '[:space:]')"
  if version_at_least "$version" "$MIN_TUI_OPENCODE_VERSION"; then
    printf 'compatible'
  else
    printf 'opencode >= %s is required for TUI plugins (found %s)' "$MIN_TUI_OPENCODE_VERSION" "${version:-unknown}"
  fi
}

version_at_least() {
  awk -v current="${1#v}" -v minimum="${2#v}" 'BEGIN {
    split(current, c, /[.-]/); split(minimum, m, /[.-]/)
    for (i = 1; i <= 3; i++) {
      cv = c[i] + 0; mv = m[i] + 0
      if (cv > mv) exit 0
      if (cv < mv) exit 1
    }
    exit 0
  }'
}

validate_managed_files() {
  local status existing
  if [ -e "$TARGET/tui.json" ]; then
    status=0
    python3 "$JSONC_EDITOR" has "$TARGET/tui.json" plugin "$MODEL_CONFIGURATOR_SPEC" >/dev/null || status=$?
    [ "$status" -ne 2 ] || die "$TARGET/tui.json is not valid supported JSONC"
  fi
  if [ -e "$TARGET/package.json" ]; then
    jq empty "$TARGET/package.json" 2>/dev/null || die "$TARGET/package.json is not valid JSON"
    existing="$(jq -r '.dependencies["jsonc-parser"] // empty' "$TARGET/package.json")"
    [ -z "$existing" ] || [ "$existing" = "$JSONC_PARSER_VERSION" ] ||
      die "$TARGET/package.json has foreign jsonc-parser dependency '$existing' (expected $JSONC_PARSER_VERSION)"
  fi
}

preflight_tui_source() {
  local src="$1" dest="$2" state
  state="$(file_state "$src" "$dest" copy_source)"
  if [ "$state" = "foreign" ] && manifest_owns_link "$OLD_MANIFEST" "$dest"; then return 0; fi
  if [ "$state" = "stale" ] && manifest_owns_file "$OLD_MANIFEST" "$dest"; then return 0; fi
  case "$state" in
    generated|not\ installed) return 0 ;;
  esac
  [ "$FORCE" -eq 1 ] || die "$dest exists and is not an installer-owned TUI source"
}

install_tui_source() {
  local src="$1" dest="$2" manifest="$3"
  if [ -L "$dest" ] && manifest_owns_link "$OLD_MANIFEST" "$dest"; then
    if [ "$DRY_RUN" -eq 1 ]; then printf 'rm %s\n' "$dest"; else rm "$dest"; fi
  fi
  generate_file "$src" "$dest" "$manifest" copy_source
}

preflight_tui_directory() {
  local dest="$1"
  if [ -L "$dest" ]; then
    manifest_owns_link "$OLD_MANIFEST" "$dest" && return 0
    [ "$FORCE" -eq 1 ] || die "$dest is a foreign symlink"
  elif [ -e "$dest" ] && [ ! -d "$dest" ]; then
    [ "$FORCE" -eq 1 ] || die "$dest exists and is not a directory"
  fi
}

prepare_tui_directory() {
  local dest="$1" manifest="$2"
  if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -d "$dest" ]; }; then
    if [ "$DRY_RUN" -eq 1 ]; then printf 'rm -rf %s\n' "$dest"; else rm -rf "$dest"; fi
  fi
  ensure_dir "$dest" "$manifest"
}

copy_source() {
  cat "$1"
}

render_agent_catalog() {
  local agent domain mode
  for agent in "$REPO_ROOT"/domains/*/agents/*.md; do
    [ -f "$agent" ] || continue
    domain="$(basename "$(dirname "$(dirname "$agent")")")"
    mode="$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } $1 == "mode:" { print $2; exit }' "$agent")"
    jq -n --arg name "$(basename "$agent" .md)" --arg domain "$domain" --arg mode "${mode:-subagent}" \
      '{name: $name, domain: $domain, mode: $mode}'
  done | jq -s 'unique_by(.name)'
}

preflight_generated_source() {
  local src="$1" dest="$2" transform="$3" state
  state="$(file_state "$src" "$dest" "$transform")"
  if [ "$state" = "stale" ] && manifest_owns_file "$OLD_MANIFEST" "$dest"; then return 0; fi
  case "$state" in
    generated|not\ installed) return 0 ;;
  esac
  [ "$FORCE" -eq 1 ] || die "$dest exists and is not an installer-owned generated source"
}

manifest_owns_link() {
  local manifest="$1" dest="$2"
  [ -f "$manifest" ] || return 1
  awk -F '\t' -v dest="$dest" '$1 == "link" && $2 == dest { found = 1; exit } END { exit found ? 0 : 1 }' "$manifest"
}

ensure_managed_array_entry() {
  local file="$1" field="$2" value="$3" manifest="$4" owns=0
  manifest_owns_managed_value managed-array "$OLD_MANIFEST" "$file" "$field" "$value" && owns=1
  if ! managed_array_has "$file" "$field" "$value"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'add managed array entry %s.%s = %s\n' "$file" "$field" "$value"
    else
      rewrite_managed_array "$file" "$field" "$value" add
    fi
    owns=1
  fi
  [ "$owns" -eq 0 ] || printf 'managed-array\t%s\t%s\t%s\n' "$file" "$field" "$value" >> "$manifest"
}

remove_managed_array_entry() {
  local file="$1" field="$2" value="$3"
  managed_array_has "$file" "$field" "$value" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'remove managed array entry %s.%s = %s\n' "$file" "$field" "$value"
  else
    rewrite_managed_array "$file" "$field" "$value" remove
  fi
}

managed_array_has() {
  local file="$1" field="$2" value="$3"
  [ -f "$file" ] || return 1
  python3 "$JSONC_EDITOR" has "$file" "$field" "$value" >/dev/null 2>&1
}

rewrite_managed_array() {
  local file="$1" field="$2" value="$3" action="$4" tmp backup mode status
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp "$(dirname "$file")/.agents-orchestrator-jsonc.XXXXXX")"
  if ! python3 "$JSONC_EDITOR" "$action" "$file" "$field" "$value" > "$tmp"; then
    rm -f "$tmp"
    die "failed to $action managed value in $file"
  fi
  status=0
  python3 "$JSONC_EDITOR" has "$tmp" "$field" "$value" >/dev/null 2>&1 || status=$?
  if [ "$status" -eq 2 ] || { [ "$action" = "add" ] && [ "$status" -ne 0 ]; } ||
    { [ "$action" = "remove" ] && [ "$status" -ne 1 ]; }; then
    rm -f "$tmp"
    die "failed to validate managed value in $file"
  fi
  backup=""
  if [ -f "$file" ]; then
    backup="$file.bak"
    cp -f "$file" "$backup"
    mode="$(file_mode "$file")"
    chmod "$mode" "$tmp"
  else
    chmod 600 "$tmp"
  fi
  mv "$tmp" "$file"
  [ -z "$backup" ] || printf 'backup: %s\n' "$backup"
}

ensure_managed_object_entry() {
  local file="$1" field="$2" value="$3" manifest="$4" owns=0
  manifest_owns_managed_value managed-object "$OLD_MANIFEST" "$file" "$field" "$value" && owns=1
  if ! managed_object_has "$file" "$field" "$value"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'set managed object entry %s.%s = %s\n' "$file" "$field" "$value"
    else
      rewrite_managed_object "$file" "$field" "$value" set
    fi
    owns=1
  fi
  [ "$owns" -eq 0 ] || printf 'managed-object\t%s\t%s\t%s\n' "$file" "$field" "$value" >> "$manifest"
}

remove_managed_object_entry() {
  local file="$1" field="$2" value="$3"
  managed_object_has "$file" "$field" "$value" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'remove managed object entry %s.%s = %s\n' "$file" "$field" "$value"
  else
    rewrite_managed_object "$file" "$field" "$value" remove
  fi
}

managed_object_has() {
  local file="$1" field="$2" value="$3"
  [ -f "$file" ] || return 1
  [ "$(jq -r --arg field "$field" 'getpath($field | split(".")) // empty' "$file" 2>/dev/null)" = "$value" ]
}

manifest_owns_managed_value() {
  local kind="$1" manifest="$2" file="$3" field="$4" value="$5"
  [ -f "$manifest" ] || return 1
  awk -F '\t' -v k="$kind" -v f="$file" -v p="$field" -v v="$value" '
    $1 == k && $2 == f && $3 == p && $4 == v { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$manifest"
}

rewrite_managed_object() {
  local file="$1" field="$2" value="$3" action="$4" tmp backup mode
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp "$(dirname "$file")/.agents-orchestrator-json.XXXXXX")"
  if [ -f "$file" ]; then
    if [ "$action" = "set" ]; then
      jq --arg field "$field" --arg value "$value" 'setpath($field | split("."); $value)' "$file" > "$tmp"
    else
      jq --arg field "$field" 'delpaths([$field | split(".")]) | if .dependencies == {} then del(.dependencies) else . end' "$file" > "$tmp"
    fi
    backup="$file.bak"
    cp -f "$file" "$backup"
    mode="$(file_mode "$file")"
    chmod "$mode" "$tmp"
  else
    jq -n --arg field "$field" --arg value "$value" 'setpath($field | split("."); $value)' > "$tmp"
    backup=""
    chmod 600 "$tmp"
  fi
  jq empty "$tmp" 2>/dev/null || { rm -f "$tmp"; die "failed to validate $file"; }
  mv "$tmp" "$file"
  [ -z "$backup" ] || printf 'backup: %s\n' "$backup"
}

file_mode() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then stat -f '%Lp' "$1"; else stat -c '%a' "$1"; fi
}

runtime_install_global() {
  link_component "$REPO_ROOT/global/AGENTS.md" "$TARGET/AGENTS.md" "$1"
}

runtime_status_global() {
  local state
  state="$(link_state "$REPO_ROOT/global/AGENTS.md" "$TARGET/AGENTS.md")"
  printf '%s\t%s\t%s\t%s\t%s\n' "-" "global" "AGENTS.md" "-" "$state"
}

harness_main "$@"
