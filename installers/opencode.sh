#!/usr/bin/env bash
set -euo pipefail

AGENTS_DIR_NAME="agents"
COMMANDS_DIR_NAME="commands"
SKILLS_DIR_NAME="skills"
MANIFEST_NAME=".agents-orchestrator-manifest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_BUILD_ROOT="$REPO_ROOT/build/opencode"
BUILD_ROOT="$DEFAULT_BUILD_ROOT"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agents-orchestrator.XXXXXX")"

ACTION=""
PROJECT_TARGET=0
ALL_STATUSES=0
STATUS_FILTER="done,testing"
FORCE=0
DRY_RUN=0
TARGET_ARG=""
INSTALL_IN_PROGRESS=0
BUILD_STAGING_ROOT=""
BUILD_BACKUP_ROOT=""
BUILD_PUBLISHED=0
MANIFEST_TEMP_PATH=""
TARGET_ROOT_CREATED=0

has_manifest_unsafe_chars() {
  case "$1" in
    *$'\t'*|*$'\n'*) return 0 ;;
    *) return 1 ;;
  esac
}

validate_manifest_field() {
  local label value
  label="$1"
  value="$2"
  if has_manifest_unsafe_chars "$value"; then
    die "manifest field contains tab or newline: $label"
  fi
}

normalize_absolute_path() {
  awk -v path="$1" '
    BEGIN {
      n = split(path, parts, "/")
      out = ""
      for (i = 1; i <= n; i++) {
        part = parts[i]
        if (part == "" || part == ".") {
          continue
        }
        if (part == "..") {
          sub(/\/[^\/]+$/, "", out)
          continue
        }
        out = out "/" part
      }
      if (out == "") {
        out = "/"
      }
      print out
    }
  '
}

physical_absolute_path() {
  local input abs path suffix base physical_dir
  input="$1"
  abs="$(normalize_absolute_path "$(absolute_path "$input")")"

  if [ "$abs" = "/" ]; then
    printf '/\n'
    return 0
  fi

  if [ -d "$abs" ]; then
    (cd -P "$abs" 2>/dev/null && pwd -P) || die "unable to resolve path: $input"
    return 0
  fi

  path="$abs"
  suffix=""
  while [ "$path" != "/" ] && [ ! -d "$path" ]; do
    base="$(basename "$path")"
    if [ -n "$suffix" ]; then
      suffix="$base/$suffix"
    else
      suffix="$base"
    fi
    path="$(dirname "$path")"
  done

  if [ -d "$path" ]; then
    physical_dir="$(cd -P "$path" 2>/dev/null && pwd -P)" || die "unable to resolve path: $input"
  else
    physical_dir="/"
  fi

  if [ -n "$suffix" ]; then
    if [ "$physical_dir" = "/" ]; then
      printf '/%s\n' "$suffix"
    else
      printf '%s/%s\n' "$physical_dir" "$suffix"
    fi
  else
    printf '%s\n' "$physical_dir"
  fi
}

path_equal_or_inside() {
  local path parent
  path="$1"
  parent="$2"
  case "$path" in
    "$parent"|"$parent"/*) return 0 ;;
    *) return 1 ;;
  esac
}

canonical_manifest_path() {
  local path abs parent base parent_phys
  path="$1"

  [ -n "$path" ] || return 1
  case "$path" in
    /*) ;;
    *) return 1 ;;
  esac

  abs="$(normalize_absolute_path "$path")"
  [ "$abs" = "/" ] && {
    printf '/\n'
    return 0
  }

  parent="$(dirname "$abs")"
  base="$(basename "$abs")"
  parent_phys="$(physical_absolute_path "$parent")" || return 1
  if [ "$parent_phys" = "/" ]; then
    printf '/%s\n' "$base"
  else
    printf '%s/%s\n' "$parent_phys" "$base"
  fi
}

manifest_paths_equal() {
  local left right
  left="$(canonical_manifest_path "$1")" || return 1
  right="$(canonical_manifest_path "$2")" || return 1
  [ "$left" = "$right" ]
}

manifest_path_inside_target() {
  local target path canonical
  target="$1"
  path="$2"

  canonical="$(canonical_manifest_path "$path")" || return 1
  path_equal_or_inside "$canonical" "$target"
}

resolve_target_path() {
  local target target_lex target_phys repo_phys build_phys catalog_skills_phys project_lex explicit_project_allowed
  target="$1"

  [ -n "$target" ] || die "--target requires a non-empty directory"
  validate_manifest_field "--target" "$target"

  target_lex="$(normalize_absolute_path "$(absolute_path "$target")")"
  target_phys="$(physical_absolute_path "$target")"
  repo_phys="$(physical_absolute_path "$REPO_ROOT")"
  build_phys="$(physical_absolute_path "$DEFAULT_BUILD_ROOT")"
  catalog_skills_phys="$(physical_absolute_path "$REPO_ROOT/catalog/$SKILLS_DIR_NAME")"

  explicit_project_allowed=0
  if [ "$PROJECT_TARGET" -eq 1 ] && [ -z "$TARGET_ARG" ]; then
    project_lex="$(normalize_absolute_path "$PWD/.opencode")"
    if [ "$target_lex" = "$project_lex" ]; then
      if [ "$target_phys" = "$project_lex" ] || ! path_equal_or_inside "$target_phys" "$repo_phys"; then
        explicit_project_allowed=1
      fi
    fi
  fi

  case "$target_phys" in
    /)
      die "refuse unsafe target path: /"
      ;;
    "$repo_phys")
      die "refuse unsafe target path: repo root"
      ;;
  esac

  if path_equal_or_inside "$target_phys" "$build_phys"; then
    die "refuse unsafe target path inside build/opencode: $target"
  fi

  if path_equal_or_inside "$target_phys" "$catalog_skills_phys"; then
    die "refuse unsafe target path inside catalog/skills: $target"
  fi

  if [ "$explicit_project_allowed" -ne 1 ] && path_equal_or_inside "$target_phys" "$repo_phys"; then
    die "refuse unsafe target path inside repo: $target"
  fi

  printf '%s\n' "$target_phys"
}

validate_target_path() {
  resolve_target_path "$1" >/dev/null
}

rollback_install() {
  local src dest old_src new_src path current backup
  set +e

  if [ -f "$TMP_DIR/rollback-created-links" ]; then
    while IFS="$(printf '\t')" read -r src dest; do
      [ -n "${dest:-}" ] || continue
      if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        rm "$dest"
      fi
    done < "$TMP_DIR/rollback-created-links"
  fi

  if [ -f "$TMP_DIR/rollback-replaced-links" ]; then
    while IFS="$(printf '\t')" read -r dest old_src new_src; do
      [ -n "${dest:-}" ] || continue
      if [ -L "$dest" ]; then
        current="$(readlink "$dest")"
        if [ "$current" != "$new_src" ]; then
          continue
        fi
        rm "$dest"
      elif [ -e "$dest" ]; then
        continue
      fi
      ln -s "$old_src" "$dest"
    done < "$TMP_DIR/rollback-replaced-links"
  fi

  if [ -f "$TMP_DIR/rollback-forced-paths" ]; then
    while IFS="$(printf '\t')" read -r dest backup new_src; do
      [ -n "${dest:-}" ] || continue
      [ -n "${backup:-}" ] || continue
      [ -e "$backup" ] || continue
      if [ -L "$dest" ]; then
        current="$(readlink "$dest")"
        if [ "$current" != "$new_src" ]; then
          continue
        fi
        rm "$dest"
      elif [ -e "$dest" ]; then
        continue
      fi
      mv "$backup" "$dest"
    done < "$TMP_DIR/rollback-forced-paths"
  fi

  if [ -f "$TMP_DIR/rollback-pruned-dirs" ]; then
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      [ -e "$path" ] || mkdir -p "$path"
    done < "$TMP_DIR/rollback-pruned-dirs"
  fi

  if [ -f "$TMP_DIR/rollback-pruned-links" ]; then
    while IFS="$(printf '\t')" read -r src dest; do
      [ -n "${dest:-}" ] || continue
      [ -e "$dest" ] || [ -L "$dest" ] || ln -s "$src" "$dest"
    done < "$TMP_DIR/rollback-pruned-links"
  fi

  if [ -f "$TMP_DIR/rollback-created-dirs" ]; then
    awk '{ lines[NR] = $0 } END { for (i = NR; i >= 1; i--) print lines[i] }' "$TMP_DIR/rollback-created-dirs" |
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      [ -d "$path" ] && rmdir "$path" 2>/dev/null
    done
  fi

  if [ "$BUILD_PUBLISHED" -eq 1 ]; then
    rm -rf "$DEFAULT_BUILD_ROOT"
    if [ -n "$BUILD_BACKUP_ROOT" ] && { [ -e "$BUILD_BACKUP_ROOT" ] || [ -L "$BUILD_BACKUP_ROOT" ]; }; then
      mv "$BUILD_BACKUP_ROOT" "$DEFAULT_BUILD_ROOT"
    fi
    BUILD_PUBLISHED=0
    BUILD_BACKUP_ROOT=""
  fi
}

cleanup() {
  local code
  code="$1"
  if [ -n "$MANIFEST_TEMP_PATH" ]; then
    rm -f "$MANIFEST_TEMP_PATH"
  fi
  if [ "$INSTALL_IN_PROGRESS" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    rollback_install
  fi
  if [ -n "$BUILD_STAGING_ROOT" ] && [ "$BUILD_STAGING_ROOT" != "$DEFAULT_BUILD_ROOT" ]; then
    rm -rf "$BUILD_STAGING_ROOT"
  fi
  rm -rf "$TMP_DIR"
  return "$code"
}

trap 'code=$?; cleanup "$code"; exit "$code"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
  cat <<'USAGE'
Usage:
  opencode.sh install   [--project] [--all] [--status s1,s2] [--force] [--dry-run] [--target DIR]
  opencode.sh uninstall [--project] [--target DIR] [--dry-run]
  opencode.sh status    [--project] [--target DIR]
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

log() {
  printf '%s\n' "$*"
}

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

target_dir() {
  if [ -n "$TARGET_ARG" ]; then
    absolute_path "$TARGET_ARG"
  elif [ "$PROJECT_TARGET" -eq 1 ]; then
    printf '%s/.opencode\n' "$PWD"
  else
    printf '%s/.config/opencode\n' "$HOME"
  fi
}

status_valid() {
  case "$1" in
    backlog|in-progress|testing|done) return 0 ;;
    *) return 1 ;;
  esac
}

status_allowed() {
  if [ "$ALL_STATUSES" -eq 1 ]; then
    return 0
  fi

  case ",$STATUS_FILTER," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

validate_status_filter() {
  local item
  printf '%s\n' "$STATUS_FILTER" | tr ',' '\n' > "$TMP_DIR/status-filter"
  while IFS= read -r item; do
    [ -n "$item" ] || die "empty status in --status"
    status_valid "$item" || die "invalid status in --status: $item"
  done < "$TMP_DIR/status-filter"
}

frontmatter_value() {
  local file key
  file="$1"
  key="$2"
  awk -v want="$key" '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) {
        sub(/^"/, "", value)
        sub(/"$/, "", value)
      }
      print value
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      current = $0
      sub(/:.*/, "", current)
      if (current == want) {
        value = $0
        sub(/^[^:]+:[[:space:]]*/, "", value)
        clean(value)
        exit
      }
    }
  ' "$file"
}

frontmatter_status() {
  local file
  file="$1"
  awk '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) {
        sub(/^"/, "", value)
        sub(/"$/, "", value)
      }
      print value
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm {
      if ($0 ~ /^metadata:[[:space:]]*$/) {
        in_metadata = 1
        next
      }
      if ($0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ && $0 !~ /^metadata:/) {
        in_metadata = 0
      }
      if (in_metadata && $0 ~ /^[[:space:]]+status:[[:space:]]*/) {
        value = $0
        sub(/^[[:space:]]+status:[[:space:]]*/, "", value)
        clean(value)
        exit
      }
    }
  ' "$file"
}

frontmatter_metadata_value() {
  local file key
  file="$1"
  key="$2"
  awk -v want="$key" '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) {
        sub(/^"/, "", value)
        sub(/"$/, "", value)
      }
      print value
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm {
      if ($0 ~ /^metadata:[[:space:]]*$/) {
        in_metadata = 1
        next
      }
      if ($0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ && $0 !~ /^metadata:/) {
        in_metadata = 0
      }
      if (in_metadata && $0 ~ "^[[:space:]]+" want ":[[:space:]]*") {
        value = $0
        sub("^[[:space:]]+" want ":[[:space:]]*", "", value)
        clean(value)
        exit
      }
    }
  ' "$file"
}

frontmatter_metadata_raw_value() {
  local file key
  file="$1"
  key="$2"
  awk -v want="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm {
      if ($0 ~ /^metadata:[[:space:]]*$/) {
        in_metadata = 1
        next
      }
      if ($0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ && $0 !~ /^metadata:/) {
        in_metadata = 0
      }
      if (in_metadata && $0 ~ "^[[:space:]]+" want ":[[:space:]]*") {
        value = $0
        sub("^[[:space:]]+" want ":[[:space:]]*", "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

frontmatter_has_key() {
  local file key
  file="$1"
  key="$2"
  awk -v want="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      current = $0
      sub(/:.*/, "", current)
      if (current == want) {
        found = 1
        exit
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

frontmatter_raw_line() {
  local file key
  file="$1"
  key="$2"
  awk -v want="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ "^[[:space:]]*" want ":" {
      print
      exit
    }
  ' "$file"
}

frontmatter_key_has_continuation() {
  local file key
  file="$1"
  key="$2"
  awk -v want="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ "^[[:space:]]*" want ":" {
      in_key = 1
      next
    }
    in_key && $0 ~ /^[[:space:]]+[^[:space:]]/ {
      found = 1
      exit
    }
    in_key && $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      exit
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

frontmatter_starts_with_indented_key() {
  local file
  file="$1"
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ /^[[:space:]]*$/ { next }
    fm && $0 ~ /^[[:space:]]+[A-Za-z0-9_-]+:[[:space:]]*/ {
      found = 1
      exit
    }
    fm && $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      exit
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

semver_valid() {
  printf '%s\n' "$1" | awk '
    /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/ { ok = 1 }
    END { exit(ok ? 0 : 1) }
  '
}

quoted_semver_valid() {
  printf '%s\n' "$1" | awk '
    /^"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"$/ { ok = 1 }
    END { exit(ok ? 0 : 1) }
  '
}

extract_frontmatter() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm { print }
  ' "$1"
}

starts_with_frontmatter() {
  [ "$(sed -n '1p' "$1")" = "---" ]
}

has_closing_frontmatter() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

frontmatter_body_has_content() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { body = 1; next }
    body && $0 !~ /^[[:space:]]*$/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

validate_stub_frontmatter_only() {
  local file
  file="$1"

  if ! starts_with_frontmatter "$file"; then
    append_error "$file: stub must start with frontmatter"
    return
  fi
  if ! has_closing_frontmatter "$file"; then
    append_error "$file: stub missing closing frontmatter delimiter"
    return
  fi
  if frontmatter_body_has_content "$file"; then
    append_error "$file: stub body must be empty; put prompt text under catalog/prompts/"
  fi
}

validate_skill_frontmatter() {
  local file
  file="$1"

  if ! starts_with_frontmatter "$file"; then
    append_error "$file: skill must start with frontmatter"
    return
  fi
  if ! has_closing_frontmatter "$file"; then
    append_error "$file: skill missing closing frontmatter delimiter"
  fi
}

ensure_frontmatter_only() {
  local file label
  file="$1"
  label="$2"

  starts_with_frontmatter "$file" || die "$label must start with frontmatter: $file"
  has_closing_frontmatter "$file" || die "$label missing closing frontmatter delimiter: $file"
  if frontmatter_body_has_content "$file"; then
    die "$label must not contain body content: $file"
  fi
  if frontmatter_starts_with_indented_key "$file"; then
    die "$label must start frontmatter with an unindented top-level key: $file"
  fi
}

validate_frontmatter_keys() {
  local file label whitelist unknown
  file="$1"
  label="$2"
  whitelist="$3"

  unknown="$(awk -v whitelist="$whitelist" '
    BEGIN {
      split(whitelist, allowed_names, ",")
      for (i in allowed_names) {
        allowed[allowed_names[i]] = 1
      }
    }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      key = $0
      sub(/:.*/, "", key)
      if (!allowed[key]) {
        print key
      }
    }
  ' "$file" | sort -u)"

  if [ -n "$unknown" ]; then
    die "$label contains unsupported frontmatter key(s) in $file: $(printf '%s' "$unknown" | tr '\n' ' ')"
  fi
}

validate_prompt_path() {
  local file prompt_rel prompt_abs
  file="$1"
  prompt_rel="$2"

  case "$prompt_rel" in
    /*)
      append_error "$file: prompt must be repo-root-relative, not absolute"
      return
      ;;
    catalog/prompts/*) ;;
    *)
      append_error "$file: prompt must be under catalog/prompts/: $prompt_rel"
      return
      ;;
  esac

  case "$prompt_rel" in
    ..|../*|*/..|*/../*)
      append_error "$file: prompt must not contain .. components: $prompt_rel"
      return
      ;;
  esac

  prompt_abs="$REPO_ROOT/$prompt_rel"
  [ -f "$prompt_abs" ] || append_error "$file: prompt does not exist: $prompt_rel"
  if [ -f "$prompt_abs" ] && starts_with_frontmatter "$prompt_abs"; then
    append_error "$file: prompt must not contain frontmatter: $prompt_rel"
  fi
}

validate_common_stub_fields() {
  local file description license author version version_raw
  file="$1"

  description="$(frontmatter_value "$file" description)"
  license="$(frontmatter_value "$file" license)"
  author="$(frontmatter_metadata_value "$file" author)"
  version="$(frontmatter_metadata_value "$file" version)"
  version_raw="$(frontmatter_metadata_raw_value "$file" version)"

  [ -n "$description" ] || append_error "$file: missing description"
  [ -n "$license" ] || append_error "$file: missing license"
  [ -n "$author" ] || append_error "$file: missing metadata.author"
  [ -n "$version" ] || append_error "$file: missing metadata.version"
  if [ -n "$version_raw" ] && ! quoted_semver_valid "$version_raw"; then
    append_error "$file: metadata.version must be quoted strict SemVer: $version_raw"
  fi
  if [ -n "$version" ] && ! semver_valid "$version"; then
    append_error "$file: metadata.version must be strict SemVer: $version"
  fi
}

validate_stub_description_line() {
  local file description_line
  file="$1"
  description_line="$(frontmatter_raw_line "$file" description)"
  if [ -n "$description_line" ]; then
    if printf '%s\n' "$description_line" | awk '
      /^[[:space:]]*description:[[:space:]]*[>|][+-]?[[:space:]]*$/ { bad = 1 }
      END { exit(bad ? 0 : 1) }
    '; then
      append_error "$file: description must be a single-line scalar"
    fi
    if frontmatter_key_has_continuation "$file" description; then
      append_error "$file: description must be a single-line scalar"
    fi
  fi
}

validate_agent_stub_fields() {
  local file mode
  file="$1"

  validate_common_stub_fields "$file"
  validate_stub_description_line "$file"
  mode="$(frontmatter_value "$file" mode)"
  case "$mode" in
    primary|subagent) ;;
    "") append_error "$file: missing mode" ;;
    *) append_error "$file: mode must be primary or subagent: $mode" ;;
  esac
  if ! frontmatter_has_key "$file" permission; then
    append_error "$file: missing permission"
  fi
}

validate_command_stub_fields() {
  local file argument_hint argument_hint_line
  file="$1"

  validate_common_stub_fields "$file"
  validate_stub_description_line "$file"
  argument_hint="$(frontmatter_value "$file" argument-hint)"
  argument_hint_line="$(frontmatter_raw_line "$file" argument-hint)"
  [ -n "$argument_hint" ] || append_error "$file: missing argument-hint"
  if [ -n "$argument_hint_line" ]; then
    if ! printf '%s\n' "$argument_hint_line" | awk '
      /^[[:space:]]*argument-hint:[[:space:]]*"[^"]+"[[:space:]]*$/ { ok = 1 }
      END { exit(ok ? 0 : 1) }
    '; then
      append_error "$file: argument-hint must be a quoted string"
    fi
  fi
}

append_error() {
  printf '%s\n' "$*" >> "$TMP_DIR/errors"
}

check_duplicates() {
  local names_file label duplicates
  names_file="$1"
  label="$2"
  duplicates="$(sort "$names_file" | uniq -d)"
  if [ -n "$duplicates" ]; then
    {
      printf '%s name collisions after flattening:\n' "$label"
      printf '%s\n' "$duplicates"
    } >> "$TMP_DIR/errors"
  fi
}

discover_components() {
  local out build_out skill_names agent_names command_names file dir expected name status prompt_rel base
  out="$1"
  build_out="${2:-}"
  skill_names="$TMP_DIR/skill-names"
  agent_names="$TMP_DIR/agent-names"
  command_names="$TMP_DIR/command-names"

  : > "$out"
  if [ -n "$build_out" ]; then
    : > "$build_out"
  fi
  : > "$TMP_DIR/errors"
  : > "$skill_names"
  : > "$agent_names"
  : > "$command_names"

  find "$REPO_ROOT/catalog/$SKILLS_DIR_NAME" -mindepth 3 -maxdepth 3 -type f -name SKILL.md | sort > "$TMP_DIR/skill-files"
  while IFS= read -r file; do
    dir="$(dirname "$file")"
    expected="$(basename "$dir")"
	    name="$(frontmatter_value "$file" name)"
	    status="$(frontmatter_status "$file")"

    validate_skill_frontmatter "$file"
    validate_common_stub_fields "$file"
    [ -n "$name" ] || append_error "$file: missing name"
    [ -n "$status" ] || append_error "$file: missing metadata.status"
    if [ -n "$status" ] && ! status_valid "$status"; then
      append_error "$file: invalid metadata.status: $status"
    fi
    if [ -n "$name" ] && [ "$name" != "$expected" ]; then
      append_error "$file: name must equal directory basename ($expected)"
    fi

    [ -n "$name" ] && printf '%s\n' "$name" >> "$skill_names"
    if [ -n "$name" ] && [ -n "$status" ] && status_valid "$status" && status_allowed "$status"; then
      printf 'skill\t%s\t%s\t%s\t-\n' "$name" "$status" "$dir" >> "$out"
    fi
  done < "$TMP_DIR/skill-files"

  find "$REPO_ROOT/catalog/$AGENTS_DIR_NAME" -maxdepth 1 -type f -name '*.md' | sort > "$TMP_DIR/agent-files"
  while IFS= read -r file; do
    base="$(basename "$file" .md)"
    name="$(frontmatter_value "$file" name)"
    status="$(frontmatter_status "$file")"
    prompt_rel="$(frontmatter_value "$file" prompt)"

	    validate_stub_frontmatter_only "$file"
	    validate_agent_stub_fields "$file"
	    [ -n "$name" ] || append_error "$file: missing name"
    [ -n "$status" ] || append_error "$file: missing metadata.status"
    [ -n "$prompt_rel" ] || append_error "$file: missing prompt"
    if [ -n "$name" ] && [ "$name" != "$base" ]; then
      append_error "$file: name must equal filename basename ($base)"
    fi
    if [ -n "$status" ] && ! status_valid "$status"; then
      append_error "$file: invalid metadata.status: $status"
    fi
    if [ -n "$prompt_rel" ]; then
      validate_prompt_path "$file" "$prompt_rel"
    fi

    [ -n "$name" ] && printf '%s\n' "$name" >> "$agent_names"
    if [ -n "$name" ] && [ -n "$status" ] && [ -n "$prompt_rel" ] && status_valid "$status" ]; then
      if [ -n "$build_out" ]; then
        printf 'agent\t%s\t%s\t%s\t%s\n' "$name" "$status" "$file" "$REPO_ROOT/$prompt_rel" >> "$build_out"
      fi
      if status_allowed "$status"; then
        printf 'agent\t%s\t%s\t%s\t%s\n' "$name" "$status" "$file" "$REPO_ROOT/$prompt_rel" >> "$out"
      fi
    fi
  done < "$TMP_DIR/agent-files"

  find "$REPO_ROOT/catalog/$COMMANDS_DIR_NAME" -maxdepth 1 -type f -name '*.md' | sort > "$TMP_DIR/command-files"
  while IFS= read -r file; do
    base="$(basename "$file" .md)"
    name="$(frontmatter_value "$file" name)"
    status="$(frontmatter_status "$file")"
    prompt_rel="$(frontmatter_value "$file" prompt)"

	    validate_stub_frontmatter_only "$file"
	    validate_command_stub_fields "$file"
	    [ -n "$name" ] || append_error "$file: missing name"
    [ -n "$status" ] || append_error "$file: missing metadata.status"
    [ -n "$prompt_rel" ] || append_error "$file: missing prompt"
    if [ -n "$name" ] && [ "$name" != "$base" ]; then
      append_error "$file: name must equal filename basename ($base)"
    fi
    if [ -n "$status" ] && ! status_valid "$status"; then
      append_error "$file: invalid metadata.status: $status"
    fi
    if [ -n "$prompt_rel" ]; then
      validate_prompt_path "$file" "$prompt_rel"
    fi

    [ -n "$name" ] && printf '%s\n' "$name" >> "$command_names"
    if [ -n "$name" ] && [ -n "$status" ] && [ -n "$prompt_rel" ] && status_valid "$status" ]; then
      if [ -n "$build_out" ]; then
        printf 'command\t%s\t%s\t%s\t%s\n' "$name" "$status" "$file" "$REPO_ROOT/$prompt_rel" >> "$build_out"
      fi
      if status_allowed "$status"; then
        printf 'command\t%s\t%s\t%s\t%s\n' "$name" "$status" "$file" "$REPO_ROOT/$prompt_rel" >> "$out"
      fi
    fi
  done < "$TMP_DIR/command-files"

  check_duplicates "$skill_names" skills
  check_duplicates "$agent_names" agents
  check_duplicates "$command_names" commands

  if [ -s "$TMP_DIR/errors" ]; then
    cat "$TMP_DIR/errors" >&2
    exit 1
  fi
}

merge_frontmatter() {
  local base override whitelist
  base="$1"
  override="$2"
  whitelist="$3"

  awk -v whitelist="$whitelist" '
    BEGIN {
      split(whitelist, allowed_names, ",")
      for (i in allowed_names) {
        allowed[allowed_names[i]] = 1
      }
    }
    function flush_block() {
      if (current != "") {
        if (!(current in seen)) {
          order[++order_count] = current
          seen[current] = 1
        }
        block[current] = buffer
        current = ""
        buffer = ""
      }
    }
    $0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/ {
      key = $0
      sub(/:.*/, "", key)
      flush_block()
      current = key
      buffer = $0 "\n"
      next
    }
    {
      if (current != "") {
        buffer = buffer $0 "\n"
      }
    }
    END {
      flush_block()
      print "---"
      for (i = 1; i <= order_count; i++) {
        key = order[i]
        if (allowed[key]) {
          printf "%s", block[key]
        }
      }
      print "---"
    }
  ' "$base" "$override"
}

build_markdown() {
  local type name stub prompt out override base_fm override_fm whitelist override_dir
  type="$1"
  name="$2"
  stub="$3"
  prompt="$4"
  out="$5"

  base_fm="$TMP_DIR/base-$type-$name.fm"
  override_fm="$TMP_DIR/override-$type-$name.fm"
  extract_frontmatter "$stub" > "$base_fm"

  if [ "$type" = "agent" ]; then
    whitelist="description,mode,model,temperature,permission,tools,disable"
    override_dir="$REPO_ROOT/harnesses/opencode/overrides/$AGENTS_DIR_NAME"
  else
    whitelist="description,agent,model,subtask"
    override_dir="$REPO_ROOT/harnesses/opencode/overrides/$COMMANDS_DIR_NAME"
  fi

  override="$override_dir/$name.md"
  if [ -f "$override" ]; then
    ensure_frontmatter_only "$override" "OpenCode override"
    extract_frontmatter "$override" > "$override_fm"
  else
    : > "$override_fm"
  fi

  merge_frontmatter "$base_fm" "$override_fm" "$whitelist" > "$out"
  printf '\n' >> "$out"
  cat "$prompt" >> "$out"
}

validate_all_overrides() {
  local dir file whitelist
  for dir in "$REPO_ROOT/harnesses/opencode/overrides/$AGENTS_DIR_NAME" "$REPO_ROOT/harnesses/opencode/overrides/$COMMANDS_DIR_NAME"; do
    [ -d "$dir" ] || continue
    if [ "$(basename "$dir")" = "$AGENTS_DIR_NAME" ]; then
      whitelist="description,mode,model,temperature,permission,tools,disable"
    else
      whitelist="description,agent,model,subtask"
    fi
    find "$dir" -maxdepth 1 -type f -name '*.md' | sort > "$TMP_DIR/override-files"
    while IFS= read -r file; do
      ensure_frontmatter_only "$file" "OpenCode override"
      validate_frontmatter_keys "$file" "OpenCode override" "$whitelist"
    done < "$TMP_DIR/override-files"
  done
}

build_components() {
  local components build_root type name status source prompt out_dir out_file
  components="$1"
  build_root="$2"

  rm -rf "$build_root"
  mkdir -p "$build_root/$AGENTS_DIR_NAME" "$build_root/$COMMANDS_DIR_NAME"

  while IFS="$(printf '\t')" read -r type name status source prompt; do
    case "$type" in
      agent)
        out_dir="$build_root/$AGENTS_DIR_NAME"
        out_file="$out_dir/$name.md"
        build_markdown agent "$name" "$source" "$prompt" "$out_file"
        ;;
      command)
        out_dir="$build_root/$COMMANDS_DIR_NAME"
        out_file="$out_dir/$name.md"
        build_markdown command "$name" "$source" "$prompt" "$out_file"
        ;;
      skill) ;;
      *) die "unknown component type: $type" ;;
    esac
  done < "$components"
}

manifest_has_path() {
  local manifest path kind col2 col3 entry_path
  manifest="$1"
  path="$2"
  [ -f "$manifest" ] || return 1

  while IFS="$(printf '\t')" read -r kind col2 col3; do
    case "$kind" in
      link)
        entry_path="$col2"
        [ -n "${col3:-}" ] && entry_path="$col3"
        ;;
      dir)
        entry_path="$col2"
        [ -n "${col3:-}" ] && entry_path="$col3"
        ;;
      *) continue ;;
    esac
    manifest_paths_equal "$entry_path" "$path" && return 0
  done < "$manifest"

  return 1
}

manifest_has_created_dir() {
  local manifest path kind col2 col3
  manifest="$1"
  path="$2"
  [ -f "$manifest" ] || return 1

  while IFS="$(printf '\t')" read -r kind col2 col3; do
    [ "$kind" = "dir" ] || continue
    [ "${col2:-}" = "created" ] || continue
    [ -n "${col3:-}" ] || continue
    manifest_paths_equal "$col3" "$path" && return 0
  done < "$manifest"

  return 1
}

legacy_link_target_allowed() {
  local src
  src="$1"
  case "$src" in
    "$DEFAULT_BUILD_ROOT"/*|"$REPO_ROOT/catalog/$SKILLS_DIR_NAME"/*|"$REPO_ROOT/$SKILLS_DIR_NAME"/*|"$REPO_ROOT/$AGENTS_DIR_NAME"/*|"$REPO_ROOT/$COMMANDS_DIR_NAME"/*) return 0 ;;
    *) return 1 ;;
  esac
}

publish_build_root() {
  local staging parent backup
  staging="$1"
  parent="$(dirname "$DEFAULT_BUILD_ROOT")"
  backup="$(mktemp -d "$parent/.opencode.previous.XXXXXX")"
  rmdir "$backup"

  if [ -e "$DEFAULT_BUILD_ROOT" ] || [ -L "$DEFAULT_BUILD_ROOT" ]; then
    mv "$DEFAULT_BUILD_ROOT" "$backup" || return 1
    BUILD_BACKUP_ROOT="$backup"
  fi

  if mv "$staging" "$DEFAULT_BUILD_ROOT"; then
    BUILD_PUBLISHED=1
    BUILD_STAGING_ROOT=""
    return 0
  fi

  if [ -e "$backup" ] || [ -L "$backup" ]; then
    mv "$backup" "$DEFAULT_BUILD_ROOT"
  fi
  BUILD_BACKUP_ROOT=""
  return 1
}

finalize_published_build() {
  if [ "$BUILD_PUBLISHED" -eq 1 ]; then
    if [ -n "$BUILD_BACKUP_ROOT" ]; then
      rm -rf "$BUILD_BACKUP_ROOT"
    fi
    BUILD_PUBLISHED=0
    BUILD_BACKUP_ROOT=""
  fi
}

manifest_owns_link_path() {
  local manifest dest kind col2 col3 current
  manifest="$1"
  dest="$2"

  [ -f "$manifest" ] || return 1
  [ -L "$dest" ] || return 1
  current="$(readlink "$dest")" || return 1

	  while IFS="$(printf '\t')" read -r kind col2 col3; do
	    [ "$kind" = "link" ] || continue
	    if [ -n "${col3:-}" ]; then
	      manifest_paths_equal "$col3" "$dest" || continue
	      [ "$current" = "$col2" ] && return 0
	      return 1
	    fi

	    manifest_paths_equal "$col2" "$dest" || continue
	    legacy_link_target_allowed "$current" && return 0
    return 1
  done < "$manifest"

  return 1
}

entry_owns_current_link() {
  local src dest current
  src="$1"
  dest="$2"

  [ -L "$dest" ] || return 1
  current="$(readlink "$dest")" || return 1
  if [ -n "$src" ]; then
    [ "$current" = "$src" ]
  else
    legacy_link_target_allowed "$current"
  fi
}

record_created_link() {
  local src dest
  src="$1"
  dest="$2"
  [ "$DRY_RUN" -eq 1 ] || printf '%s\t%s\n' "$src" "$dest" >> "$TMP_DIR/rollback-created-links"
}

record_replaced_link() {
  local dest old_src new_src
  dest="$1"
  old_src="$2"
  new_src="$3"
  [ "$DRY_RUN" -eq 1 ] || printf '%s\t%s\t%s\n' "$dest" "$old_src" "$new_src" >> "$TMP_DIR/rollback-replaced-links"
}

record_forced_path_replace() {
  local dest backup new_src
  dest="$1"
  backup="$2"
  new_src="$3"
  [ "$DRY_RUN" -eq 1 ] || printf '%s\t%s\t%s\n' "$dest" "$backup" "$new_src" >> "$TMP_DIR/rollback-forced-paths"
}

record_created_dir() {
  local path
  path="$1"
  [ "$DRY_RUN" -eq 1 ] || printf '%s\n' "$path" >> "$TMP_DIR/rollback-created-dirs"
}

record_pruned_link() {
  local src dest
  src="$1"
  dest="$2"
  [ "$DRY_RUN" -eq 1 ] || printf '%s\t%s\n' "$src" "$dest" >> "$TMP_DIR/rollback-pruned-links"
}

record_pruned_dir() {
  local path
  path="$1"
  [ "$DRY_RUN" -eq 1 ] || printf '%s\n' "$path" >> "$TMP_DIR/rollback-pruned-dirs"
}

manifest_temp_file() {
  local target label
  target="$1"
  label="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    MANIFEST_TEMP_PATH="$TMP_DIR/$label"
    return 0
  fi

  MANIFEST_TEMP_PATH="$(mktemp "$target/${MANIFEST_NAME}.XXXXXX")" || die "unable to create manifest temp in target: $target"
}

prepare_target_root() {
  local target
  target="$1"
  TARGET_ROOT_CREATED=0

  if [ -d "$target" ]; then
    return 0
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    die "target exists but is not a directory: $target"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN mkdir -p $target"
  else
    mkdir -p "$target"
    record_created_dir "$target"
  fi
  TARGET_ROOT_CREATED=1
}

dir_has_entries_except_manifest() {
  local dir entry base temp_base
  dir="$1"
  temp_base=""
  if [ -n "$MANIFEST_TEMP_PATH" ]; then
    temp_base="$(basename "$MANIFEST_TEMP_PATH")"
  fi

  for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    base="$(basename "$entry")"
    [ "$base" = "$MANIFEST_NAME" ] && continue
    [ -n "$temp_base" ] && [ "$base" = "$temp_base" ] && continue
    return 0
  done

  return 1
}

path_list_contains() {
  local file wanted
  file="$1"
  wanted="$2"
  [ -f "$file" ] || return 1
  awk -v wanted="$wanted" '
    $0 == wanted { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

first_entry_after_uninstall() {
  local dir entry base temp_base
  dir="$1"
  temp_base=""
  if [ -n "$MANIFEST_TEMP_PATH" ]; then
    temp_base="$(basename "$MANIFEST_TEMP_PATH")"
  fi

  for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    base="$(basename "$entry")"
    [ "$base" = "$MANIFEST_NAME" ] && continue
    [ -n "$temp_base" ] && [ "$base" = "$temp_base" ] && continue
    path_list_contains "$TMP_DIR/uninstall-removed-links" "$entry" && continue
    path_list_contains "$TMP_DIR/uninstall-removed-dirs" "$entry" && continue
    printf '%s\n' "$entry"
    return 0
  done

  return 1
}

dir_has_entries_after_uninstall() {
  first_entry_after_uninstall "$1" >/dev/null
}

record_uninstall_removed_link() {
  local path
  path="$1"
  printf '%s\n' "$path" >> "$TMP_DIR/uninstall-removed-links"
}

record_uninstall_removed_dir() {
  local path
  path="$1"
  printf '%s\n' "$path" >> "$TMP_DIR/uninstall-removed-dirs"
}

append_manifest_dir() {
  local path manifest
  path="$1"
  manifest="$2"
  validate_manifest_field "manifest dir path" "$path"
  printf 'dir\tcreated\t%s\n' "$path" >> "$manifest"
}

append_manifest_link() {
  local src dest manifest
  src="$1"
  dest="$2"
  manifest="$3"
  validate_manifest_field "manifest link source" "$src"
  validate_manifest_field "manifest link destination" "$dest"
  printf 'link\t%s\t%s\n' "$src" "$dest" >> "$manifest"
}

append_manifest_existing_entry() {
  local kind col2 col3 manifest
  kind="$1"
  col2="$2"
  col3="$3"
  manifest="$4"

  validate_manifest_field "manifest entry kind" "$kind"
  validate_manifest_field "manifest entry field" "$col2"
  validate_manifest_field "manifest entry field" "${col3:-}"
  if [ -n "${col3:-}" ]; then
    printf '%s\t%s\t%s\n' "$kind" "$col2" "$col3" >> "$manifest"
  else
    printf '%s\t%s\n' "$kind" "$col2" >> "$manifest"
  fi
}

prepare_target_dirs() {
  local target manifest old_manifest dir path path_phys
  target="$1"
  manifest="$2"
  old_manifest="$3"
  for dir in "$AGENTS_DIR_NAME" "$COMMANDS_DIR_NAME" "$SKILLS_DIR_NAME"; do
    path="$target/$dir"
    if [ -L "$path" ]; then
      die "target component directory must not be a symlink: $path"
    fi

    if [ -d "$path" ]; then
      path_phys="$(physical_absolute_path "$path")"
      if ! path_equal_or_inside "$path_phys" "$target"; then
        die "target component directory resolves outside target: $path"
      fi
      if manifest_has_created_dir "$old_manifest" "$path"; then
        append_manifest_dir "$path" "$manifest"
      fi
      continue
    fi

    if [ -e "$path" ] || [ -L "$path" ]; then
      die "target component directory exists but is not a directory: $path"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      log "DRY-RUN mkdir -p $path"
    else
      mkdir -p "$path"
      record_created_dir "$path"
    fi
    append_manifest_dir "$path" "$manifest"
  done
}

install_link() {
  local src dest old_manifest new_manifest current
  src="$1"
  dest="$2"
  old_manifest="$3"
  new_manifest="$4"

  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      log "ok $dest"
      append_manifest_link "$src" "$dest" "$new_manifest"
      return
    fi

    if manifest_owns_link_path "$old_manifest" "$dest"; then
      log "replace $dest -> $src"
      if [ "$DRY_RUN" -eq 0 ]; then
        record_replaced_link "$dest" "$current" "$src"
        rm "$dest"
        ln -s "$src" "$dest"
      fi
      append_manifest_link "$src" "$dest" "$new_manifest"
      return
    fi

    if [ "$FORCE" -eq 1 ]; then
      log "force replace $dest -> $src"
      if [ "$DRY_RUN" -eq 0 ]; then
        record_replaced_link "$dest" "$current" "$src"
        rm "$dest"
        ln -s "$src" "$dest"
      fi
      append_manifest_link "$src" "$dest" "$new_manifest"
      return
    fi

    warn "skip existing symlink not owned by manifest source: $dest"
    return 1
  fi

  if [ -e "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      if [ -d "$dest" ]; then
        warn "refuse to force replace directory: $dest"
        return 1
      fi
      log "force replace $dest -> $src"
      if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$TMP_DIR/force-backups"
        backup="$(mktemp "$TMP_DIR/force-backups/path.XXXXXX")"
        rm -f "$backup"
        mv "$dest" "$backup"
        record_forced_path_replace "$dest" "$backup" "$src"
        ln -s "$src" "$dest"
      fi
      append_manifest_link "$src" "$dest" "$new_manifest"
      return 0
    else
      warn "skip existing path: $dest (use --force to replace)"
    fi
    return 1
  fi

  log "link $dest -> $src"
  if [ "$DRY_RUN" -eq 0 ]; then
    record_created_link "$src" "$dest"
    ln -s "$src" "$dest"
  fi
  append_manifest_link "$src" "$dest" "$new_manifest"
  return 0
}

prune_absent_entries() {
  local target old_manifest new_manifest kind col2 col3 src path current
  target="$1"
  old_manifest="$2"
  new_manifest="$3"

  [ -f "$old_manifest" ] || return 0

  while IFS="$(printf '\t')" read -r kind col2 col3; do
    [ -n "${kind:-}" ] || continue
    src=""
    path="$col2"
    if [ "$kind" = "link" ] && [ -n "${col3:-}" ]; then
      src="$col2"
      path="$col3"
    elif [ "$kind" = "dir" ] && [ "${col2:-}" = "created" ] && [ -n "${col3:-}" ]; then
      path="$col3"
    fi

    if manifest_has_path "$new_manifest" "$path"; then
      continue
    fi

    if ! manifest_path_inside_target "$target" "$path"; then
      warn "skip manifest entry outside target: $path"
      append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
      continue
    fi

    case "$kind" in
      link)
        if entry_owns_current_link "$src" "$path"; then
          log "prune $path"
          if [ "$DRY_RUN" -eq 0 ]; then
            current="$(readlink "$path")"
            record_pruned_link "$current" "$path"
            rm "$path"
          fi
        elif [ -L "$path" ]; then
          warn "skip prune for symlink with unexpected source: $path"
          append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
        elif [ -e "$path" ]; then
          warn "skip prune for non-symlink path: $path"
          append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
        fi
        ;;
      dir)
        if [ "${col2:-}" != "created" ]; then
          warn "skip prune for legacy directory entry: $path"
          append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
        elif [ -L "$path" ]; then
          warn "skip prune for directory symlink: $path"
          append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
        elif [ -d "$path" ]; then
          log "rmdir if empty $path"
          if [ "$DRY_RUN" -eq 0 ] && rmdir "$path" 2>/dev/null; then
            record_pruned_dir "$path"
          fi
          if [ -d "$path" ]; then
            append_manifest_dir "$path" "$new_manifest"
          fi
        fi
        ;;
    esac
  done < "$old_manifest"
}

run_install() {
  local target components build_components_file old_manifest new_manifest type name status source prompt src dest build_parent install_failed
  validate_status_filter
  target="$(resolve_target_path "$(target_dir)")"
  components="$TMP_DIR/components.tsv"
  build_components_file="$TMP_DIR/build-components.tsv"
  old_manifest="$target/$MANIFEST_NAME"

  discover_components "$components" "$build_components_file"
  validate_all_overrides
  if [ "$DRY_RUN" -eq 1 ]; then
    BUILD_ROOT="$TMP_DIR/build/opencode"
    build_components "$build_components_file" "$BUILD_ROOT"
    BUILD_ROOT="$DEFAULT_BUILD_ROOT"
  else
    build_parent="$(dirname "$DEFAULT_BUILD_ROOT")"
    mkdir -p "$build_parent"
    BUILD_STAGING_ROOT="$(mktemp -d "$build_parent/.opencode.stage.XXXXXX")"
    BUILD_ROOT="$DEFAULT_BUILD_ROOT"
    build_components "$build_components_file" "$BUILD_STAGING_ROOT"
  fi

  : > "$TMP_DIR/rollback-created-links"
  : > "$TMP_DIR/rollback-replaced-links"
  : > "$TMP_DIR/rollback-forced-paths"
  : > "$TMP_DIR/rollback-created-dirs"
  : > "$TMP_DIR/rollback-pruned-links"
  : > "$TMP_DIR/rollback-pruned-dirs"

  install_failed=0
  INSTALL_IN_PROGRESS=1
  prepare_target_root "$target"
  manifest_temp_file "$target" manifest.new
  new_manifest="$MANIFEST_TEMP_PATH"
  : > "$new_manifest"
  prepare_target_dirs "$target" "$new_manifest" "$old_manifest"
  if [ "$TARGET_ROOT_CREATED" -eq 1 ] || manifest_has_created_dir "$old_manifest" "$target"; then
    append_manifest_dir "$target" "$new_manifest"
  fi

  while IFS="$(printf '\t')" read -r type name status source prompt; do
    case "$type" in
      skill)
        src="$source"
        dest="$target/$SKILLS_DIR_NAME/$name"
        ;;
      agent)
        src="$BUILD_ROOT/$AGENTS_DIR_NAME/$name.md"
        dest="$target/$AGENTS_DIR_NAME/$name.md"
        ;;
      command)
        src="$BUILD_ROOT/$COMMANDS_DIR_NAME/$name.md"
        dest="$target/$COMMANDS_DIR_NAME/$name.md"
        ;;
      *) die "unknown component type: $type" ;;
    esac
    if ! install_link "$src" "$dest" "$old_manifest" "$new_manifest"; then
      install_failed=1
    fi
  done < "$components"

  if [ "$install_failed" -ne 0 ]; then
    die "install aborted due to skipped selected entries"
  fi

  prune_absent_entries "$target" "$old_manifest" "$new_manifest"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN write manifest $old_manifest"
  else
    publish_build_root "$BUILD_STAGING_ROOT"
    mv "$new_manifest" "$old_manifest"
    MANIFEST_TEMP_PATH=""
    finalize_published_build
  fi
  INSTALL_IN_PROGRESS=0
}

run_uninstall() {
  local target manifest new_manifest kind col2 col3 src path leftovers owned_target_root remaining
  target="$(resolve_target_path "$(target_dir)")"
  manifest="$target/$MANIFEST_NAME"
  leftovers=0
  owned_target_root=0

  if [ ! -f "$manifest" ]; then
    warn "manifest not found: $manifest"
    return 0
  fi

  manifest_temp_file "$target" manifest.uninstall
  new_manifest="$MANIFEST_TEMP_PATH"
  : > "$new_manifest"
  : > "$TMP_DIR/uninstall-removed-links"
  : > "$TMP_DIR/uninstall-removed-dirs"

  while IFS="$(printf '\t')" read -r kind col2 col3; do
    [ "$kind" = "link" ] || continue
    if [ -n "${col3:-}" ]; then
      src="$col2"
      path="$col3"
    else
      src=""
      path="$col2"
    fi

    if ! manifest_path_inside_target "$target" "$path"; then
      warn "skip manifest link outside target: $path"
      append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
      leftovers=1
      continue
    fi

    if entry_owns_current_link "$src" "$path"; then
      log "remove $path"
      record_uninstall_removed_link "$path"
      [ "$DRY_RUN" -eq 1 ] || rm "$path"
    elif [ -L "$path" ]; then
      warn "skip symlink with unexpected source: $path"
      append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
      leftovers=1
    elif [ -e "$path" ]; then
      warn "skip non-symlink manifest link path: $path"
      append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
      leftovers=1
    fi
  done < "$manifest"

  while IFS="$(printf '\t')" read -r kind col2 col3; do
    [ "$kind" = "dir" ] || continue
    if [ "${col2:-}" = "created" ] && [ -n "${col3:-}" ]; then
      path="$col3"
    else
      warn "skip legacy directory entry: $col2"
      append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
      leftovers=1
      continue
    fi

    if ! manifest_path_inside_target "$target" "$path"; then
      warn "skip manifest directory outside target: $path"
      append_manifest_existing_entry "$kind" "$col2" "${col3:-}" "$new_manifest"
      leftovers=1
      continue
    fi

    if [ "$path" = "$target" ]; then
      owned_target_root=1
      continue
    fi

    if [ -L "$path" ]; then
      warn "skip directory symlink in manifest: $path"
      append_manifest_dir "$path" "$new_manifest"
      leftovers=1
    elif [ -d "$path" ]; then
      log "rmdir if empty $path"
      if [ "$DRY_RUN" -eq 1 ]; then
        remaining="$(first_entry_after_uninstall "$path" || true)"
        if [ -n "$remaining" ]; then
          warn "keep directory with remaining path after planned uninstall: $remaining"
          append_manifest_dir "$path" "$new_manifest"
          leftovers=1
        else
          record_uninstall_removed_dir "$path"
        fi
        continue
      fi
      rmdir "$path" 2>/dev/null || true
      if [ -d "$path" ]; then
        append_manifest_dir "$path" "$new_manifest"
        leftovers=1
      else
        record_uninstall_removed_dir "$path"
      fi
    fi
  done < "$manifest"

  if [ "$owned_target_root" -eq 1 ] && [ -d "$target" ]; then
    log "rmdir if empty $target"
    remaining="$(first_entry_after_uninstall "$target" || true)"
    if [ -n "$remaining" ]; then
      warn "keep directory with remaining path after planned uninstall: $remaining"
      append_manifest_dir "$target" "$new_manifest"
      leftovers=1
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$leftovers" -eq 1 ]; then
      log "DRY-RUN rewrite manifest $manifest"
      return 1
    fi
    log "DRY-RUN remove manifest $manifest"
  else
    if [ "$leftovers" -eq 1 ]; then
      mv "$new_manifest" "$manifest"
      MANIFEST_TEMP_PATH=""
      return 1
    fi
    rm -f "$new_manifest"
    MANIFEST_TEMP_PATH=""
    rm "$manifest"
    if [ "$owned_target_root" -eq 1 ] && [ -d "$target" ]; then
      rmdir "$target" 2>/dev/null || true
    fi
  fi
}

run_status() {
  local target manifest kind col2 col3 src path current state exit_code
  target="$(resolve_target_path "$(target_dir)")"
  manifest="$target/$MANIFEST_NAME"
  exit_code=0

  if [ ! -f "$manifest" ]; then
    printf 'MISSING\tmanifest\t%s\n' "$manifest"
    return 1
  fi

  while IFS="$(printf '\t')" read -r kind col2 col3; do
    src=""
    path="$col2"
    case "$kind" in
      link)
        if [ -n "${col3:-}" ]; then
          src="$col2"
          path="$col3"
        fi
        if ! manifest_path_inside_target "$target" "$path"; then
          state="BROKEN"
          exit_code=1
          printf '%s\t%s\t%s\n' "$state" "$kind" "$path"
          continue
        fi
        if [ -L "$path" ]; then
          current="$(readlink "$path")"
          if [ -n "$src" ] && [ "$current" != "$src" ]; then
            state="BROKEN"
            exit_code=1
          elif [ -z "$src" ] && ! legacy_link_target_allowed "$current"; then
            state="BROKEN"
            exit_code=1
          elif [ -e "$path" ]; then
            state="OK"
          else
            state="BROKEN"
            exit_code=1
          fi
        elif [ -e "$path" ]; then
          state="BROKEN"
          exit_code=1
        else
          state="MISSING"
          exit_code=1
        fi
        ;;
      dir)
        if [ "${col2:-}" = "created" ] && [ -n "${col3:-}" ]; then
          path="$col3"
        fi
        if ! manifest_path_inside_target "$target" "$path"; then
          state="BROKEN"
          exit_code=1
        elif [ -L "$path" ]; then
          state="BROKEN"
          exit_code=1
        elif [ -d "$path" ]; then
          state="OK"
        else
          state="MISSING"
          exit_code=1
        fi
        ;;
      *)
        state="BROKEN"
        exit_code=1
        ;;
    esac
    printf '%s\t%s\t%s\n' "$state" "$kind" "$path"
  done < "$manifest"

  return "$exit_code"
}

parse_args() {
  [ $# -gt 0 ] || {
    usage
    exit 2
  }

  ACTION="$1"
  shift

  case "$ACTION" in
    install|uninstall|status) ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac

  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        PROJECT_TARGET=1
        ;;
      --all)
        [ "$ACTION" = "install" ] || die "--all is only valid for install"
        ALL_STATUSES=1
        ;;
      --status)
        [ "$ACTION" = "install" ] || die "--status is only valid for install"
        shift
        [ $# -gt 0 ] || die "--status requires a comma-separated value"
        STATUS_FILTER="$1"
        ;;
      --force)
        [ "$ACTION" = "install" ] || die "--force is only valid for install"
        FORCE=1
        ;;
      --dry-run)
        [ "$ACTION" != "status" ] || die "--dry-run is not valid for status"
        DRY_RUN=1
        ;;
      --target)
        shift
        [ $# -gt 0 ] || die "--target requires a directory"
        [ -n "$1" ] || die "--target requires a non-empty directory"
        validate_manifest_field "--target" "$1"
        TARGET_ARG="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  case "$ACTION" in
    install) run_install ;;
    uninstall) run_uninstall ;;
    status) run_status ;;
  esac
}

main "$@"
