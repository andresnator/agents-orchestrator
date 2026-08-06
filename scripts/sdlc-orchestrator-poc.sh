#!/usr/bin/env bash
# Install the opt-in SDLC orchestrator profile into one project's .opencode/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INSTALLER="$REPO_ROOT/installers/opencode.sh"
JSONC_EDITOR="$REPO_ROOT/scripts/jsonc-array.py"

PROFILE_CONTRACT="sdlc-orchestrator-poc-profile/v1"
PROFILE_DOMAINS="sdlc,plan,sdd,architecture,sdd-lite,common"
MANAGED_DEFAULT_AGENT='"sdlc-orchestrator"'
MANAGED_SUBAGENT_DEPTH='2'

ACTION=""
PROJECT_ROOT_ARG=""
PROJECT_ROOT=""
TARGET=""
CONFIG_FILE=""
INSTALLER_MANIFEST=""
PROFILE_MANIFEST=""

JSON_STATE=""
JSON_VALUE=""
TMP_ONE=""
TMP_TWO=""
TMP_THREE=""

usage() {
  cat <<'EOF'
usage: scripts/sdlc-orchestrator-poc.sh install|status|uninstall --project-root <dir>

Installs or removes the opt-in SDLC orchestrator profile only in
<dir>/.opencode. Global OpenCode configuration is never a target.
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
    die "refusing to install the POC into this repository or one of its worktrees"
  fi

  TARGET="$PROJECT_ROOT/.opencode"
  [ ! -L "$TARGET" ] || die "refusing symlinked project target: $TARGET"
  CONFIG_FILE="$TARGET/opencode.jsonc"
  INSTALLER_MANIFEST="$TARGET/.agents-orchestrator-manifest"
  PROFILE_MANIFEST="$TARGET/.sdlc-orchestrator-poc-manifest"
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

new_tmp() { mktemp "${TMPDIR:-/tmp}/sdlc-orchestrator-poc.XXXXXX"; }

render_managed_config() {
  TMP_ONE="$(new_tmp)"
  TMP_TWO="$(new_tmp)"
  render_jsonc_action set "$CONFIG_FILE" default_agent "$MANAGED_DEFAULT_AGENT" "$TMP_ONE"
  render_jsonc_action set "$TMP_ONE" subagent_depth "$MANAGED_SUBAGENT_DEPTH" "$TMP_TWO"
}

render_restored_config() {
  local default_state="$1" default_json="$2" depth_state="$3" depth_json="$4"
  TMP_ONE="$(new_tmp)"
  TMP_TWO="$(new_tmp)"
  if [ "$default_state" = value ]; then
    render_jsonc_action set "$CONFIG_FILE" default_agent "$default_json" "$TMP_ONE"
  else
    render_jsonc_action remove-property "$CONFIG_FILE" default_agent "" "$TMP_ONE"
  fi
  if [ "$depth_state" = value ]; then
    render_jsonc_action set "$TMP_ONE" subagent_depth "$depth_json" "$TMP_TWO"
  else
    render_jsonc_action remove-property "$TMP_ONE" subagent_depth "" "$TMP_TWO"
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
      die "the POC profile does not support TUI descriptors in its selected domains"
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

validate_installer_contents() {
  [ -f "$INSTALLER_MANIFEST" ] || die "installer manifest is missing: $INSTALLER_MANIFEST"

  local kind path expected actual source name descriptor expected_sha actual_sha
  while IFS=$'\t' read -r kind path _; do
    [ -n "$kind" ] || continue
    case "$kind" in
      link|file|dir)
        case "$path" in "$TARGET"|"$TARGET"/*) ;; *) die "global or broad manifest destination: $path" ;; esac
        ;;
      managed-array|managed-object) die "broad profile manifest contains managed runtime config: $path" ;;
      *) die "foreign installer manifest row: $kind" ;;
    esac
  done < "$INSTALLER_MANIFEST"

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
  [ "$primary_count" -eq 1 ] || die "expected exactly one repo-owned primary, found $primary_count"
  [ "$question_owner_count" -eq 1 ] || die "expected exactly one profile question owner, found $question_owner_count"
  grep -Fq "$TARGET/agents/sdlc-orchestrator.md" "$TMP_THREE" ||
    die "sdlc-orchestrator is missing from the profile"
}

validate_managed_config() {
  read_scalar "$CONFIG_FILE" default_agent
  [ "$JSON_STATE" = value ] && [ "$JSON_VALUE" = "$MANAGED_DEFAULT_AGENT" ] ||
    die "managed default_agent changed in $CONFIG_FILE"
  read_scalar "$CONFIG_FILE" subagent_depth
  [ "$JSON_STATE" = value ] && [ "$JSON_VALUE" = "$MANAGED_SUBAGENT_DEPTH" ] ||
    die "managed subagent_depth changed in $CONFIG_FILE"
}

validate_profile_manifest() {
  [ -f "$PROFILE_MANIFEST" ] || die "POC profile manifest is missing: $PROFILE_MANIFEST"
  [ "$(manifest_value contract)" = "$PROFILE_CONTRACT" ] || die "foreign POC profile manifest contract"
  [ "$(manifest_value project-root)" = "$PROJECT_ROOT" ] || die "global or foreign POC profile manifest root"
  [ "$(manifest_value target)" = "$TARGET" ] || die "global or foreign POC profile target"
  [ "$(manifest_value domains)" = "$PROFILE_DOMAINS" ] || die "broad POC profile domain selection"
  local config_existed target_existed expected_sha actual_sha
  config_existed="$(manifest_value config-existed)"
  case "$config_existed" in 0|1) ;; *) die "invalid config-existed value in POC profile manifest" ;; esac
  target_existed="$(manifest_value target-existed)"
  case "$target_existed" in ""|0|1) ;; *) die "invalid target-existed value in POC profile manifest" ;; esac
  [ -f "$INSTALLER_MANIFEST" ] || die "installer manifest is missing"
  expected_sha="$(manifest_value installer-manifest-sha256)"
  actual_sha="$(sha256_file "$INSTALLER_MANIFEST")"
  [ -n "$expected_sha" ] && [ "$expected_sha" = "$actual_sha" ] ||
    die "installer manifest changed or became broad/foreign"
  validate_installer_contents
}

write_profile_manifest() {
  local default_state="$1" default_json="$2" depth_state="$3" depth_json="$4" config_existed="$5" target_existed="$6"
  TMP_THREE="$(mktemp "$TARGET/.sdlc-orchestrator-poc-manifest.tmp.XXXXXX")"
  {
    printf 'contract\t%s\n' "$PROFILE_CONTRACT"
    printf 'project-root\t%s\n' "$PROJECT_ROOT"
    printf 'target\t%s\n' "$TARGET"
    printf 'domains\t%s\n' "$PROFILE_DOMAINS"
    printf 'config-existed\t%s\n' "$config_existed"
    printf 'target-existed\t%s\n' "$target_existed"
    printf 'previous-default-agent-state\t%s\n' "$default_state"
    printf 'previous-default-agent-json\t%s\n' "$default_json"
    printf 'previous-subagent-depth-state\t%s\n' "$depth_state"
    printf 'previous-subagent-depth-json\t%s\n' "$depth_json"
    printf 'installer-manifest-sha256\t%s\n' "$(sha256_file "$INSTALLER_MANIFEST")"
  } > "$TMP_THREE"
  mv "$TMP_THREE" "$PROFILE_MANIFEST"
  TMP_THREE=""
}

run_install() {
  local default_state default_json depth_state depth_json config_existed=0 target_existed=0
  if [ -f "$PROFILE_MANIFEST" ]; then
    validate_profile_manifest
    validate_managed_config
    default_state="$(manifest_value previous-default-agent-state)"
    default_json="$(manifest_value previous-default-agent-json)"
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
    read_scalar "$CONFIG_FILE" default_agent
    default_state="$JSON_STATE"; default_json="$JSON_VALUE"
    read_scalar "$CONFIG_FILE" subagent_depth
    depth_state="$JSON_STATE"; depth_json="$JSON_VALUE"
  fi

  render_managed_config
  "$INSTALLER" install --domain "$PROFILE_DOMAINS" --target "$TARGET"
  validate_installer_contents
  mkdir -p "$TARGET"
  mv "$TMP_TWO" "$CONFIG_FILE"
  TMP_TWO=""
  write_profile_manifest "$default_state" "$default_json" "$depth_state" "$depth_json" "$config_existed" "$target_existed"
  validate_managed_config
  printf 'status: installed\nproject-root: %s\ndefault_agent: sdlc-orchestrator\nsubagent_depth: 2\n' "$PROJECT_ROOT"
}

run_status() {
  if [ ! -f "$PROFILE_MANIFEST" ]; then
    [ ! -e "$INSTALLER_MANIFEST" ] || die "foreign installer manifest exists without the POC profile"
    printf 'status: not installed\nproject-root: %s\n' "$PROJECT_ROOT"
    return 1
  fi
  validate_profile_manifest
  validate_managed_config
  printf 'status: installed\nproject-root: %s\ndefault_agent: sdlc-orchestrator\nsubagent_depth: 2\nrepo-owned primaries: 1\nquestion owners: 1\n' "$PROJECT_ROOT"
}

run_uninstall() {
  [ -f "$PROFILE_MANIFEST" ] || die "POC profile is not installed for $PROJECT_ROOT"
  validate_profile_manifest
  validate_managed_config

  local default_state default_json depth_state depth_json config_existed target_existed
  default_state="$(manifest_value previous-default-agent-state)"
  default_json="$(manifest_value previous-default-agent-json)"
  depth_state="$(manifest_value previous-subagent-depth-state)"
  depth_json="$(manifest_value previous-subagent-depth-json)"
  config_existed="$(manifest_value config-existed)"
  target_existed="$(manifest_value target-existed)"
  [ -n "$target_existed" ] || target_existed=1
  render_restored_config "$default_state" "$default_json" "$depth_state" "$depth_json"

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
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  command -v jq >/dev/null 2>&1 || die "jq is required"
  trap cleanup EXIT INT TERM
  resolve_project_root
  case "$ACTION" in
    install) run_install ;;
    status) run_status ;;
    uninstall) run_uninstall ;;
  esac
}

main "$@"
