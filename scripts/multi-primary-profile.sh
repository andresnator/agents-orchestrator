#!/usr/bin/env bash
# Install the opt-in multi-primary profile into one project's .opencode/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INSTALLER="$REPO_ROOT/installers/opencode.sh"
JSONC_EDITOR="$REPO_ROOT/scripts/jsonc-array.py"

PROFILE_CONTRACT="multi-primary-profile/v1"
PROFILE_DOMAINS="plan,sdd,architecture,sdd-lite,review,common"
PRIMARY_AGENTS="deep-planner architect orchestraitor orchestralite review-coordinator"
MANAGED_SUBAGENT_DEPTH='1'

ACTION=""
PROJECT_ROOT_ARG=""
PROJECT_ROOT=""
TARGET=""
CONFIG_FILE=""
INSTALLER_MANIFEST=""
PROFILE_MANIFEST=""
BREW_TOOLS_OPTION=""

JSON_STATE=""
JSON_VALUE=""
TMP_ONE=""
TMP_TWO=""
TMP_THREE=""

usage() {
  cat <<'EOF'
usage: scripts/multi-primary-profile.sh install|status|uninstall --project-root <dir>
       [--install-brew-tools|--no-install-brew-tools]

Installs or removes the opt-in multi-primary profile only in
<dir>/.opencode. Global OpenCode configuration is never a target.
Project installs skip Homebrew tools unless --install-brew-tools is set.
The profile preserves default_agent and manages only subagent_depth.
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
cleanup() { rm -f "$TMP_ONE" "$TMP_TWO" "$TMP_THREE"; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    sha256sum "$1" | awk '{ print $1 }'
  fi
}

resolve_git_common_dir() {
  local root="$1" common
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  common="$(git -C "$root" rev-parse --git-common-dir)"
  case "$common" in
    /*) (cd -P "$common" && pwd -P) ;;
    *) (cd -P "$root/$common" && pwd -P) ;;
  esac
}

resolve_project_root() {
  [ -n "$PROJECT_ROOT_ARG" ] || die "--project-root is required"
  [ -d "$PROJECT_ROOT_ARG" ] || die "project root does not exist: $PROJECT_ROOT_ARG"
  PROJECT_ROOT="$(cd "$PROJECT_ROOT_ARG" && pwd -P)"
  case "$PROJECT_ROOT" in
    /|"$HOME") die "refusing broad project root: $PROJECT_ROOT" ;;
  esac
  case "$PROJECT_ROOT" in
    *$'\t'*|*$'\n'*) die "project root cannot contain tabs or newlines" ;;
  esac

  local source_common="" target_common=""
  source_common="$(resolve_git_common_dir "$REPO_ROOT" 2>/dev/null || true)"
  target_common="$(resolve_git_common_dir "$PROJECT_ROOT" 2>/dev/null || true)"
  if [ -n "$source_common" ] && [ "$source_common" = "$target_common" ]; then
    die "refusing to install the profile into this repository or one of its worktrees"
  fi

  TARGET="$PROJECT_ROOT/.opencode"
  [ ! -L "$TARGET" ] || die "refusing symlinked project target: $TARGET"
  CONFIG_FILE="$TARGET/opencode.jsonc"
  INSTALLER_MANIFEST="$TARGET/.agents-orchestrator-manifest"
  PROFILE_MANIFEST="$TARGET/.multi-primary-profile-manifest"
}

reject_symlinked_managed_directories() {
  local directory path
  for directory in agents commands skills plugins; do
    path="$TARGET/$directory"
    [ ! -L "$path" ] || die "refusing symlinked managed directory: $path"
  done
}

read_scalar() {
  local file="$1" property="$2" status
  JSON_STATE="absent"
  JSON_VALUE=""
  [ ! -e "$file" ] || [ -f "$file" ] || die "$file must be a regular file"
  [ -f "$file" ] || return 0
  set +e
  JSON_VALUE="$(python3 "$JSONC_EDITOR" get "$file" "$property")"
  status=$?
  set -e
  case "$status" in
    0) JSON_STATE="value" ;;
    1) JSON_STATE="absent"; JSON_VALUE="" ;;
    *) die "cannot read JSONC property '$property' from $file" ;;
  esac
}

render_jsonc_action() {
  local action="$1" input="$2" property="$3" value="$4" output="$5" status
  set +e
  if [ -n "$value" ]; then
    python3 "$JSONC_EDITOR" "$action" "$input" "$property" "$value" > "$output"
  else
    python3 "$JSONC_EDITOR" "$action" "$input" "$property" > "$output"
  fi
  status=$?
  set -e
  case "$status" in
    0|3) ;;
    *) die "failed to $action JSONC property '$property' in $input" ;;
  esac
}

new_tmp() { mktemp "${TMPDIR:-/tmp}/multi-primary-profile.XXXXXX"; }

render_managed_config() {
  TMP_TWO="$(new_tmp)"
  render_jsonc_action set "$CONFIG_FILE" subagent_depth "$MANAGED_SUBAGENT_DEPTH" "$TMP_TWO"
}

render_restored_config() {
  local depth_state="$1" depth_json="$2"
  TMP_TWO="$(new_tmp)"
  if [ "$depth_state" = value ]; then
    render_jsonc_action set "$CONFIG_FILE" subagent_depth "$depth_json" "$TMP_TWO"
  else
    render_jsonc_action remove-property "$CONFIG_FILE" subagent_depth "" "$TMP_TWO"
  fi
}

is_empty_jsonc_object() {
  [ "$(tr -d '[:space:]' < "$1")" = "{}" ]
}

manifest_value() {
  local key="$1"
  awk -F '\t' -v key="$key" '$1 == key { print substr($0, length($1) + 2); exit }' "$PROFILE_MANIFEST"
}

manifest_has_row() {
  local kind="$1" path="$2"
  awk -F '\t' -v kind="$kind" -v path="$path" \
    '$1 == kind && $2 == path { found = 1; exit } END { exit found ? 0 : 1 }' \
    "$INSTALLER_MANIFEST"
}

emit_expected_links() {
  local domain dir file name source old_ifs
  old_ifs="$IFS"
  IFS=,
  for domain in $PROFILE_DOMAINS; do
    for dir in agents commands; do
      [ -d "$REPO_ROOT/domains/$domain/$dir" ] || continue
      find "$REPO_ROOT/domains/$domain/$dir" -maxdepth 1 -type f -name '*.md' | sort |
        while IFS= read -r file; do
          printf '%s\t%s\n' "$TARGET/$dir/$(basename "$file")" "$file"
        done
    done
    if [ -d "$REPO_ROOT/domains/$domain/skills" ]; then
      find "$REPO_ROOT/domains/$domain/skills" -mindepth 1 -maxdepth 1 \( -type l -o -type d \) | sort |
        while IFS= read -r file; do
          name="$(basename "$file")"
          source="$(cd -P "$file" && pwd -P)"
          printf '%s\t%s\n' "$TARGET/skills/$name" "$source"
        done
    fi
    if [ -d "$REPO_ROOT/domains/$domain/plugins" ]; then
      find "$REPO_ROOT/domains/$domain/plugins" -maxdepth 1 -type f -name '*.ts' | sort |
        while IFS= read -r file; do
          printf '%s\t%s\n' "$TARGET/plugins/$(basename "$file")" "$file"
        done
    fi
  done
  IFS="$old_ifs"
  printf '%s\t%s\n' "$TARGET/AGENTS.md" "$REPO_ROOT/global/AGENTS.md"
}

emit_expected_files() {
  local domain file name old_ifs
  old_ifs="$IFS"
  IFS=,
  for domain in $PROFILE_DOMAINS; do
    [ -d "$REPO_ROOT/domains/$domain/external-plugins" ] || continue
    find "$REPO_ROOT/domains/$domain/external-plugins" -maxdepth 1 -type f -name '*.server.json' | sort |
      while IFS= read -r file; do
        name="$(basename "$file" .server.json)"
        printf '%s\t%s\t%s\n' "$TARGET/plugins/$name.js" "$name" "$file"
      done
    if find "$REPO_ROOT/domains/$domain/external-plugins" -maxdepth 1 -type f -name '*.tui.json' | grep -q .; then
      die "the profile does not support TUI descriptors in its selected domains"
    fi
  done
  IFS="$old_ifs"
}

preflight_fresh_destinations() {
  local dest source name descriptor
  while IFS=$'\t' read -r dest source; do
    [ ! -e "$dest" ] && [ ! -L "$dest" ] || die "foreign profile destination exists: $dest"
  done < <(emit_expected_links | sort -u)
  while IFS=$'\t' read -r dest name descriptor; do
    [ ! -e "$dest" ] && [ ! -L "$dest" ] || die "foreign profile destination exists: $dest"
  done < <(emit_expected_files | sort -u)
}

resolve_link_source() {
  local dest="$1" source
  source="$(readlink "$dest")"
  case "$source" in
    /*) printf '%s\n' "$source" ;;
    *) printf '%s/%s\n' "$(cd -P "$(dirname "$dest")" && pwd -P)" "$source" ;;
  esac
}

validate_installer_manifest_ownership() {
  [ -f "$INSTALLER_MANIFEST" ] || die "installer manifest is missing: $INSTALLER_MANIFEST"

  local kind path actual
  while IFS=$'\t' read -r kind path _; do
    [ -n "$kind" ] || continue
    case "$kind" in
      link|file|dir)
        case "$path" in
          "$TARGET"|"$TARGET"/*) ;;
          *) die "global or broad manifest destination: $path" ;;
        esac
        case "$path" in
          */../*|*/./*) die "non-canonical profile manifest destination: $path" ;;
        esac
        ;;
      managed-array|managed-object) die "broad profile manifest contains managed runtime config: $path" ;;
      *) die "foreign installer manifest row: $kind" ;;
    esac

    case "$kind" in
      link)
        [ -L "$path" ] || die "profile-owned link is missing or changed type: $path"
        actual="$(resolve_link_source "$path")"
        case "$actual" in
          "$REPO_ROOT"/*) ;;
          *) die "profile link target escaped this repository: $path" ;;
        esac
        case "$actual" in
          */../*|*/./*) die "non-canonical profile link target: $path" ;;
        esac
        ;;
      file)
        [ -f "$path" ] && [ ! -L "$path" ] || die "profile-owned file is missing or changed type: $path"
        ;;
      dir)
        [ -d "$path" ] && [ ! -L "$path" ] || die "profile-owned directory is missing or changed type: $path"
        ;;
    esac
  done < "$INSTALLER_MANIFEST"

  local primary
  for primary in $PRIMARY_AGENTS; do
    manifest_has_row link "$TARGET/agents/$primary.md" ||
      die "$primary is missing from the saved profile manifest"
    [ -L "$TARGET/agents/$primary.md" ] ||
      die "$primary is missing from the installed profile"
  done
}

validate_installer_contents() {
  validate_installer_manifest_ownership

  local kind path expected actual source name descriptor expected_sha actual_sha

  TMP_THREE="$(new_tmp)"
  emit_expected_links | sort -u > "$TMP_THREE"
  while IFS=$'\t' read -r path expected; do
    manifest_has_row link "$path" || die "profile link is missing from manifest: $path"
    [ -L "$path" ] || die "profile link is not a symlink: $path"
    actual="$(resolve_link_source "$path")"
    [ "$actual" = "$expected" ] || die "profile link target changed: $path"
  done < "$TMP_THREE"
  while IFS=$'\t' read -r kind path _; do
    [ "$kind" != link ] || awk -F '\t' -v path="$path" '$1 == path { found = 1 } END { exit found ? 0 : 1 }' "$TMP_THREE" ||
      die "broad profile link is not in the selected domains: $path"
  done < "$INSTALLER_MANIFEST"

  emit_expected_files | sort -u > "$TMP_THREE"
  while IFS=$'\t' read -r path name descriptor; do
    manifest_has_row file "$path" || die "external profile file is missing from manifest: $path"
    [ -f "$path" ] && [ ! -L "$path" ] || die "external profile file is not regular: $path"
    if [ -n "${AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR:-}" ] &&
      [ -f "$AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR/$name.js" ]; then
      expected_sha="$(sha256_file "$AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR/$name.js")"
    else
      expected_sha="$(jq -er '.sha256' "$descriptor")"
    fi
    actual_sha="$(sha256_file "$path")"
    [ "$actual_sha" = "$expected_sha" ] || die "external profile file is stale: $path"
  done < "$TMP_THREE"
  while IFS=$'\t' read -r kind path _; do
    [ "$kind" != file ] || awk -F '\t' -v path="$path" '$1 == path { found = 1 } END { exit found ? 0 : 1 }' "$TMP_THREE" ||
      die "broad profile file is not in the selected domains: $path"
  done < "$INSTALLER_MANIFEST"

  local primary_count=0 question_owner_count=0 mode question
  emit_expected_links | sort -u | while IFS=$'\t' read -r path source; do
    case "$path" in
      "$TARGET/agents/"*.md)
        mode="$(sed -n '/^mode: /{s/^mode: //;p;q;}' "$source")"
        question="$(awk 'BEGIN{p=0} /^permission:/{p=1;next} p && /^  question:/{sub(/^  question: /, ""); print; exit} p && /^[^ ]/{exit}' "$source")"
        printf '%s\t%s\t%s\n' "$path" "$mode" "$question"
        ;;
    esac
  done > "$TMP_THREE"
  while IFS=$'\t' read -r path mode question; do
    [ "$mode" != primary ] || primary_count=$((primary_count + 1))
    [ "$question" != allow ] || question_owner_count=$((question_owner_count + 1))
    [ -n "$question" ] || die "profile agent omits its question permission: $path"
  done < "$TMP_THREE"
  [ "$primary_count" -eq 5 ] || die "expected exactly five repo-owned primaries, found $primary_count"
  [ "$question_owner_count" -eq 5 ] || die "expected exactly five direct question owners, found $question_owner_count"
  local primary
  for primary in $PRIMARY_AGENTS; do
    grep -Fq "$TARGET/agents/$primary.md" "$TMP_THREE" ||
      die "$primary is missing from the profile"
  done
}

validate_managed_config() {
  read_scalar "$CONFIG_FILE" subagent_depth
  [ "$JSON_STATE" = value ] && [ "$JSON_VALUE" = "$MANAGED_SUBAGENT_DEPTH" ] ||
    die "managed subagent_depth changed in $CONFIG_FILE"
}

validate_profile_manifest() {
  [ -f "$PROFILE_MANIFEST" ] || die "profile manifest is missing: $PROFILE_MANIFEST"
  [ "$(manifest_value contract)" = "$PROFILE_CONTRACT" ] || die "foreign profile manifest contract"
  [ "$(manifest_value project-root)" = "$PROJECT_ROOT" ] || die "global or foreign profile manifest root"
  [ "$(manifest_value target)" = "$TARGET" ] || die "global or foreign profile target"
  [ "$(manifest_value domains)" = "$PROFILE_DOMAINS" ] || die "broad profile domain selection"
  local config_existed target_existed expected_sha actual_sha
  config_existed="$(manifest_value config-existed)"
  case "$config_existed" in 0|1) ;; *) die "invalid config-existed value in profile manifest" ;; esac
  target_existed="$(manifest_value target-existed)"
  case "$target_existed" in ""|0|1) ;; *) die "invalid target-existed value in profile manifest" ;; esac
  [ -f "$INSTALLER_MANIFEST" ] || die "installer manifest is missing"
  expected_sha="$(manifest_value installer-manifest-sha256)"
  actual_sha="$(sha256_file "$INSTALLER_MANIFEST")"
  [ -n "$expected_sha" ] && [ "$expected_sha" = "$actual_sha" ] ||
    die "installer manifest changed or became broad/foreign"
  validate_installer_manifest_ownership
}

write_profile_manifest() {
  local depth_state="$1" depth_json="$2" config_existed="$3" target_existed="$4"
  TMP_THREE="$(mktemp "$TARGET/.multi-primary-profile-manifest.tmp.XXXXXX")"
  {
    printf 'contract\t%s\n' "$PROFILE_CONTRACT"
    printf 'project-root\t%s\n' "$PROJECT_ROOT"
    printf 'target\t%s\n' "$TARGET"
    printf 'domains\t%s\n' "$PROFILE_DOMAINS"
    printf 'config-existed\t%s\n' "$config_existed"
    printf 'target-existed\t%s\n' "$target_existed"
    printf 'previous-subagent-depth-state\t%s\n' "$depth_state"
    printf 'previous-subagent-depth-json\t%s\n' "$depth_json"
    printf 'installer-manifest-sha256\t%s\n' "$(sha256_file "$INSTALLER_MANIFEST")"
  } > "$TMP_THREE"
  mv "$TMP_THREE" "$PROFILE_MANIFEST"
  TMP_THREE=""
}

run_install() {
  local depth_state depth_json config_existed=0 target_existed=0
  local installer_args=(install --domain "$PROFILE_DOMAINS" --target "$TARGET")
  if [ -f "$PROFILE_MANIFEST" ]; then
    validate_profile_manifest
    validate_managed_config
    depth_state="$(manifest_value previous-subagent-depth-state)"
    depth_json="$(manifest_value previous-subagent-depth-json)"
    config_existed="$(manifest_value config-existed)"
    target_existed="$(manifest_value target-existed)"
    [ -n "$target_existed" ] || target_existed=1
  else
    [ ! -e "$INSTALLER_MANIFEST" ] || die "foreign installer manifest already exists: $INSTALLER_MANIFEST"
    preflight_fresh_destinations
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then target_existed=1; fi
    [ ! -e "$CONFIG_FILE" ] || config_existed=1
    read_scalar "$CONFIG_FILE" subagent_depth
    depth_state="$JSON_STATE"; depth_json="$JSON_VALUE"
  fi

  render_managed_config
  [ -z "$BREW_TOOLS_OPTION" ] || installer_args+=("$BREW_TOOLS_OPTION")
  "$INSTALLER" "${installer_args[@]}"
  validate_installer_contents
  mkdir -p "$TARGET"
  mv "$TMP_TWO" "$CONFIG_FILE"
  TMP_TWO=""
  write_profile_manifest "$depth_state" "$depth_json" "$config_existed" "$target_existed"
  validate_managed_config
  printf 'status: installed\nproject-root: %s\ndefault_agent: preserved\nsubagent_depth: 1\n' "$PROJECT_ROOT"
}

run_status() {
  if [ ! -f "$PROFILE_MANIFEST" ]; then
    [ ! -e "$INSTALLER_MANIFEST" ] || die "foreign installer manifest exists without the profile"
    printf 'status: not installed\nproject-root: %s\n' "$PROJECT_ROOT"
    return 1
  fi
  validate_profile_manifest
  validate_managed_config
  printf 'status: installed\nproject-root: %s\ndefault_agent: preserved\nsubagent_depth: 1\nrepo-owned primaries: 5\nquestion owners: 5\n' "$PROJECT_ROOT"
}

run_uninstall() {
  [ -f "$PROFILE_MANIFEST" ] || die "profile is not installed for $PROJECT_ROOT"
  validate_profile_manifest
  validate_managed_config

  local depth_state depth_json config_existed target_existed
  depth_state="$(manifest_value previous-subagent-depth-state)"
  depth_json="$(manifest_value previous-subagent-depth-json)"
  config_existed="$(manifest_value config-existed)"
  target_existed="$(manifest_value target-existed)"
  [ -n "$target_existed" ] || target_existed=1
  render_restored_config "$depth_state" "$depth_json"

  "$INSTALLER" uninstall --target "$TARGET"
  if [ "$config_existed" = 0 ] && is_empty_jsonc_object "$TMP_TWO"; then
    rm -f "$CONFIG_FILE"
  else
    mkdir -p "$TARGET"
    mv "$TMP_TWO" "$CONFIG_FILE"
    TMP_TWO=""
  fi
  rm -f "$PROFILE_MANIFEST"
  if [ "$target_existed" = 0 ]; then rmdir "$TARGET" 2>/dev/null || true; fi
  printf 'status: uninstalled\nproject-root: %s\n' "$PROJECT_ROOT"
}

main() {
  [ "$#" -gt 0 ] || { usage >&2; exit 1; }
  case "$1" in
    install|status|uninstall) ACTION="$1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown action: $1" ;;
  esac
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-root)
        [ "$#" -ge 2 ] || die "--project-root requires a directory"
        PROJECT_ROOT_ARG="$2"
        shift
        ;;
      --install-brew-tools)
        [ "$BREW_TOOLS_OPTION" != "--no-install-brew-tools" ] ||
          die "--install-brew-tools and --no-install-brew-tools cannot be combined"
        BREW_TOOLS_OPTION="$1"
        ;;
      --no-install-brew-tools)
        [ "$BREW_TOOLS_OPTION" != "--install-brew-tools" ] ||
          die "--install-brew-tools and --no-install-brew-tools cannot be combined"
        BREW_TOOLS_OPTION="$1"
        ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  if [ "$ACTION" != "install" ] && [ -n "$BREW_TOOLS_OPTION" ]; then
    die "Brew tool options are valid only with install"
  fi

  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  command -v jq >/dev/null 2>&1 || die "jq is required"
  trap cleanup EXIT INT TERM
  resolve_project_root
  reject_symlinked_managed_directories
  case "$ACTION" in
    install) run_install ;;
    status) run_status ;;
    uninstall) run_uninstall ;;
  esac
}

main "$@"
