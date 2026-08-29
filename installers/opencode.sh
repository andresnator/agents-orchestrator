#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034  # MANIFEST_ROOT/DEST_PATH are read by lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installers/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

TARGET=""
OPENCODE_CONFIG_FILE=""
MIN_EXTERNAL_OPENCODE_VERSION="1.17.15"
RETIRED_MODEL_TUI_SPECS="./plugins/model-configurator/tui.js ./plugins/model-configurator.tsx"
JSONC_EDITOR="$REPO_ROOT/scripts/jsonc-array.py"
BREW_TOOLS_CATALOG="$SCRIPT_DIR/brew-tools.tsv"
INSTALL_TX_DIR=""
INSTALL_TX_RECORDS=""
EXTERNAL_STAGE_DIR=""
SELECTED_BREW_TOOLS=""

runtime_usage() {
  cat <<'EOF'
Usage:
  opencode.sh <install|uninstall|status> [--domain d1,d2] [--status s1,s2]
              [--project] [--target DIR] [--dry-run] [--force] [--reload]
              [--install-brew-tools|--no-install-brew-tools]

Actions:
  install     Sync selected domain components into an OpenCode target. Repository
              components are symlinked; external plugin bundles are downloaded
              from commit-pinned GitHub sources and SHA-256 verified. npm server
              and TUI plugins are registered by exact package version in the
              matching OpenCode config.
              Always links global/AGENTS.md to $TARGET/AGENTS.md (global rules),
              regardless of --domain/--status filters. A pre-existing foreign
              AGENTS.md in the target is skipped with a warning unless --force.
  uninstall   Remove manifest-owned links, files, config values, and empty directories.
  status      List selected components and their target state.

Targets:
  default      ~/.config/opencode
  --project   ./.opencode from the current working directory
  --target    Explicit alternate target, useful for tests and scratch installs

Filters:
  --domain    Comma-separated domains, or all.
              Domains are discovered dynamically from domains/
              (currently: architecture, common, docs, learning, meta, plan,
              orchestration, review).
              Exclusive skills live in their domain; shared skills use relative
              symlinks to the top-level skills/ directory.
  --status    Comma-separated skill lifecycle states, or all.
              Valid statuses: backlog, in-progress, testing, done.
              Agents, commands, plugins, external plugins, and TUI plugins are not
              status-filtered because
              OpenCode frontmatter for executable components cannot carry
              repository-only metadata.

Defaults:
  --domain all
  --status all
  Brew tools enabled for the default global target; disabled with --project
  or --target. Explicit Brew tool options override that target-based default.

Options:
  --dry-run   Print planned mkdir/link/download/rm/manifest actions without changing files.
  --force     Replace an existing non-matching destination symlink/file during install.
  --reload    After a committed install, POST /global/dispose to running OpenCode
              servers so re-installed agents, commands, and skills are re-read
              without a restart. Servers come from OPENCODE_RELOAD_URLS
              (comma/space-separated base URLs) or lsof discovery on localhost.
              Best-effort: never fails the install. Plugin code changes
              (including TUI plugins) still require an OpenCode restart.
  --install-brew-tools
              Install missing Homebrew formulas required by selected components.
              Homebrew or formula failures warn and do not fail the OpenCode sync.
  --no-install-brew-tools
              Skip Homebrew formula installation, including for the global target.
  -h, --help  Show this help.

Examples:
  installers/opencode.sh install
      Install every domain and every lifecycle state into ~/.config/opencode.

  installers/opencode.sh install --project
      Install into ./.opencode for the current project.

  installers/opencode.sh install --project --install-brew-tools
      Install project components plus their missing Homebrew tools.

  installers/opencode.sh install --no-install-brew-tools
      Install globally without managing Homebrew tools.

  installers/opencode.sh install --domain plan --status done,testing
      Install only done/testing planning components.

  installers/opencode.sh install --domain orchestration --target /tmp/opencode-test --dry-run
      Preview direct and SDD execution without Review.

  installers/opencode.sh install --domain review --target /tmp/opencode-review --dry-run
      Preview Judgment and Defend without Orchestration.

  installers/opencode.sh status --domain meta
      Show meta components and link state in the default target.

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
  MANIFEST_ROOT="$TARGET"
}

runtime_ensure_dirs() {
  ensure_dir "$TARGET/agents" "$1"
  ensure_dir "$TARGET/commands" "$1"
  ensure_dir "$TARGET/skills" "$1"
  ensure_dir "$TARGET/plugins" "$1"
}

# File plugin types install into OpenCode's plugin folder. npm plugins register
# in the matching OpenCode config.
runtime_dest() {
  case "$1" in
    external-server-plugins) DEST_PATH="$TARGET/plugins/$2.js" ;;
    external-tui-plugins) DEST_PATH="$TARGET/plugins/$2/tui.js" ;;
    npm-server-plugins) DEST_PATH="$OPENCODE_CONFIG_FILE" ;;
    npm-tui-plugins) DEST_PATH="$TARGET/tui.json" ;;
    tui-plugins) DEST_PATH="$TARGET/plugins/$2" ;;
    *) DEST_PATH="$TARGET/$1/$2" ;;
  esac
}

external_descriptor_field() {
  jq -er --arg field "$2" '.[$field] // empty' "$1"
}

external_descriptor_kind() {
  case "$1" in
    external-server-plugins) printf 'server' ;;
    external-tui-plugins) printf 'tui' ;;
    *) return 1 ;;
  esac
}

external_stage_path() {
  local type="$1" name="$2" kind
  kind="$(external_descriptor_kind "$type")"
  printf '%s/%s-%s.js\n' "$EXTERNAL_STAGE_DIR" "$kind" "$name"
}

validate_external_descriptor() {
  local type="$1" name="$2" descriptor="$3" kind
  kind="$(external_descriptor_kind "$type")"
  jq -e --arg name "$name" --arg kind "$kind" '
    .schemaVersion == 1 and
    .name == $name and
    .kind == $kind and
    (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    (.repository | type == "string" and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) and
    (.commit | type == "string" and test("^[0-9a-f]{40}$")) and
    (.artifact | type == "string" and length > 0 and (startswith("/") | not) and (split("/") | all(. != ".."))) and
    (.sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    ((.profileSource // null) as $profile |
      $profile == null or
      ($kind == "tui" and ($profile | type == "string" and length > 0 and (startswith("/") | not) and (split("/") | all(. != "..")))))
  ' "$descriptor" >/dev/null 2>&1 || die "$descriptor: invalid external plugin descriptor"
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

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    sha256sum "$1" | awk '{ print $1 }'
  fi
}

external_test_artifact() {
  local name="$1" test_dir="${AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR:-}"
  [ -n "$test_dir" ] || return 1
  [ -f "$test_dir/$name.js" ] || return 1
  printf '%s\n' "$test_dir/$name.js"
}

external_expected_sha() {
  local name="$1" descriptor="$2" test_artifact
  if test_artifact="$(external_test_artifact "$name" 2>/dev/null)"; then
    sha256_file "$test_artifact"
  else
    external_descriptor_field "$descriptor" sha256
  fi
}

external_artifact_url() {
  local descriptor="$1" repository commit artifact
  repository="$(external_descriptor_field "$descriptor" repository)"
  commit="$(external_descriptor_field "$descriptor" commit)"
  artifact="$(external_descriptor_field "$descriptor" artifact)"
  printf 'https://raw.githubusercontent.com/%s/%s/%s\n' "$repository" "$commit" "$artifact"
}

external_tui_spec() {
  printf './plugins/%s/tui.js' "$1"
}

external_file_state() {
  local descriptor="$1" name="$2" dest="$3" expected actual
  if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -f "$dest" ]; }; then
    printf 'foreign'
    return 0
  fi
  if [ ! -f "$dest" ]; then
    printf 'not installed'
    return 0
  fi
  expected="$(external_expected_sha "$name" "$descriptor")"
  actual="$(sha256_file "$dest")"
  if [ "$actual" = "$expected" ]; then printf 'installed'; else printf 'stale'; fi
}

cleanup_external_stage() {
  if [ -n "$EXTERNAL_STAGE_DIR" ] && [ -d "$EXTERNAL_STAGE_DIR" ]; then
    rm -rf "$EXTERNAL_STAGE_DIR"
  fi
  EXTERNAL_STAGE_DIR=""
}

stage_external_artifacts() {
  local selected="$1" type name domain status descriptor dest stage expected actual source url
  [ "$DRY_RUN" -eq 0 ] || return 0
  EXTERNAL_STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-orchestrator-external.XXXXXX")"
  trap cleanup_external_stage EXIT

  while IFS=$'\t' read -r type name domain status descriptor; do
    case "$type" in external-server-plugins|external-tui-plugins) ;; *) continue ;; esac
    stage="$(external_stage_path "$type" "$name")"
    expected="$(external_expected_sha "$name" "$descriptor")"
    DEST_PATH=""
    runtime_dest "$type" "$name"
    dest="$DEST_PATH"

    if [ -f "$dest" ] && [ ! -L "$dest" ] && [ "$(sha256_file "$dest")" = "$expected" ]; then
      cp "$dest" "$stage"
    elif source="$(external_test_artifact "$name" 2>/dev/null)"; then
      cp "$source" "$stage"
    else
      url="$(external_artifact_url "$descriptor")"
      curl -fsSL --retry 2 --connect-timeout 10 --max-time 90 "$url" -o "$stage" || {
        cleanup_external_stage
        die "failed to download external plugin $name from $url"
      }
    fi

    actual="$(sha256_file "$stage")"
    if [ "$actual" != "$expected" ]; then
      cleanup_external_stage
      die "$name: external artifact checksum mismatch (expected $expected, found $actual)"
    fi
  done < "$selected"
}

install_external_artifact() {
  local type="$1" name="$2" descriptor="$3" dest="$4" manifest="$5" stage url
  if [ "$DRY_RUN" -eq 1 ]; then
    url="$(external_artifact_url "$descriptor")"
    printf 'download %s -> %s\n' "$url" "$dest"
    printf 'file\t%s\n' "$dest" >> "$manifest"
    return 0
  fi
  stage="$(external_stage_path "$type" "$name")"
  [ -f "$stage" ] || die "staged external plugin missing: $stage"
  generate_file "$stage" "$dest" "$manifest" copy_source
}

install_external_tui_profiles() {
  local descriptor="$1" dest="$2" manifest="$3" profile_source profiles_dest profile
  profile_source="$(external_descriptor_field "$descriptor" profileSource 2>/dev/null || true)"
  [ -n "$profile_source" ] || return 0
  profiles_dest="$(dirname "$dest")/profiles"
  prepare_tui_directory "$profiles_dest" "$manifest"
  for profile in "$REPO_ROOT/$profile_source"/*.json; do
    [ -f "$profile" ] || continue
    install_tui_source "$profile" "$profiles_dest/$(basename "$profile")" "$manifest"
  done
}

tui_spec_for_dest() {
  local dest="$1"
  case "$dest" in
    "$TARGET"/*) printf './%s' "${dest#"$TARGET"/}" ;;
    *) die "TUI entry is outside the OpenCode target: $dest" ;;
  esac
}

runtime_install_component() {
  local type="$1" name="$2" src="$3" dest="$4" manifest="$5" companion support spec package legacy_spec
  case "$type" in
    external-server-plugins)
      install_external_artifact "$type" "$name" "$src" "$dest" "$manifest"
      return 0
      ;;
    external-tui-plugins)
      prepare_tui_directory "$(dirname "$dest")" "$manifest"
      install_external_artifact "$type" "$name" "$src" "$dest" "$manifest"
      install_external_tui_profiles "$src" "$dest" "$manifest"
      maybe_fail_install "after-links"
      spec="$(external_tui_spec "$name")"
      ensure_managed_array_entry "$TARGET/tui.json" plugin "$spec" "$manifest"
      maybe_fail_install "after-managed-array"
      return 0
      ;;
    npm-server-plugins)
      maybe_fail_install "after-links"
      package="$(npm_plugin_package "$src")"
      spec="$(npm_plugin_spec "$src")"
      if ! managed_array_has "$dest" plugin "$spec" &&
        managed_array_npm_has "$dest" plugin "$package"; then
        remove_managed_npm_entries "$dest" plugin "$package"
      fi
      ensure_managed_array_entry "$dest" plugin "$spec" "$manifest"
      maybe_fail_install "after-managed-array"
      return 0
      ;;
    npm-tui-plugins)
      maybe_fail_install "after-links"
      package="$(npm_plugin_package "$src")"
      spec="$(npm_plugin_spec "$src")"
      if ! managed_array_has "$dest" plugin "$spec" &&
        managed_array_npm_has "$dest" plugin "$package"; then
        remove_managed_npm_entries "$dest" plugin "$package"
      fi
      for legacy_spec in $RETIRED_MODEL_TUI_SPECS; do
        if managed_array_has "$dest" plugin "$legacy_spec" &&
          { [ "$FORCE" -eq 1 ] || manifest_owns_managed_value managed-array "$OLD_MANIFEST" "$dest" plugin "$legacy_spec"; }; then
          remove_managed_array_entry "$dest" plugin "$legacy_spec"
        fi
      done
      ensure_managed_array_entry "$dest" plugin "$spec" "$manifest"
      maybe_fail_install "after-managed-array"
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
    for support in "$companion"/*.ts "$companion"/*.tsx; do
      [ -f "$support" ] || continue
      install_tui_source "$support" "${dest%.tsx}/$(basename "$support")" "$manifest"
    done
  fi
  maybe_fail_install "after-links"
  spec="$(tui_spec_for_dest "$dest")"
  ensure_managed_array_entry "$TARGET/tui.json" plugin "$spec" "$manifest"
  maybe_fail_install "after-managed-array"
}

runtime_component_state() {
  local type="$1" name="$2" src="$3" dest="$4" state companion companion_state compatibility support support_state
  local profile profile_source profiles_dest spec version package

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

  case "$type" in
    external-server-plugins|external-tui-plugins)
      if ! command -v jq >/dev/null 2>&1; then
        printf 'unavailable (jq required)'
        return 0
      fi
      if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
        printf 'unavailable (shasum or sha256sum required)'
        return 0
      fi
      if [ "$type" = "external-tui-plugins" ] && ! command -v python3 >/dev/null 2>&1; then
        printf 'unavailable (python3 required)'
        return 0
      fi
      state="$(external_file_state "$src" "$name" "$dest")"
      version="$(external_descriptor_field "$src" version)"
      [ "$type" = "external-tui-plugins" ] || {
        if [ "$state" = "installed" ]; then
          compatibility="$(opencode_compatibility)"
          if [ "$compatibility" = "compatible" ]; then
            printf 'installed@%s' "$version"
          else
            printf 'installed@%s; %s' "$version" "$compatibility"
          fi
        else
          printf '%s' "$state"
        fi
        return 0
      }

      companion_state="installed"
      profile_source="$(external_descriptor_field "$src" profileSource 2>/dev/null || true)"
      if [ -n "$profile_source" ]; then
        profiles_dest="$(dirname "$dest")/profiles"
        for profile in "$REPO_ROOT/$profile_source"/*.json; do
          [ -f "$profile" ] || continue
          support_state="$(file_state "$profile" "$profiles_dest/$(basename "$profile")" copy_source)"
          [ "$support_state" = "generated" ] || companion_state="$support_state"
        done
      fi
      spec="$(external_tui_spec "$name")"
      if [ "$state" = "installed" ] && [ "$companion_state" = "installed" ] &&
        managed_array_has "$TARGET/tui.json" plugin "$spec"; then
        compatibility="$(opencode_compatibility)"
        if [ "$compatibility" = "compatible" ]; then
          printf 'installed+registered@%s' "$version"
        else
          printf 'installed+registered@%s; %s' "$version" "$compatibility"
        fi
      elif [ "$state" = "foreign" ] || [ "$companion_state" = "foreign" ]; then
        printf 'foreign'
      elif [ "$state" = "stale" ] || [ "$companion_state" = "stale" ]; then
        printf 'stale'
      else
        printf 'not installed'
      fi
      return 0
      ;;
  esac

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
  fi
  spec="$(tui_spec_for_dest "$dest")"
  if [ "$state" = "generated" ] && [ "$companion_state" = "generated" ] &&
    managed_array_has "$TARGET/tui.json" plugin "$spec"; then
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

preflight_external_source() {
  local descriptor="$1" name="$2" dest="$3" expected actual
  expected="$(external_expected_sha "$name" "$descriptor")"
  if [ -L "$dest" ] || [ -d "$dest" ]; then
    manifest_owns_file "$OLD_MANIFEST" "$dest" && return 0
    [ "$FORCE" -eq 1 ] || die "$dest exists and is not an installer-owned external plugin file"
    return 0
  fi
  [ -f "$dest" ] || return 0
  actual="$(sha256_file "$dest")"
  [ "$actual" != "$expected" ] || return 0
  manifest_owns_file "$OLD_MANIFEST" "$dest" && return 0
  [ "$FORCE" -eq 1 ] || die "$dest exists and does not match the pinned external plugin artifact"
}

brew_tools_enabled() {
  case "$BREW_TOOLS_MODE" in
    enabled) return 0 ;;
    disabled) return 1 ;;
    auto) [ "$PROJECT_TARGET" -eq 0 ] && [ -z "$TARGET_ARG" ] ;;
    *) die "invalid Brew tools mode: $BREW_TOOLS_MODE" ;;
  esac
}

validate_brew_tool_token() {
  local catalog_line="$1" field_name="$2" value="$3"
  case "$value" in
    ""|*[!A-Za-z0-9._+/@-]*)
      die "$BREW_TOOLS_CATALOG:$catalog_line: invalid $field_name: $value"
      ;;
  esac
}

validate_brew_tools_catalog() {
  local line_number=0 component_type component_name command_name formula extra conflict
  [ -f "$BREW_TOOLS_CATALOG" ] || die "Brew tools catalog not found: $BREW_TOOLS_CATALOG"

  while IFS=$'\t' read -r component_type component_name command_name formula extra; do
    line_number=$((line_number + 1))
    [ -n "$component_type" ] || continue
    [ "${component_type:0:1}" != "#" ] || continue
    [ -z "$extra" ] || die "$BREW_TOOLS_CATALOG:$line_number: expected four tab-separated fields"
    validate_brew_tool_token "$line_number" "component type" "$component_type"
    validate_brew_tool_token "$line_number" "component name" "$component_name"
    validate_brew_tool_token "$line_number" "command" "$command_name"
    validate_brew_tool_token "$line_number" "formula" "$formula"
  done < "$BREW_TOOLS_CATALOG"

  conflict="$(awk -F '\t' '
    $0 !~ /^#/ && NF {
      if (formula[$3] != "" && formula[$3] != $4) { print $3; exit }
      formula[$3] = $4
    }
  ' "$BREW_TOOLS_CATALOG")"
  [ -z "$conflict" ] || die "$BREW_TOOLS_CATALOG: command maps to multiple formulas: $conflict"
}

select_brew_tools() {
  local selected="$1" component_type component_name command_name formula extra
  SELECTED_BREW_TOOLS=""
  brew_tools_enabled || return 0
  validate_brew_tools_catalog

  SELECTED_BREW_TOOLS="$(
    while IFS=$'\t' read -r component_type component_name command_name formula extra; do
      [ -n "$component_type" ] || continue
      [ "${component_type:0:1}" != "#" ] || continue
      if awk -F '\t' -v type="$component_type" -v name="$component_name" \
        '$1 == type && $2 == name { found = 1; exit } END { exit found ? 0 : 1 }' "$selected"; then
        printf '%s\t%s\n' "$command_name" "$formula"
      fi
    done < "$BREW_TOOLS_CATALOG" | sort -u
  )"
}

install_selected_brew_tools() {
  local command_name formula brew_binary missing_formulas=""
  [ -n "$SELECTED_BREW_TOOLS" ] || return 0

  if [ "$DRY_RUN" -eq 1 ]; then
    while IFS=$'\t' read -r command_name formula; do
      command -v "$command_name" >/dev/null 2>&1 || printf 'brew install %s\n' "$formula"
    done <<EOF
$SELECTED_BREW_TOOLS
EOF
    return 0
  fi

  brew_binary="$(command -v brew || true)"
  if [ -z "$brew_binary" ]; then
    while IFS=$'\t' read -r command_name formula; do
      command -v "$command_name" >/dev/null 2>&1 && continue
      missing_formulas="${missing_formulas}${missing_formulas:+, }$formula"
    done <<EOF
$SELECTED_BREW_TOOLS
EOF
    [ -z "$missing_formulas" ] || warn "Homebrew not found; skipped required formulas: $missing_formulas"
    return 0
  fi

  while IFS=$'\t' read -r command_name formula; do
    command -v "$command_name" >/dev/null 2>&1 && continue
    if "$brew_binary" install "$formula"; then
      command -v "$command_name" >/dev/null 2>&1 ||
        warn "$formula installed but $command_name is not available on PATH"
    else
      warn "brew install $formula failed; $command_name remains unavailable"
    fi
  done <<EOF
$SELECTED_BREW_TOOLS
EOF
}

runtime_pre_install() {
  local selected="$1" type name domain status src dest companion support profile profile_source profiles_dest
  local package spec legacy_spec
  local has_external=0 has_npm_server=0 has_npm_tui=0 has_npm=0 has_tui=0 has_managed_config=0
  select_brew_tools "$selected"
  awk -F '\t' '$1 == "external-server-plugins" || $1 == "external-tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_external=1
  awk -F '\t' '$1 == "npm-server-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_npm_server=1
  awk -F '\t' '$1 == "npm-tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_npm_tui=1
  awk -F '\t' '$1 == "tui-plugins" || $1 == "external-tui-plugins" || $1 == "npm-tui-plugins" { found = 1 } END { exit found ? 0 : 1 }' "$selected" && has_tui=1
  [ "$has_npm_server" -eq 0 ] && [ "$has_npm_tui" -eq 0 ] || has_npm=1
  [ "$has_npm_server" -eq 0 ] && [ "$has_tui" -eq 0 ] || has_managed_config=1

  if [ "$has_external" -eq 1 ] || [ "$has_npm" -eq 1 ]; then
    command -v jq >/dev/null 2>&1 || die "jq is required to validate external plugin descriptors"
  fi
  if [ "$has_external" -eq 1 ]; then
    if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
      die "shasum or sha256sum is required to verify external plugin artifacts"
    fi
    if [ -z "${AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR:-}" ]; then
      command -v curl >/dev/null 2>&1 || die "curl is required to download external plugin artifacts"
    else
      [ -d "$AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR" ] ||
        die "test external artifact directory not found: $AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR"
    fi
  fi
  if [ "$has_external" -eq 1 ] || [ "$has_npm" -eq 1 ] || [ "$has_tui" -eq 1 ]; then
    check_opencode_version
  fi
  if [ "$has_managed_config" -eq 1 ]; then
    command -v python3 >/dev/null 2>&1 || die "python3 is required to preserve OpenCode config comments"
    [ -f "$JSONC_EDITOR" ] || die "JSONC editor not found: $JSONC_EDITOR"
    validate_managed_files "$has_tui" "$has_npm_server"
  fi

  while IFS=$'\t' read -r type name domain status src; do
    DEST_PATH=""
    runtime_dest "$type" "$name"
    dest="$DEST_PATH"
    case "$type" in
      external-server-plugins|external-tui-plugins)
        if [ -n "${AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR:-}" ]; then
          [ -f "$AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR/$name.js" ] ||
            die "test external artifact not found: $AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR/$name.js"
        fi
        validate_external_descriptor "$type" "$name" "$src"
        preflight_external_source "$src" "$name" "$dest"
        if [ "$type" = "external-tui-plugins" ]; then
          preflight_tui_directory "$(dirname "$dest")"
          profile_source="$(external_descriptor_field "$src" profileSource 2>/dev/null || true)"
          if [ -n "$profile_source" ]; then
            [ -d "$REPO_ROOT/$profile_source" ] || die "$src: profileSource does not exist: $profile_source"
            profiles_dest="$(dirname "$dest")/profiles"
            preflight_tui_directory "$profiles_dest"
            for profile in "$REPO_ROOT/$profile_source"/*.json; do
              [ -f "$profile" ] || continue
              preflight_tui_source "$profile" "$profiles_dest/$(basename "$profile")"
            done
          fi
        fi
        ;;
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
        if ! managed_array_has "$dest" plugin "$spec" &&
          managed_array_npm_has "$dest" plugin "$package" &&
          [ "$FORCE" -ne 1 ] &&
          ! manifest_owns_npm_package "$OLD_MANIFEST" "$dest" plugin "$package"; then
          die "$dest already configures npm package $package; use --force to replace it"
        fi
        for legacy_spec in $RETIRED_MODEL_TUI_SPECS; do
          if managed_array_has "$dest" plugin "$legacy_spec" &&
            [ "$FORCE" -ne 1 ] &&
            ! manifest_owns_managed_value managed-array "$OLD_MANIFEST" "$dest" plugin "$legacy_spec"; then
            die "$dest contains foreign legacy Models Presets entry $legacy_spec; remove it or use --force"
          fi
        done
        ;;
      tui-plugins)
        preflight_tui_source "$src" "$dest"
        companion="${src%.tsx}"
        if [ -d "$companion" ]; then
          preflight_tui_directory "${dest%.tsx}"
          for support in "$companion"/*.ts "$companion"/*.tsx; do
            [ -f "$support" ] || continue
            preflight_tui_source "$support" "${dest%.tsx}/$(basename "$support")"
          done
        fi
        ;;
    esac
  done < "$selected"

  [ "$has_external" -eq 0 ] || stage_external_artifacts "$selected"
}

runtime_remove_managed_entry() {
  local kind="$1" file="$2" field="$3" value="$4"
  case "$kind" in
    managed-array) remove_managed_array_entry "$file" "$field" "$value" ;;
    managed-array-json) remove_managed_array_json_entry "$file" "$field" "$value" ;;
    managed-object) remove_managed_object_entry "$file" "$field" "$value" ;;
  esac
}

runtime_begin_install() {
  local selected="$1" manifest="$2" type name domain status src companion kind owned_path field value profile_source
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
    case "$type" in
      tui-plugins)
        companion="${src%.tsx}"
        [ ! -d "$companion" ] || snapshot_install_path "${DEST_PATH%.tsx}"
        ;;
      external-tui-plugins)
        snapshot_install_path "$(dirname "$DEST_PATH")"
        profile_source="$(external_descriptor_field "$src" profileSource 2>/dev/null || true)"
        [ -z "$profile_source" ] || snapshot_install_path "$(dirname "$DEST_PATH")/profiles"
        ;;
    esac
  done < "$selected"
  snapshot_install_path "$TARGET/AGENTS.md"
  if [ -f "$manifest" ]; then
    while IFS=$'\t' read -r kind owned_path field value; do
      case "$kind" in
        link|file) snapshot_install_path "$owned_path" ;;
        managed-array|managed-array-json|managed-object)
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
  cleanup_external_stage
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
    printf 'opencode >= %s is required for external and TUI plugins' "$MIN_EXTERNAL_OPENCODE_VERSION"
    return 0
  fi
  version="$($binary --version 2>/dev/null | tr -d '[:space:]')"
  if version_at_least "$version" "$MIN_EXTERNAL_OPENCODE_VERSION"; then
    printf 'compatible'
  else
    printf 'opencode >= %s is required for external and TUI plugins (found %s)' "$MIN_EXTERNAL_OPENCODE_VERSION" "${version:-unknown}"
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
  local file="$1" status=0
  [ -e "$file" ] || return 0
  python3 "$JSONC_EDITOR" has "$file" plugin "__agents_orchestrator_validation_probe__" >/dev/null || status=$?
  [ "$status" -ne 2 ] || die "$file is not valid supported JSONC"
}

validate_managed_files() {
  local validate_tui="$1" validate_server="$2"
  if [ "$validate_tui" -eq 1 ]; then
    validate_managed_jsonc_file "$TARGET/tui.json"
  fi
  if [ "$validate_server" -eq 1 ]; then
    validate_managed_jsonc_file "$OPENCODE_CONFIG_FILE"
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

ensure_managed_array_json_entry() {
  local file="$1" field="$2" value="$3" manifest="$4" owns=0
  manifest_owns_managed_value managed-array-json "$OLD_MANIFEST" "$file" "$field" "$value" && owns=1
  if ! managed_array_json_has "$file" "$field" "$value"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'add managed JSON array entry %s.%s = %s\n' "$file" "$field" "$value"
    else
      rewrite_managed_array_json "$file" "$field" "$value" add-json
    fi
    owns=1
  fi
  [ "$owns" -eq 0 ] || printf 'managed-array-json\t%s\t%s\t%s\n' "$file" "$field" "$value" >> "$manifest"
}

remove_managed_array_json_entry() {
  local file="$1" field="$2" value="$3"
  managed_array_json_has "$file" "$field" "$value" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'remove managed JSON array entry %s.%s = %s\n' "$file" "$field" "$value"
  else
    rewrite_managed_array_json "$file" "$field" "$value" remove-json
  fi
}

managed_array_json_has() {
  local file="$1" field="$2" value="$3"
  [ -f "$file" ] || return 1
  python3 "$JSONC_EDITOR" has-json "$file" "$field" "$value" >/dev/null 2>&1
}

rewrite_managed_array_json() {
  local file="$1" field="$2" value="$3" action="$4" tmp backup mode status expected
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp "$(dirname "$file")/.agents-orchestrator-jsonc.XXXXXX")"
  if ! python3 "$JSONC_EDITOR" "$action" "$file" "$field" "$value" > "$tmp"; then
    rm -f "$tmp"
    die "failed to $action managed JSON value in $file"
  fi
  case "$action" in
    add-json) expected=0 ;;
    remove-json) expected=1 ;;
    *) rm -f "$tmp"; die "unsupported managed JSON array action: $action" ;;
  esac
  status=0
  python3 "$JSONC_EDITOR" has-json "$tmp" "$field" "$value" >/dev/null 2>&1 || status=$?
  if [ "$status" -eq 2 ] || [ "$status" -ne "$expected" ]; then
    rm -f "$tmp"
    die "failed to validate managed JSON value in $file"
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
      managed-array-json)
        spec="$(printf '%s' "$value" | jq -er 'if type == "array" and (.[0] | type) == "string" then .[0] else empty end' 2>/dev/null || true)"
        managed_array_json_has "$file" "$field" "$value" || continue
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

runtime_post_install() {
  install_selected_brew_tools
  [ "$RELOAD" -eq 1 ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'reload: skipped (dry run)\n'
    return 0
  fi
  reload_running_servers
}

# Validated on OpenCode 1.17.15 (docs/hot-reload.md): POST /global/dispose makes
# every instance re-read markdown artifacts and project config on its next
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
}

harness_main "$@"
