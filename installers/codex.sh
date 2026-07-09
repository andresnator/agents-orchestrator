#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034  # MANIFEST_ROOT/DEST_PATH are read by lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installers/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

CODEX_ROOT=""
SKILLS_ROOT=""
PLUGINS_WARNED=0
PROMPTS_WARNED=0

runtime_usage() {
  cat <<'EOF'
Usage:
  codex.sh <install|uninstall|status> [--domain d1,d2] [--status s1,s2]
           [--project] [--target DIR] [--dry-run] [--force]

Installs the agents-orchestrator harness into OpenAI Codex CLI.

Mapping:
  agents      generated TOML at $CODEX_ROOT/agents/<name>.toml
              (name + description + developer_instructions from the prompt body)
  commands    generated custom prompts at $CODEX_ROOT/prompts/<name>.md
              (frontmatter reduced to description + argument-hint; Codex
              prompts are user-level only and invoked as /prompts:<name>)
  skills      symlinked directories at $SKILLS_ROOT/<name>
              (Codex user skills live under ~/.agents/skills, not ~/.codex)
  plugins     skipped (OpenCode-only runtime plugins)
  global      global/AGENTS.md symlinked to $CODEX_ROOT/AGENTS.md

Targets:
  default      CODEX_ROOT=~/.codex, SKILLS_ROOT=~/.agents/skills
  --project   CODEX_ROOT=./.codex, SKILLS_ROOT=./.agents/skills; prompts and
              global rules are skipped (prompts are user-level only; the
              project AGENTS.md belongs to the consumer repo)
  --target    DIR acts as a fake $HOME: CODEX_ROOT=DIR/.codex and
              SKILLS_ROOT=DIR/.agents/skills. Useful for scratch installs.

Filters:
  --domain    Comma-separated domains, or all.
  --status    Comma-separated skill lifecycle states, or all
              (backlog, in-progress, testing, done). Skills only.

Options:
  --dry-run   Print planned mkdir/link/generate/rm/manifest actions without changing files.
  --force     Replace an existing non-matching destination during install.
  -h, --help  Show this help.

Notes:
  Generated agent/prompt files do not auto-update when the repo changes;
  re-run install to regenerate them. Codex custom prompts are deprecated in
  favor of skills but still work. Restart Codex sessions after installing.

Manifest:
  The installer writes .agents-orchestrator-manifest in $CODEX_ROOT with
  absolute destinations spanning both roots. A later install is a sync:
  links and generated files no longer selected are removed.
EOF
}

runtime_init() {
  local base
  if [ -n "$TARGET_ARG" ]; then
    base="$(absolute_path "$TARGET_ARG")"
    CODEX_ROOT="$base/.codex"
    SKILLS_ROOT="$base/.agents/skills"
  elif [ "$PROJECT_TARGET" -eq 1 ]; then
    CODEX_ROOT="$PWD/.codex"
    SKILLS_ROOT="$PWD/.agents/skills"
  else
    CODEX_ROOT="$HOME/.codex"
    SKILLS_ROOT="$HOME/.agents/skills"
  fi
  MANIFEST_ROOT="$CODEX_ROOT"
}

prompts_enabled() {
  [ "$PROJECT_TARGET" -eq 0 ]
}

runtime_ensure_dirs() {
  ensure_dir "$CODEX_ROOT/agents" "$1"
  ensure_dir "$SKILLS_ROOT" "$1"
  if prompts_enabled; then
    ensure_dir "$CODEX_ROOT/prompts" "$1"
  fi
}

runtime_dest() {
  case "$1" in
    agents) DEST_PATH="$CODEX_ROOT/agents/${2%.md}.toml" ;;
    commands)
      if prompts_enabled; then
        DEST_PATH="$CODEX_ROOT/prompts/$2"
      else
        DEST_PATH=""
        if [ "$PROMPTS_WARNED" -eq 0 ]; then
          warn "Codex custom prompts are user-level only; commands skipped for --project installs"
          PROMPTS_WARNED=1
        fi
      fi
      ;;
    skills) DEST_PATH="$SKILLS_ROOT/$2" ;;
    plugins)
      DEST_PATH=""
      if [ "$PLUGINS_WARNED" -eq 0 ]; then
        warn "plugins are OpenCode-only; skipped for Codex"
        PLUGINS_WARNED=1
      fi
      ;;
    *) DEST_PATH="" ;;
  esac
}

# OpenCode agent -> Codex agent TOML: name from the filename, description from
# frontmatter, prompt body as developer_instructions. Every backslash and
# double quote is escaped, which is valid in TOML basic strings and removes
# any risk of a """ collision inside the multiline body. No model is emitted:
# agents stay provider-agnostic.
transform_codex_agent_toml() {
  local src stem
  src="$1"
  stem="$(basename "$src" .md)"
  awk -v name="$stem" -v sq="'" '
    function toml_escape(s) {
      gsub(/\\/, "\\\\", s)
      gsub(/"/, "\\\"", s)
      return s
    }
    function print_header() {
      print "name = \"" name "\""
      print "description = \"" toml_escape(desc) "\""
      print "developer_instructions = \"\"\""
      header_done = 1
    }
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && /^---[[:space:]]*$/ { infm = 0; next }
    infm && /^description:[[:space:]]*/ {
      val = $0
      sub(/^description:[[:space:]]*/, "", val)
      first = substr(val, 1, 1)
      last = substr(val, length(val), 1)
      if (length(val) >= 2 && ((first == "\"" && last == "\"") || (first == sq && last == sq)))
        val = substr(val, 2, length(val) - 2)
      desc = val
      next
    }
    infm { next }
    {
      if (!header_done) print_header()
      print toml_escape($0)
    }
    END {
      if (desc == "") exit 1
      if (!header_done) print_header()
      print "\"\"\""
    }
  ' "$src"
}

# OpenCode command -> Codex custom prompt: keep only description and
# argument-hint; agent:/model:/subtask: are OpenCode dialect. Bodies use
# $ARGUMENTS, which Codex prompts support.
transform_codex_prompt() {
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
    agents) generate_file "$3" "$4" "$5" transform_codex_agent_toml ;;
    commands) generate_file "$3" "$4" "$5" transform_codex_prompt ;;
    skills) link_component "$3" "$4" "$5" ;;
  esac
}

runtime_component_state() {
  case "$1" in
    agents) file_state "$3" "$4" transform_codex_agent_toml ;;
    commands) file_state "$3" "$4" transform_codex_prompt ;;
    *) link_state "$3" "$4" ;;
  esac
}

runtime_install_global() {
  if [ "$PROJECT_TARGET" -eq 1 ]; then
    warn "project AGENTS.md belongs to the consumer repo; global rules skipped for --project installs"
    return 0
  fi
  link_component "$REPO_ROOT/global/AGENTS.md" "$CODEX_ROOT/AGENTS.md" "$1"
}

runtime_status_global() {
  local state
  if [ "$PROJECT_TARGET" -eq 1 ]; then
    return 0
  fi
  state="$(link_state "$REPO_ROOT/global/AGENTS.md" "$CODEX_ROOT/AGENTS.md")"
  printf '%s\t%s\t%s\t%s\t%s\n' "-" "global" "AGENTS.md" "-" "$state"
}

harness_main "$@"
