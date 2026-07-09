#!/usr/bin/env bash
# configure-models.sh — interactive per-agent model/variant assignment for OpenCode.
#
# Discovers harness agents from domains/*/agents, loads a tier profile from
# profiles/, asks model + variant per tier (with per-agent overrides), and
# merges the resulting `agent` block into the user's opencode.json(c).
# Model/variant catalog comes from the model-variants plugin cache when
# present, else from `opencode models`. See docs/agent-models.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_CATALOG="$HOME/.config/opencode/cache/model-variants.json"

ACTION=""
PROFILE_ARG="default"
PROJECT_TARGET=0
TARGET_ARG=""
DRY_RUN=0
MODELS_FILE=""
CATALOG_ARG=""

warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  scripts/configure-models.sh [configure] [options]
  scripts/configure-models.sh show [options]

Actions:
  configure  Interactive wizard: assign model and variant per agent tier (default).
  show       Print current agent mappings from the resolved config.

Options:
  --profile NAME|PATH  Tier profile; a bare name resolves to profiles/NAME.json (default: default).
  --project            Target ./.opencode instead of ~/.config/opencode (gitignored user state).
  --target DIR         Explicit target directory.
  --dry-run            Run the wizard but write nothing; print merged JSON and a diff.
  --models-file FILE   Read the model list from FILE, one provider/model per line (testing).
  --catalog FILE       Read the model/variant catalog JSON from FILE (testing).
  -h, --help           Show this help.

The catalog is preferred from ~/.config/opencode/cache/model-variants.json (written by
the meta model-variants plugin on OpenCode startup; start a session once to refresh it);
fallback is `opencode models` (models only, no variants). Requires jq. Config files with
JSONC comments are not supported.
EOF
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

AGENTS_TMP=""
MODELS_TMP=""
CURRENT_TMP=""
DECISIONS_TMP=""
OUT_TMP=""
REWRITE_TMP=""

cleanup() { rm -f "$AGENTS_TMP" "$MODELS_TMP" "$CURRENT_TMP" "$DECISIONS_TMP" "$OUT_TMP" "$REWRITE_TMP"; }

make_tmp() { mktemp "${TMPDIR:-/tmp}/agents-orchestrator-cfg.XXXXXX"; }

# --- config resolution -------------------------------------------------------

CONFIG_FILE=""
CONFIG_EXISTS=0

resolve_config() {
  local root="$1"
  if [ -f "$root/opencode.jsonc" ]; then
    CONFIG_FILE="$root/opencode.jsonc"
    CONFIG_EXISTS=1
  elif [ -f "$root/opencode.json" ]; then
    CONFIG_FILE="$root/opencode.json"
    CONFIG_EXISTS=1
  else
    CONFIG_FILE="$root/opencode.json"
    CONFIG_EXISTS=0
  fi
  if [ "$CONFIG_EXISTS" -eq 1 ]; then
    jq empty "$CONFIG_FILE" 2>/dev/null ||
      die "$CONFIG_FILE is not valid JSON (JSONC comments are not supported by this script; remove them or edit manually)"
  fi
}

config_json() {
  if [ "$CONFIG_EXISTS" -eq 1 ]; then
    cat "$CONFIG_FILE"
  else
    printf '{}'
  fi
}

# --- catalog and model list --------------------------------------------------

CATALOG_FILE=""

resolve_catalog() {
  if [ -n "$CATALOG_ARG" ]; then
    CATALOG_FILE="$(absolute_path "$CATALOG_ARG")"
    [ -f "$CATALOG_FILE" ] || die "catalog file not found: $CATALOG_FILE"
    jq empty "$CATALOG_FILE" 2>/dev/null || die "catalog file is not valid JSON: $CATALOG_FILE"
  elif [ -f "$DEFAULT_CATALOG" ] && jq empty "$DEFAULT_CATALOG" 2>/dev/null; then
    CATALOG_FILE="$DEFAULT_CATALOG"
    printf 'catalog: %s (generated %s)\n' "$CATALOG_FILE" \
      "$(jq -r '.generatedAt // "unknown"' "$CATALOG_FILE")" >&2
  fi
}

load_models() {
  MODELS_TMP="$(make_tmp)"
  if [ -n "$MODELS_FILE" ]; then
    grep '/' "$MODELS_FILE" > "$MODELS_TMP" || true
  elif [ -n "$CATALOG_FILE" ]; then
    jq -r '.providers | to_entries[] | .key as $p | (.value | keys[]) | "\($p)/\(.)"' \
      "$CATALOG_FILE" | sort > "$MODELS_TMP"
  else
    command -v opencode >/dev/null 2>&1 ||
      die "opencode CLI not found and no catalog cache at $DEFAULT_CATALOG (start an OpenCode session once, or pass --models-file)"
    warn "no catalog cache at $DEFAULT_CATALOG; falling back to 'opencode models' (no variant data — start an OpenCode session once to generate the cache)"
    opencode models 2>/dev/null | grep '/' > "$MODELS_TMP" || true
  fi
  [ -s "$MODELS_TMP" ] || die "no models found (check provider auth with 'opencode providers')"
}

# Prints the variant names known for a provider/model, one per line.
variants_for() {
  local model="$1"
  [ -n "$CATALOG_FILE" ] || return 0
  jq -r --arg p "${model%%/*}" --arg m "${model#*/}" \
    '.providers[$p][$m] // [] | .[]' "$CATALOG_FILE"
}

# --- discovery and current state ---------------------------------------------

discover_agents() {
  AGENTS_TMP="$(make_tmp)"
  local file
  for file in "$REPO_ROOT"/domains/*/agents/*.md; do
    [ -f "$file" ] || continue
    basename "$file" .md
  done | sort > "$AGENTS_TMP"
  [ -s "$AGENTS_TMP" ] || die "no agents found under $REPO_ROOT/domains/*/agents"
}

load_current() {
  CURRENT_TMP="$(make_tmp)"
  config_json | jq -r '.agent // {} | to_entries[] |
    [.key, (.value.model // "-"), (.value.variant // "-")] | @tsv' > "$CURRENT_TMP"
}

current_model() { awk -F'\t' -v a="$1" '$1 == a { print $2 }' "$CURRENT_TMP"; }
current_variant() { awk -F'\t' -v a="$1" '$1 == a { print $3 }' "$CURRENT_TMP"; }

current_display() {
  local model variant
  model="$(current_model "$1")"
  variant="$(current_variant "$1")"
  if [ -z "$model" ] || [ "$model" = "-" ]; then
    printf 'inherits\n'
  elif [ "$variant" = "-" ]; then
    printf '%s\n' "$model"
  else
    printf '%s variant=%s\n' "$model" "$variant"
  fi
}

# --- profile -----------------------------------------------------------------

PROFILE_FILE=""

resolve_profile() {
  case "$PROFILE_ARG" in
    */*|*.json) PROFILE_FILE="$(absolute_path "$PROFILE_ARG")" ;;
    *) PROFILE_FILE="$REPO_ROOT/profiles/$PROFILE_ARG.json" ;;
  esac
  if [ ! -f "$PROFILE_FILE" ]; then
    local available="" p
    for p in "$REPO_ROOT"/profiles/*.json; do
      [ -e "$p" ] || continue
      available="$available$(basename "$p" .json) "
    done
    die "profile not found: $PROFILE_FILE (available: ${available:-none})"
  fi
  jq empty "$PROFILE_FILE" 2>/dev/null || die "profile is not valid JSON: $PROFILE_FILE"
  jq -e '.tiers | type == "object"' "$PROFILE_FILE" >/dev/null ||
    die "profile has no .tiers object: $PROFILE_FILE"
  jq -e '[.tiers[].agents[]] | length == (unique | length)' "$PROFILE_FILE" >/dev/null ||
    die "profile lists an agent in more than one tier: $PROFILE_FILE"
  local uncovered
  uncovered="$(comm -23 "$AGENTS_TMP" <(jq -r '.tiers[].agents[]' "$PROFILE_FILE" | sort -u))"
  if [ -n "$uncovered" ]; then
    warn "agents not covered by any tier (reachable via per-agent override): $(printf '%s' "$uncovered" | tr '\n' ' ')"
  fi
}

# --- decisions ---------------------------------------------------------------
# DECISIONS_TMP rows: name <TAB> tier <TAB> action <TAB> variant
# action: KEEP | INHERIT | provider/model ; variant: - | name

init_decisions() {
  DECISIONS_TMP="$(make_tmp)"
  local name tier
  while IFS= read -r name; do
    tier="$(jq -r --arg a "$name" \
      '.tiers | to_entries[] | select(.value.agents | index($a)) | .key' "$PROFILE_FILE")"
    printf '%s\t%s\tKEEP\t-\n' "$name" "${tier:--}"
  done < "$AGENTS_TMP" >> "$DECISIONS_TMP"
}

set_decision() {
  local name="$1" action="$2" variant="$3"
  REWRITE_TMP="$(make_tmp)"
  awk -F'\t' -v OFS='\t' -v a="$name" -v act="$action" -v v="$variant" \
    '$1 == a { $3 = act; $4 = v } { print }' "$DECISIONS_TMP" > "$REWRITE_TMP"
  mv "$REWRITE_TMP" "$DECISIONS_TMP"
  REWRITE_TMP=""
}

decision_display() {
  local action variant
  action="$(awk -F'\t' -v a="$1" '$1 == a { print $3 }' "$DECISIONS_TMP")"
  variant="$(awk -F'\t' -v a="$1" '$1 == a { print $4 }' "$DECISIONS_TMP")"
  case "$action" in
    KEEP) printf 'keep (%s)\n' "$(current_display "$1")" ;;
    INHERIT) printf 'inherit (remove mapping)\n' ;;
    *)
      if [ "$variant" = "-" ]; then
        printf '%s\n' "$action"
      else
        printf '%s variant=%s\n' "$action" "$variant"
      fi
      ;;
  esac
}

# Resolved model after decisions (empty when inheriting/unmapped).
resolved_model() {
  local row action model
  row="$(awk -F'\t' -v a="$1" '$1 == a { print $3 }' "$DECISIONS_TMP")"
  case "$row" in
    KEEP)
      model="$(current_model "$1")"
      [ "$model" = "-" ] && model=""
      printf '%s\n' "$model"
      ;;
    INHERIT|"") printf '\n' ;;
    *) printf '%s\n' "$row" ;;
  esac
}

# --- interaction helpers -----------------------------------------------------

# choose PROMPT DEFAULT ITEM... -> prints the chosen item. UI on stderr,
# selection on stdout, reads stdin so piped answers work for testing.
choose() {
  local prompt="$1" default="$2" reply item i=0
  shift 2
  for item in "$@"; do
    i=$((i + 1))
    printf '  %2d) %s\n' "$i" "$item" >&2
  done
  while :; do
    printf '%s [%s]: ' "$prompt" "$default" >&2
    IFS= read -r reply || die "input closed"
    if [ -z "$reply" ]; then
      printf '%s\n' "$default"
      return 0
    fi
    case "$reply" in
      *[!0-9]*) warn "enter a number between 1 and $#" ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le $# ]; then
          printf '%s\n' "${!reply}"
          return 0
        fi
        warn "enter a number between 1 and $#"
        ;;
    esac
  done
}

prompt_line() {
  local reply
  printf '%s' "$1" >&2
  IFS= read -r reply || die "input closed"
  printf '%s\n' "$reply"
}

confirm() {
  local reply
  reply="$(prompt_line "$1 [y/N]: ")"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ask_model PROMPT -> prints: SKIP | INHERIT | provider/model
ask_model() {
  local prompt="$1" choice manual
  local models=()
  while IFS= read -r choice; do models+=("$choice"); done < "$MODELS_TMP"
  choice="$(choose "$prompt" "skip (keep current)" \
    "skip (keep current)" "inherit (remove mapping)" "enter model manually" "${models[@]}")"
  case "$choice" in
    "skip (keep current)") printf 'SKIP\n' ;;
    "inherit (remove mapping)") printf 'INHERIT\n' ;;
    "enter model manually")
      manual="$(prompt_line "model (provider/model): ")"
      case "$manual" in
        */*) ;;
        *) die "model must be provider/model, got: $manual" ;;
      esac
      grep -qxF "$manual" "$MODELS_TMP" || warn "model not in the known list: $manual"
      printf '%s\n' "$manual"
      ;;
    *) printf '%s\n' "$choice" ;;
  esac
}

# ask_variant MODEL SUGGESTED -> prints: - | variant-name
ask_variant() {
  local model="$1" suggested="$2" choice default v
  local items=("none (no variant)")
  local names=()
  while IFS= read -r v; do
    [ -n "$v" ] && names+=("$v")
  done < <(variants_for "$model")
  if [ "${#names[@]}" -gt 0 ]; then
    items=("${items[@]}" "${names[@]}")
  fi
  items=("${items[@]}" "enter variant manually")
  default="none (no variant)"
  if [ -n "$suggested" ] && [ "$suggested" != "null" ]; then
    for v in ${names[@]+"${names[@]}"}; do
      [ "$v" = "$suggested" ] && default="$suggested"
    done
  fi
  choice="$(choose "variant for $model" "$default" "${items[@]}")"
  case "$choice" in
    "none (no variant)") printf '%s\n' "-" ;;
    "enter variant manually")
      choice="$(prompt_line "variant name: ")"
      [ -n "$choice" ] || { printf '%s\n' "-"; return 0; }
      printf '%s\n' "$choice"
      ;;
    *) printf '%s\n' "$choice" ;;
  esac
}

# Re-ask model+variant for one agent and record the decision.
override_agent() {
  local name="$1" suggested="$2" model variant
  model="$(ask_model "model for agent '$name'")"
  case "$model" in
    SKIP) return 0 ;;
    INHERIT) set_decision "$name" INHERIT - ;;
    *)
      variant="$(ask_variant "$model" "$suggested")"
      set_decision "$name" "$model" "$variant"
      ;;
  esac
}

# --- actions -----------------------------------------------------------------

run_show() {
  local root name foreign
  root="$(target_root)"
  resolve_config "$root"
  if [ "$CONFIG_EXISTS" -eq 0 ]; then
    printf 'no config at %s — all agents inherit defaults\n' "$CONFIG_FILE"
    return 0
  fi
  discover_agents
  load_current
  printf 'config: %s\n\n' "$CONFIG_FILE"
  printf '%-22s %s\n' 'AGENT' 'MAPPING'
  while IFS= read -r name; do
    printf '%-22s %s\n' "$name" "$(current_display "$name")"
  done < "$AGENTS_TMP"
  foreign="$(awk -F'\t' '{ print $1 }' "$CURRENT_TMP" | grep -vxF -f "$AGENTS_TMP" || true)"
  if [ -n "$foreign" ]; then
    printf '\n'
    printf '%s\n' "$foreign" | while IFS= read -r name; do
      printf '%-22s %s (not a harness agent, untouched)\n' "$name" "$(current_display "$name")"
    done
  fi
}

run_configure() {
  local root tier desc suggested name model variant changes judge_a judge_b
  root="$(target_root)"
  resolve_config "$root"
  discover_agents
  load_current
  resolve_catalog
  load_models
  resolve_profile
  init_decisions

  printf 'target config: %s%s\n' "$CONFIG_FILE" \
    "$([ "$CONFIG_EXISTS" -eq 0 ] && printf ' (will be created)')" >&2
  printf 'profile: %s — %s\n' \
    "$(jq -r '.name // "?"' "$PROFILE_FILE")" \
    "$(jq -r '.description // ""' "$PROFILE_FILE")" >&2

  # Read the tier list into an array first: the loop body prompts on stdin,
  # so the loop must not have its stdin redirected from the tier stream.
  local tiers=()
  while IFS= read -r tier; do tiers+=("$tier"); done < <(jq -r '.tiers | keys_unsorted[]' "$PROFILE_FILE")

  for tier in ${tiers[@]+"${tiers[@]}"}; do
    desc="$(jq -r --arg t "$tier" '.tiers[$t].description // ""' "$PROFILE_FILE")"
    suggested="$(jq -r --arg t "$tier" '.tiers[$t].variant // ""' "$PROFILE_FILE")"
    local members=()
    while IFS= read -r name; do
      if grep -qxF "$name" "$AGENTS_TMP"; then
        members+=("$name")
      else
        warn "profile tier '$tier' references unknown agent '$name' (ignored)"
      fi
    done < <(jq -r --arg t "$tier" '.tiers[$t].agents[]' "$PROFILE_FILE")
    [ "${#members[@]}" -eq 0 ] && continue

    printf '\n== tier: %s — %s\n' "$tier" "$desc" >&2
    for name in "${members[@]}"; do
      printf '   %-22s current: %s\n' "$name" "$(current_display "$name")" >&2
    done

    model="$(ask_model "model for tier '$tier'")"
    case "$model" in
      SKIP) continue ;;
      INHERIT)
        for name in "${members[@]}"; do set_decision "$name" INHERIT -; done
        ;;
      *)
        variant="$(ask_variant "$model" "$suggested")"
        for name in "${members[@]}"; do set_decision "$name" "$model" "$variant"; done
        ;;
    esac
  done

  judge_a="$(resolved_model jd-judge-a)"
  judge_b="$(resolved_model jd-judge-b)"
  if [ -n "$judge_a" ] && [ -n "$judge_b" ] && [ "${judge_a%%/*}" = "${judge_b%%/*}" ]; then
    warn "jd-judge-a and jd-judge-b share provider '${judge_a%%/*}'; different providers strengthen the blind adversarial review"
    if confirm "re-pick model for jd-judge-b now?"; then
      override_agent jd-judge-b "$(jq -r '.tiers["judge-b"].variant // ""' "$PROFILE_FILE")"
    fi
  fi

  if confirm "override individual agents?"; then
    while :; do
      local items=("done")
      while IFS= read -r name; do
        items+=("$name -> $(decision_display "$name")")
      done < "$AGENTS_TMP"
      printf '\n' >&2
      name="$(choose "pick an agent to override" "done" "${items[@]}")"
      [ "$name" = "done" ] && break
      name="${name%% *}"
      override_agent "$name" ""
    done
  fi

  printf '\n%-22s %-15s %-38s %-10s %s\n' 'AGENT' 'TIER' 'MODEL' 'VARIANT' 'ACTION' >&2
  while IFS=$'\t' read -r name tier model variant; do
    case "$model" in
      KEEP) printf '%-22s %-15s %-38s %-10s %s\n' "$name" "$tier" "$(current_display "$name")" '' 'keep' >&2 ;;
      INHERIT) printf '%-22s %-15s %-38s %-10s %s\n' "$name" "$tier" '(inherits)' '' 'remove mapping' >&2 ;;
      *) printf '%-22s %-15s %-38s %-10s %s\n' "$name" "$tier" "$model" "$variant" 'set' >&2 ;;
    esac
  done < "$DECISIONS_TMP"
  name="$(awk -F'\t' '{ print $1 }' "$CURRENT_TMP" | grep -vxF -f "$AGENTS_TMP" || true)"
  [ -n "$name" ] && printf 'untouched non-harness entries: %s\n' "$(printf '%s' "$name" | tr '\n' ' ')" >&2

  changes="$(awk -F'\t' '$3 != "KEEP"' "$DECISIONS_TMP")"
  if [ -z "$changes" ]; then
    printf 'no changes.\n'
    return 0
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    confirm "apply to $CONFIG_FILE?" || { printf 'aborted, nothing written.\n'; return 0; }
  fi

  local set_json unset_json
  set_json="$(awk -F'\t' -v OFS='\t' '$3 != "KEEP" && $3 != "INHERIT" { print $1, $3, $4 }' "$DECISIONS_TMP" |
    jq -Rn '[inputs | split("\t")] | map({key: .[0], value: {model: .[1], variant: .[2]}}) | from_entries')"
  unset_json="$(awk -F'\t' '$3 == "INHERIT" { print $1 }' "$DECISIONS_TMP" | jq -Rn '[inputs]')"

  OUT_TMP="$(make_tmp)"
  config_json | jq --argjson set "$set_json" --argjson unset "$unset_json" '
    .agent = ((.agent // {})
      | reduce $unset[] as $n (.;
          if has($n) then
            (.[$n] |= del(.model, .variant))
            | if (.[$n] | length) == 0 then del(.[$n]) else . end
          else . end)
      | reduce ($set | to_entries[]) as $e (.;
          .[$e.key] = (((.[$e.key] // {}) + {model: $e.value.model})
            | if $e.value.variant != "-" then .variant = $e.value.variant else del(.variant) end)))
    | if (.agent | length) == 0 then del(.agent) else . end
  ' > "$OUT_TMP"
  jq empty "$OUT_TMP" || die "internal error: merged config is not valid JSON"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\ndry-run: would write %s\n' "$CONFIG_FILE" >&2
    if [ "$CONFIG_EXISTS" -eq 1 ]; then
      diff <(jq . "$CONFIG_FILE") <(jq . "$OUT_TMP") >&2 || true
    fi
    cat "$OUT_TMP"
    return 0
  fi

  mkdir -p "$root"
  if [ "$CONFIG_EXISTS" -eq 1 ]; then
    local backup
    backup="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_FILE" "$backup"
    printf 'backup: %s\n' "$backup"
  fi
  cat "$OUT_TMP" > "$CONFIG_FILE"
  printf 'wrote %s — restart OpenCode sessions to pick up model changes.\n' "$CONFIG_FILE"
}

# --- main --------------------------------------------------------------------

if [ "$#" -gt 0 ]; then
  case "$1" in
    configure|show) ACTION="$1"; shift ;;
    -h|--help|help) usage; exit 0 ;;
    -*) ACTION="configure" ;;
    *) die "unknown action: $1" ;;
  esac
else
  ACTION="configure"
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      shift
      [ "$#" -gt 0 ] || die "--profile requires a value"
      PROFILE_ARG="$1"
      ;;
    --project) PROJECT_TARGET=1 ;;
    --target)
      shift
      [ "$#" -gt 0 ] || die "--target requires a value"
      TARGET_ARG="$1"
      ;;
    --dry-run) DRY_RUN=1 ;;
    --models-file)
      shift
      [ "$#" -gt 0 ] || die "--models-file requires a value"
      MODELS_FILE="$(absolute_path "$1")"
      [ -f "$MODELS_FILE" ] || die "models file not found: $MODELS_FILE"
      ;;
    --catalog)
      shift
      [ "$#" -gt 0 ] || die "--catalog requires a value"
      CATALOG_ARG="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || die "jq is required"
trap cleanup EXIT INT TERM

case "$ACTION" in
  configure) run_configure ;;
  show) run_show ;;
  *) die "unknown action: $ACTION" ;;
esac
