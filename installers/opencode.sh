#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034  # MANIFEST_ROOT/DEST_PATH are read by lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installers/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

TARGET=""
OPENCODE_CONFIG_FILE=""
CLI_CONFIG_FILE=""
MIN_EXTERNAL_OPENCODE_VERSION="1.17.15"
MIN_LOCAL_TUI_OPENCODE_VERSION="2.0.28"
RETIRED_MODEL_TUI_SPECS="./plugins/model-configurator/tui.js ./plugins/model-configurator.tsx"
JSONC_EDITOR="$REPO_ROOT/scripts/jsonc-array.py"
INSTALL_TX_DIR=""
INSTALL_TX_RECORDS=""

runtime_usage() {
  cat <<'EOF'
Usage:
  opencode.sh <install|uninstall|status> [--status s1,s2]
              [--project] [--target DIR] [--dry-run] [--force] [--reload]

Actions:
  install     Sync all repository components into an OpenCode target. Repository
              components are symlinked. npm server and TUI plugins are
              registered by exact package version in the matching OpenCode
              config. Repository-local V2 TUI plugins require OpenCode >= 2.0.28.
              Local and npm TUI plugins register in cli.json.
              Always links global/AGENTS.md to $TARGET/AGENTS.md (global rules)
              and standards/ to $TARGET/standards,
              regardless of the --status filter. A pre-existing foreign
              AGENTS.md in the target is skipped with a warning unless --force.
  uninstall   Remove manifest-owned links, files, config values, and empty directories.
  status      List selected components and their target state.

Targets:
  default      ~/.config/opencode
  --project   ./.opencode from the current working directory
  --target    Explicit alternate target, useful for tests and scratch installs

Filters:
  --status    Comma-separated skill lifecycle states, or all.
              Valid statuses: backlog, in-progress, testing, done.
              Agents, commands, npm plugins, and TUI plugins are not
              status-filtered because
              OpenCode frontmatter for executable components cannot carry
              repository-only metadata.

Defaults:
  --status all

Options:
  --dry-run   Print planned mkdir/link/rm/manifest actions without changing files.
  --force     Replace an existing non-matching destination symlink/file during install.
  --reload    After a committed install, POST /global/dispose to running OpenCode
              servers so re-installed agents, commands, and skills are re-read
              without a restart. Servers come from OPENCODE_RELOAD_URLS
              (comma/space-separated base URLs) or lsof discovery on localhost.
              Best-effort: never fails the install. Plugin code changes
              (including TUI plugins) still require an OpenCode restart.
  -h, --help  Show this help.

Examples:
  installers/opencode.sh install
      Install every component and every lifecycle state into ~/.config/opencode.

  installers/opencode.sh install --project
      Install into ./.opencode for the current project.

  installers/opencode.sh install --status done,testing
      Install only done/testing skills (plus all other components).

  installers/opencode.sh install --target /tmp/opencode-test --dry-run
      Preview an install into a scratch target.

  installers/opencode.sh status
      Show components and link state in the default target.

  installers/opencode.sh uninstall --project
      Remove manifest-owned project-local OpenCode links.

Manifest:
  The installer writes .agents-orchestrator-manifest in the target. A later
  install is a sync: previously owned links, files, config values, and empty
  directories that are no longer selected are removed with type/value guards.
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
  if [ -e "$TARGET/opencode.jsonc" ]; then
    OPENCODE_CONFIG_FILE="$TARGET/opencode.jsonc"
  elif [ -e "$TARGET/opencode.json" ]; then
    OPENCODE_CONFIG_FILE="$TARGET/opencode.json"
  else
    OPENCODE_CONFIG_FILE="$TARGET/opencode.jsonc"
  fi
  CLI_CONFIG_FILE="$TARGET/cli.json"
  MANIFEST_ROOT="$TARGET"
}

runtime_ensure_dirs() {
  ensure_dir "$TARGET/agents" "$1"
  ensure_dir "$TARGET/commands" "$1"
  ensure_dir "$TARGET/skills" "$1"
  ensure_dir "$TARGET/plugins" "$1"
}

# TUI plugins install into OpenCode's plugin folder. npm plugins register
# in the matching OpenCode config.
runtime_dest() {
  case "$1" in
    npm-server-plugins) DEST_PATH="$OPENCODE_CONFIG_FILE" ;;
    npm-tui-plugins) DEST_PATH="$CLI_CONFIG_FILE" ;;
    tui-plugins) DEST_PATH="$TARGET/plugins/$2" ;;
    *) DEST_PATH="$TARGET/$1/$2" ;;
  esac
}

external_descriptor_field() {
  jq -er --arg field "$2" '.[$field] // empty' "$1"
}

validate_npm_tui_descriptor() {
  local name="$1" descriptor="$2"
  jq -e --arg name "$name" '
    .schemaVersion == 1 and
    .name == $name and
    .kind == "tui" and
    .source == "npm" and
    (.package | type == "string" and test("^(@[A-Za-z0-9_.-]+/)?[A-Za-z0-9_.-]+$")) and
    (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    ([keys[]] - ["kind", "name", "package", "schemaVersion", "source", "version"] | length == 0)
  ' "$descriptor" >/dev/null 2>&1 || die "$descriptor: invalid npm TUI plugin descriptor"
}

npm_plugin_package() {
  external_descriptor_field "$1" package
}

npm_plugin_spec() {
  local descriptor="$1" package version
  package="$(npm_plugin_package "$descriptor")"
  version="$(external_descriptor_field "$descriptor" version)"
  printf '%s@%s\n' "$package" "$version"
}

validate_npm_server_descriptor() {
  local name="$1" descriptor="$2"
  jq -e --arg name "$name" '
    .schemaVersion == 1 and
    .name == $name and
    .kind == "server" and
    .source == "npm" and
    (.package | type == "string" and test("^(@[A-Za-z0-9_.-]+/)?[A-Za-z0-9_.-]+$")) and
    (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    ([keys[]] - ["kind", "name", "package", "schemaVersion", "source", "version"] | length == 0)
  ' "$descriptor" >/dev/null 2>&1 || die "$descriptor: invalid npm server plugin descriptor"
}

tui_spec_for_dest() {
  local dest="$1"
  case "$dest" in
    "$TARGET"/*) printf './%s' "${dest#"$TARGET"/}" ;;
    *) die "TUI entry is outside the OpenCode target: $dest" ;;
  esac
}

tui_support_sources() {
  local companion="$1" support
  for support in "$companion"/*.ts "$companion"/*.tsx "$companion"/*.mjs "$companion"/package.json; do
    [ -f "$support" ] || continue
    case "$support" in *.test.*) continue ;; esac
    printf '%s\n' "$support"
  done
}

runtime_install_component() {
  local type="$1" name="$2" src="$3" dest="$4" manifest="$5" companion support spec package legacy_spec
  case "$type" in
    npm-server-plugins)
      package="$(npm_plugin_package "$src")"
      spec="$(npm_plugin_spec "$src")"
      if ! managed_array_has "$dest" plugin "$spec" &&
        managed_array_npm_has "$dest" plugin "$package"; then
        remove_managed_npm_entries "$dest" plugin "$package"
      fi
      ensure_managed_array_entry "$dest" plugin "$spec" "$manifest"
      return 0
      ;;
    npm-tui-plugins)
      package="$(npm_plugin_package "$src")"
      spec="$(npm_plugin_spec "$src")"
      if ! managed_array_has "$dest" plugins "$spec" &&
        managed_array_npm_has "$dest" plugins "$package"; then
        remove_managed_npm_entries "$dest" plugins "$package"
      fi
      for legacy_spec in $RETIRED_MODEL_TUI_SPECS; do
        if managed_array_has "$dest" plugins "$legacy_spec" &&
          { [ "$FORCE" -eq 1 ] || manifest_owns_managed_value managed-array "$OLD_MANIFEST" "$dest" plugins "$legacy_spec"; }; then
          remove_managed_array_entry "$dest" plugins "$legacy_spec"
        fi
      done
      ensure_managed_array_entry "$dest" plugins "$spec" "$manifest"
      return 0
      ;;
    tui-plugins) ;;
    *)
      link_component "$src" "$dest" "$manifest"
      return 0
      ;;
  esac

  install_tui_source "$src" "$dest" "$manifest"
  companion="${src%.tsx}"
  if [ -d "$companion" ]; then
    prepare_tui_directory "${dest%.tsx}" "$manifest"
    while IFS= read -r support; do
      install_tui_source "$support" "${dest%.tsx}/$(basename "$support")" "$manifest"
    done < <(tui_support_sources "$companion")
  fi
  spec="$(tui_spec_for_dest "$dest")"
  ensure_managed_array_entry "$CLI_CONFIG_FILE" plugins "$spec" "$manifest"
}

runtime_component_state() {
  local type="$1" name="$2" src="$3" dest="$4" state companion companion_state compatibility support support_state
  local spec version package

  if [ "$type" = "npm-server-plugins" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      printf 'unavailable (jq required)'
      return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
      printf 'unavailable (python3 required)'
      return 0
    fi
    version="$(external_descriptor_field "$src" version)"
    package="$(npm_plugin_package "$src")"
    spec="$(npm_plugin_spec "$src")"
    if managed_array_has "$dest" plugin "$spec"; then
      compatibility="$(opencode_compatibility)"
      if [ "$compatibility" = "compatible" ]; then
        printf 'registered@%s' "$version"
      else
        printf 'registered@%s; %s' "$version" "$compatibility"
      fi
    elif managed_array_npm_has "$dest" plugin "$package"; then
      printf 'foreign'
    else
      printf 'not installed'
    fi
    return 0
  fi

  if [ "$type" = "npm-tui-plugins" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      printf 'unavailable (jq required)'
      return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
      printf 'unavailable (python3 required)'
      return 0
    fi
    version="$(external_descriptor_field "$src" version)"
    package="$(npm_plugin_package "$src")"
    spec="$(npm_plugin_spec "$src")"
    if managed_array_has "$dest" plugins "$spec"; then
      compatibility="$(opencode_compatibility)"
      if [ "$compatibility" = "compatible" ]; then
        printf 'registered@%s' "$version"
      else
        printf 'registered@%s; %s' "$version" "$compatibility"
      fi
    elif managed_array_npm_has "$dest" plugins "$package"; then
      printf 'foreign'
    else
      printf 'not installed'
    fi
    return 0
  fi

  state="$(link_state "$src" "$dest")"
  [ "$type" = "tui-plugins" ] || { printf '%s' "$state"; return 0; }
  state="$(file_state "$src" "$dest" copy_source)"
  companion="${src%.tsx}"
  companion_state="generated"
  if [ -d "$companion" ]; then
    while IFS= read -r support; do
      support_state="$(file_state "$support" "${dest%.tsx}/$(basename "$support")" copy_source)"
      [ "$support_state" = "generated" ] || companion_state="$support_state"
    done < <(tui_support_sources "$companion")
  fi
  spec="$(tui_spec_for_dest "$dest")"
  if [ "$state" = "generated" ] && [ "$companion_state" = "generated" ] &&
    managed_array_has "$CLI_CONFIG_FILE" plugins "$spec"; then
    compatibility="$(opencode_compatibility "$MIN_LOCAL_TUI_OPENCODE_VERSION")"
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
  local selected="$1" type name status src dest companion support
  local package spec legacy_spec
  local has_npm_server=0 has_npm_tui=0 has_npm=0 has_tui=0 has_managed_config=0
  awk -F '\t' '$1 == "npm-server-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_npm_server=1
  awk -F '\t' '$1 == "npm-tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_npm_tui=1
  awk -F '\t' '$1 == "tui-plugins" || $1 == "npm-tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_tui=1
  [ "$has_npm_server" -eq 0 ] && [ "$has_npm_tui" -eq 0 ] || has_npm=1
  [ "$has_npm_server" -eq 0 ] && [ "$has_tui" -eq 0 ] || has_managed_config=1

  if [ "$has_npm" -eq 1 ]; then
    command -v jq >/dev/null 2>&1 || die "jq is required to validate npm plugin descriptors"
  fi
  if [ "$has_npm" -eq 1 ] || [ "$has_tui" -eq 1 ]; then
    check_opencode_version
  fi
  if [ "$has_managed_config" -eq 1 ]; then
    command -v python3 >/dev/null 2>&1 || die "python3 is required to preserve OpenCode config comments"
    [ -f "$JSONC_EDITOR" ] || die "JSONC editor not found: $JSONC_EDITOR"
    [ "$has_npm_server" -eq 0 ] || validate_managed_jsonc_file "$OPENCODE_CONFIG_FILE"
    if awk -F '\t' '$1 == "tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected"; then
      check_opencode_version "$MIN_LOCAL_TUI_OPENCODE_VERSION"
    fi
    if awk -F '\t' '$1 == "tui-plugins" || $1 == "npm-tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected"; then
      validate_managed_jsonc_file "$CLI_CONFIG_FILE" plugins
    fi
  fi

  while IFS=$'\t' read -r type name status src; do
    DEST_PATH=""
    runtime_dest "$type" "$name"
    dest="$DEST_PATH"
    case "$type" in
      npm-server-plugins)
        validate_npm_server_descriptor "$name" "$src"
        package="$(npm_plugin_package "$src")"
        spec="$(npm_plugin_spec "$src")"
        if ! managed_array_has "$dest" plugin "$spec" &&
          managed_array_npm_has "$dest" plugin "$package" &&
          [ "$FORCE" -ne 1 ] &&
          ! manifest_owns_npm_package "$OLD_MANIFEST" "$dest" plugin "$package"; then
          die "$dest already configures npm package $package; use --force to replace it"
        fi
        ;;
      npm-tui-plugins)
        validate_npm_tui_descriptor "$name" "$src"
        package="$(npm_plugin_package "$src")"
        spec="$(npm_plugin_spec "$src")"
        if ! managed_array_has "$dest" plugins "$spec" &&
          managed_array_npm_has "$dest" plugins "$package" &&
          [ "$FORCE" -ne 1 ] &&
          ! manifest_owns_npm_package "$OLD_MANIFEST" "$dest" plugins "$package"; then
          die "$dest already configures npm package $package; use --force to replace it"
        fi
        for legacy_spec in $RETIRED_MODEL_TUI_SPECS; do
          if managed_array_has "$dest" plugins "$legacy_spec" &&
            [ "$FORCE" -ne 1 ] &&
            ! manifest_owns_managed_value managed-array "$OLD_MANIFEST" "$dest" plugins "$legacy_spec"; then
            die "$dest contains foreign legacy Models Presets entry $legacy_spec; remove it or use --force"
          fi
        done
        ;;
      tui-plugins)
        preflight_tui_source "$src" "$dest"
        companion="${src%.tsx}"
        if [ -d "$companion" ]; then
          preflight_tui_directory "${dest%.tsx}"
          while IFS= read -r support; do
            preflight_tui_source "$support" "${dest%.tsx}/$(basename "$support")"
          done < <(tui_support_sources "$companion")
        fi
        ;;
    esac
  done < "$selected"
}

runtime_remove_managed_entry() {
  local kind="$1" file="$2" field="$3" value="$4"
  case "$kind" in
    managed-array) remove_managed_array_entry "$file" "$field" "$value" ;;
  esac
}

runtime_begin_install() {
  local selected="$1" manifest="$2" type name status src companion kind owned_path field value
  [ "$DRY_RUN" -eq 0 ] || return 0
  INSTALL_TX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-orchestrator-install.XXXXXX")"
  INSTALL_TX_RECORDS="$INSTALL_TX_DIR/records.tsv"
  : > "$INSTALL_TX_RECORDS"

  snapshot_created_directory "$TARGET"
  snapshot_created_directory "$TARGET/agents"
  snapshot_created_directory "$TARGET/commands"
  snapshot_created_directory "$TARGET/skills"
  snapshot_created_directory "$TARGET/plugins"
  snapshot_install_path "$OPENCODE_CONFIG_FILE"
  snapshot_install_path "$OPENCODE_CONFIG_FILE.bak"
  snapshot_install_path "$CLI_CONFIG_FILE"
  snapshot_install_path "$CLI_CONFIG_FILE.bak"
  snapshot_install_path "$manifest"

  while IFS=$'\t' read -r type name status src; do
    DEST_PATH=""
    runtime_dest "$type" "$name"
    [ -n "$DEST_PATH" ] || continue
    snapshot_install_path "$DEST_PATH"
    case "$type" in
      tui-plugins)
        companion="${src%.tsx}"
        [ ! -d "$companion" ] || snapshot_install_path "${DEST_PATH%.tsx}"
        ;;
    esac
  done < "$selected"
  snapshot_install_path "$TARGET/AGENTS.md"
  snapshot_install_path "$TARGET/standards"
  if [ -f "$manifest" ]; then
    while IFS=$'\t' read -r kind owned_path field value; do
      case "$kind" in
        link|file) snapshot_install_path "$owned_path" ;;
        managed-array)
          snapshot_install_path "$owned_path"
          snapshot_install_path "$owned_path.bak"
          ;;
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

check_opencode_version() {
  local compatibility
  compatibility="$(opencode_compatibility "${1:-$MIN_EXTERNAL_OPENCODE_VERSION}")"
  [ "$compatibility" = "compatible" ] || die "$compatibility"
}

opencode_compatibility() {
  local binary version version_pattern minimum
  minimum="${1:-$MIN_EXTERNAL_OPENCODE_VERSION}"
  binary="${OPENCODE_BIN:-$(command -v opencode || true)}"
  if [ -z "$binary" ]; then
    printf 'opencode >= %s is required for npm and TUI plugins' "$minimum"
    return 0
  fi
  # Accept bare/v-prefixed versions and OpenCode v2's product-prefixed output.
  version_pattern='^[[:space:]]*(opencode[[:space:]]+)?v?([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?[[:space:]]*$'
  if version="$("$binary" --version 2>/dev/null)" &&
    [[ "$version" =~ $version_pattern ]] &&
    version_at_least "${BASH_REMATCH[2]}" "$minimum"; then
    printf 'compatible'
  else
    printf 'opencode >= %s is required for npm and TUI plugins (found %s)' "$minimum" "${version:-unknown}"
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

validate_managed_jsonc_file() {
  local file="$1" field="${2:-plugin}" status=0
  [ -e "$file" ] || return 0
  python3 "$JSONC_EDITOR" has "$file" "$field" "__agents_orchestrator_validation_probe__" >/dev/null || status=$?
  [ "$status" -ne 2 ] || die "$file is not valid supported JSONC"
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

managed_array_npm_has() {
  local file="$1" field="$2" package="$3"
  [ -f "$file" ] || return 1
  python3 "$JSONC_EDITOR" has-npm "$file" "$field" "$package" >/dev/null 2>&1
}

remove_managed_npm_entries() {
  local file="$1" field="$2" package="$3" tmp backup mode status
  managed_array_npm_has "$file" "$field" "$package" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'remove npm array entries %s.%s package %s\n' "$file" "$field" "$package"
    return 0
  fi
  tmp="$(mktemp "$(dirname "$file")/.agents-orchestrator-jsonc.XXXXXX")"
  if ! python3 "$JSONC_EDITOR" remove-npm "$file" "$field" "$package" > "$tmp"; then
    rm -f "$tmp"
    die "failed to remove npm package $package from $file"
  fi
  status=0
  python3 "$JSONC_EDITOR" has-npm "$tmp" "$field" "$package" >/dev/null 2>&1 || status=$?
  if [ "$status" -ne 1 ]; then
    rm -f "$tmp"
    die "failed to validate npm package removal in $file"
  fi
  backup="$file.bak"
  cp -f "$file" "$backup"
  mode="$(file_mode "$file")"
  chmod "$mode" "$tmp"
  mv "$tmp" "$file"
  printf 'backup: %s\n' "$backup"
}

manifest_owns_npm_package() {
  local manifest="$1" file="$2" field="$3" package="$4" kind entry_file entry_field value spec
  [ -f "$manifest" ] || return 1
  while IFS=$'\t' read -r kind entry_file entry_field value; do
    [ "$entry_file" = "$file" ] || continue
    [ "$entry_field" = "$field" ] || continue
    case "$kind" in
      managed-array)
        spec="$value"
        managed_array_has "$file" "$field" "$value" || continue
        ;;
      *) continue ;;
    esac
    case "$spec" in
      "$package"|"$package"@*)
        return 0
        ;;
    esac
  done < "$manifest"
  return 1
}

manifest_owns_managed_value() {
  local kind="$1" manifest="$2" file="$3" field="$4" value="$5"
  [ -f "$manifest" ] || return 1
  awk -F '\t' -v k="$kind" -v f="$file" -v p="$field" -v v="$value" '
    $1 == k && $2 == f && $3 == p && $4 == v { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$manifest"
}

file_mode() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then stat -f '%Lp' "$1"; else stat -c '%a' "$1"; fi
}

runtime_install_global() {
  link_component "$REPO_ROOT/global/AGENTS.md" "$TARGET/AGENTS.md" "$1"
  link_component "$REPO_ROOT/standards" "$TARGET/standards" "$1"
}

runtime_post_install() {
  [ "$RELOAD" -eq 1 ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'reload: skipped (dry run)\n'
    return 0
  fi
  reload_running_servers
}

# Validated on OpenCode 1.17.15 and not checked again on 2.x (docs/hot-reload.md):
# POST /global/dispose makes every instance re-read markdown artifacts and project config on its next
# request. It does NOT re-read the global opencode.json[c] (infinite-TTL cache)
# and cannot reload plugin code; any installed plugin-bundle change still needs
# a restart even when --reload is requested.
reload_running_servers() {
  local urls url health reachable=0
  command -v curl >/dev/null 2>&1 || { warn "reload: curl not found; restart OpenCode sessions to apply"; return 0; }
  urls="$(discover_opencode_server_urls)"
  if [ -z "$urls" ]; then
    printf 'reload: no running OpenCode server found; sessions pick changes up on restart\n'
    return 0
  fi
  for url in $urls; do
    health="$(curl -fsS --max-time 2 "$url/global/health" 2>/dev/null || true)"
    case "$health" in
      *'"healthy":true'*) ;;
      *) continue ;;
    esac
    reachable=$((reachable + 1))
    if [ "$(curl -fsS --max-time 5 -X POST "$url/global/dispose" 2>/dev/null || true)" = "true" ]; then
      printf 'reload: disposed instances on %s\n' "$url"
    else
      warn "reload: POST $url/global/dispose failed; restart that OpenCode session to apply"
    fi
  done
  if [ "$reachable" -eq 0 ]; then
    printf 'reload: no healthy OpenCode server found; sessions pick changes up on restart\n'
    return 0
  fi
  printf 'reload: agents, commands, and skills re-read on next request; plugin code changes still need a restart\n'
}

discover_opencode_server_urls() {
  if [ -n "${OPENCODE_RELOAD_URLS:-}" ]; then
    printf '%s\n' "$OPENCODE_RELOAD_URLS" | tr ', ' '\n' | awk 'NF'
    return 0
  fi
  command -v lsof >/dev/null 2>&1 || { warn "reload: lsof not found; set OPENCODE_RELOAD_URLS to reload explicitly"; return 0; }
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null |
    awk '$1 ~ /^opencode/ { sub(/.*:/, "", $9); if ($9 ~ /^[0-9]+$/) print $9 }' |
    sort -un |
    while IFS= read -r port; do printf 'http://127.0.0.1:%s\n' "$port"; done
}

runtime_status_global() {
  local state
  state="$(link_state "$REPO_ROOT/global/AGENTS.md" "$TARGET/AGENTS.md")"
  printf '%s\t%s\t%s\t%s\t%s\n' "-" "global" "AGENTS.md" "-" "$state"
  state="$(link_state "$REPO_ROOT/standards" "$TARGET/standards")"
  printf '%s\t%s\t%s\t%s\t%s\n' "-" "global" "standards" "-" "$state"
}

harness_main "$@"
