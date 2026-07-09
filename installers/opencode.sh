#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034  # MANIFEST_ROOT/DEST_PATH are read by lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installers/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

TARGET=""

runtime_usage() {
  cat <<'EOF'
Usage:
  opencode.sh <install|uninstall|status> [--domain d1,d2] [--status s1,s2]
              [--project] [--target DIR] [--dry-run] [--force]

Actions:
  install     Sync selected domain components into an OpenCode target as symlinks.
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
}

runtime_dest() {
  DEST_PATH="$TARGET/$1/$2"
}

runtime_install_component() {
  link_component "$3" "$4" "$5"
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
