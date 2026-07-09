#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034  # MANIFEST_ROOT/DEST_PATH are read by lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installers/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

TARGET=""
PLUGINS_WARNED=0

runtime_usage() {
  cat <<'EOF'
Usage:
  claude.sh <install|uninstall|status> [--domain d1,d2] [--status s1,s2]
            [--project] [--target DIR] [--dry-run] [--force]

Installs the agents-orchestrator harness into Claude Code.

Mapping:
  agents      generated files at $TARGET/agents/<name>.md
              (frontmatter rewritten to Claude Code subagent format:
              name + description; OpenCode mode/temperature/permission dropped)
  commands    generated files at $TARGET/commands/<name>.md
              (frontmatter reduced to description + argument-hint; OpenCode
              agent:/model:/subtask: dropped — in Claude Code `agent:` means
              "fork into this subagent", a different semantic)
  skills      symlinked directories at $TARGET/skills/<name>
  plugins     skipped (OpenCode-only runtime plugins)
  global      global/AGENTS.md symlinked to $TARGET/rules/agents-orchestrator.md
              (never touches $TARGET/CLAUDE.md or settings files)

Targets:
  default      ~/.claude
  --project   ./.claude from the current working directory
  --target    Explicit alternate Claude root, useful for scratch installs

Filters:
  --domain    Comma-separated domains, or all.
  --status    Comma-separated skill lifecycle states, or all
              (backlog, in-progress, testing, done). Skills only.

Options:
  --dry-run   Print planned mkdir/link/generate/rm/manifest actions without changing files.
  --force     Replace an existing non-matching destination during install.
  -h, --help  Show this help.

Notes:
  Generated agent/command files do not auto-update when the repo changes;
  re-run install to regenerate them. `status` reports generated files as
  generated, stale (source changed since install), foreign, or not installed.

Manifest:
  The installer writes .agents-orchestrator-manifest in the target. A later
  install is a sync: links and generated files from the old manifest that are
  no longer selected are removed.
EOF
}

runtime_init() {
  if [ -n "$TARGET_ARG" ]; then
    TARGET="$(absolute_path "$TARGET_ARG")"
  elif [ "$PROJECT_TARGET" -eq 1 ]; then
    TARGET="$PWD/.claude"
  else
    TARGET="$HOME/.claude"
  fi
  MANIFEST_ROOT="$TARGET"
}

runtime_ensure_dirs() {
  ensure_dir "$TARGET/agents" "$1"
  ensure_dir "$TARGET/commands" "$1"
  ensure_dir "$TARGET/skills" "$1"
  ensure_dir "$TARGET/rules" "$1"
}

runtime_dest() {
  case "$1" in
    agents) DEST_PATH="$TARGET/agents/$2" ;;
    commands) DEST_PATH="$TARGET/commands/$2" ;;
    skills) DEST_PATH="$TARGET/skills/$2" ;;
    plugins)
      DEST_PATH=""
      if [ "$PLUGINS_WARNED" -eq 0 ]; then
        warn "plugins are OpenCode-only; skipped for Claude Code"
        PLUGINS_WARNED=1
      fi
      ;;
    *) DEST_PATH="" ;;
  esac
}

# OpenCode agent -> Claude Code subagent: keep the body, emit name (from the
# filename, preserving the repo's name-from-filename contract) + description.
# mode/temperature/permission are OpenCode dialect with no safe Claude mapping.
transform_claude_agent() {
  local src stem
  src="$1"
  stem="$(basename "$src" .md)"
  awk -v name="$stem" '
    NR == 1 && $0 == "---" { infm = 1; print "---"; print "name: " name; next }
    infm && /^---[[:space:]]*$/ { infm = 0; print "---"; next }
    infm && /^description:/ { print; found = 1; next }
    infm { next }
    { print }
    END { if (!found) exit 1 }
  ' "$src"
}

# OpenCode command -> Claude Code command: keep only description and
# argument-hint. OpenCode agent:/subtask:/model: must not leak through:
# in Claude Code `agent:` means "fork into this subagent".
transform_claude_command() {
  awk '
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && /^---[[:space:]]*$/ { infm = 0; print; next }
    infm && /^description:/ { print; found = 1; next }
    infm && /^argument-hint:/ { print; next }
    infm { next }
    { print }
    END { if (!found) exit 1 }
  ' "$1"
}

runtime_install_component() {
  case "$1" in
    agents) generate_file "$3" "$4" "$5" transform_claude_agent ;;
    commands) generate_file "$3" "$4" "$5" transform_claude_command ;;
    skills) link_component "$3" "$4" "$5" ;;
  esac
}

runtime_component_state() {
  case "$1" in
    agents) file_state "$3" "$4" transform_claude_agent ;;
    commands) file_state "$3" "$4" transform_claude_command ;;
    *) link_state "$3" "$4" ;;
  esac
}

runtime_install_global() {
  link_component "$REPO_ROOT/global/AGENTS.md" "$TARGET/rules/agents-orchestrator.md" "$1"
}

runtime_status_global() {
  local state
  state="$(link_state "$REPO_ROOT/global/AGENTS.md" "$TARGET/rules/agents-orchestrator.md")"
  printf '%s\t%s\t%s\t%s\t%s\n' "-" "global" "rules/agents-orchestrator.md" "-" "$state"
}

harness_main "$@"
