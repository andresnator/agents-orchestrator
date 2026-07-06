#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <plan.md>" >&2
  exit 2
fi

plan_file=$1
if [ ! -f "$plan_file" ]; then
  echo "plan-lint: file not found: $plan_file" >&2
  exit 2
fi

legacy_mode=0
case "$plan_file" in
  *-legacy-safety.md) legacy_mode=1 ;;
esac
if [ "$legacy_mode" -eq 0 ] && grep -q '^# Legacy Safety Plan:' "$plan_file"; then
  legacy_mode=1
fi

TMPDIR=${TMPDIR:-/tmp}
errors_file=$(mktemp "$TMPDIR/plan-lint-errors.XXXXXX")
cleanup() {
  rm -f "$errors_file"
}
trap cleanup EXIT INT TERM HUP

if awk -v FILE_PATH="$plan_file" -v LEGACY_MODE="$legacy_mode" '
BEGIN {
  pointer = "Concrete follow-up/deferred/hypothesis details are excluded from Sections 1-12; see Section 13."
  legacy = (LEGACY_MODE == 1)

  if (legacy) {
    expected[1]  = "## 1. Executive Summary"
    expected[2]  = "## 2. Target and Safety Scope"
    expected[3]  = "## 3. Unit Breakdown"
    expected[4]  = "## 4. Legacy Risk Observations"
    expected[5]  = "## 5. Characterization Coverage Plan"
    expected[6]  = "## 6. Seam and Isolation Opportunities"
    expected[7]  = "## 7. Tooling Audit and Provisioning"
    expected[8]  = "## 8. Prioritized Legacy Safety Backlog"
    expected[9]  = "## 9. Proposed Safety Sequence"
    expected[10] = "## 10. Validation and Rollback Plan"
    expected[11] = "## 11. Out of Scope and Follow-up"
    expected[12] = "## 12. Safety Gate Review Result"
    expected_count = 12
    yaml_section = 12
    require_tasks = 0
    target_lock_section = 2
    tooling_section = 7
  } else {
    expected[1]  = "## 1. Executive Summary"
    expected[2]  = "## 2. Target and Scope"
    expected[3]  = "## 3. Current Code Observations"
    expected[4]  = "## 4. Refactor Goals"
    expected[5]  = "## 5. Non-Goals"
    expected[6]  = "## 6. Findings by Category"
    expected[7]  = "## 7. Prioritized Refactor Backlog"
    expected[8]  = "## 8. Proposed Refactor Sequence"
    expected[9]  = "## 9. OpenSpec-Style Change"
    expected[10] = "## 10. Validation Strategy"
    expected[11] = "## 11. Risk and Rollback Plan"
    expected[12] = "## 12. Out of Scope"
    expected[13] = "## 13. Follow-up Plans"
    expected[14] = "## 14. Safety Gate Review Result"
    expected_count = 14
    yaml_section = 14
    require_tasks = 1
  }

  line_count = 0
  heading_count = 0
  output_file_seen = 0
  tasks_md_seen = 0
  in_tasks = 0
  current_section = 0
  plan_target_seen = 0
  tooling_marker_seen = 0
  final_section_started = 0
  final_section_code_fences = 0
  final_section_outside_text = 0
  final_section_status = 0
  final_section_blockers = 0
  final_section_required_fixes = 0
  final_section_final_safety_level = 0
  final_section_root = 0
  in_followup = 0
  followup_has_support = 0
}

function add_error(line, message) {
  errors[++error_count] = sprintf("%d:%s", line, message)
}

function is_blank(value) {
  return value ~ /^[[:space:]]*$/
}

function section_label(n) {
  if (n >= 1 && n <= expected_count) return expected[n]
  return "before first section"
}

function flush_followup(reason_line) {
  if (in_followup && !followup_has_support) {
    add_error(reason_line, "Section 13 follow-up block missing Evidence: or Hypothesis:")
  }
  in_followup = 0
  followup_has_support = 0
}

{
  line = $0
  line_count = NR

  if ($0 ~ /^Output file:[[:space:]]*`.+`[[:space:]]*$/) {
    output_file_seen = 1
  }

  if ($0 ~ /^## [0-9]+\./) {
    in_tasks = 0
    if (!legacy && current_section == 13) {
      flush_followup(NR - 1)
    }

    heading_count++
    if (heading_count > expected_count) {
      add_error(NR, "Unexpected extra top-level heading: " $0)
    } else if ($0 != expected[heading_count]) {
      add_error(NR, "Expected heading \"" expected[heading_count] "\" but found \"" $0 "\"")
    }
    current_section = heading_count
    heading_line[current_section] = NR
    pointer_count[current_section] = 0
    nonpointer_content[current_section] = 0
    next
  }

  if (current_section == 0) {
    next
  }

  if (legacy && current_section == target_lock_section && $0 ~ /^[[:space:]]*plan_target:/) {
    plan_target_seen = 1
  }

  if (legacy && current_section == tooling_section && ($0 ~ /No tooling gaps detected\./ || $0 ~ /verify-latest-at-execution: true/)) {
    tooling_marker_seen = 1
  }

  if (!legacy && index($0, pointer) > 0) {
    pointer_count[current_section]++
    if (pointer_count[current_section] > 1) {
      add_error(NR, "Generic Section 13 pointer repeated within " section_label(current_section))
    }
  } else if (!is_blank($0)) {
    nonpointer_content[current_section]++
  }

  if (!legacy && current_section != 13) {
    lower = tolower($0)
    if (lower ~ /deprecat/) {
      add_error(NR, "Section 13 leak heuristic matched deprecat outside Section 13")
    }
    if ($0 ~ /public API/) {
      add_error(NR, "Section 13 leak heuristic matched \"public API\" outside Section 13")
    }
    if ($0 ~ /Hypothesis:/) {
      add_error(NR, "Section 13 leak heuristic matched \"Hypothesis:\" outside Section 13")
    }
    if ($0 ~ /\b(FOLLOW[- ]?UP|FU)-[A-Za-z0-9_-]+\b/) {
      add_error(NR, "Section 13 leak heuristic matched follow-up identifier outside Section 13")
    }
  }

  if (require_tasks && $0 ~ /^### tasks\.md[[:space:]]*$/) {
    tasks_md_seen = 1
    in_tasks = 1
    next
  }

  if (in_tasks) {
    if (!is_blank($0) && $0 !~ /^### tasks\.md[[:space:]]*$/) {
      if ($0 !~ /^- \[ \]/ && $0 !~ /^  - /) {
        add_error(NR, "tasks.md contains a non-checkbox line")
      }
    }
  }

  if (!legacy && current_section == 13) {
    if ($0 ~ /^### Follow-up/) {
      flush_followup(NR - 1)
      in_followup = 1
      followup_has_support = 0
    } else if (in_followup && ($0 ~ /Evidence:/ || $0 ~ /Hypothesis:/)) {
      followup_has_support = 1
    }
  }

  if (current_section == yaml_section) {
    if (!final_section_started) {
      final_section_started = 1
    }
    if ($0 ~ /^```ya?ml[[:space:]]*$/ || $0 ~ /^```[[:space:]]*$/) {
      final_section_code_fences++
      in_section14_fence = !in_section14_fence
      next
    }
    if (!in_section14_fence && !is_blank($0)) {
      final_section_outside_text++
    }
    if (in_section14_fence) {
      if ($0 ~ /^[[:space:]]*status:/) final_section_status++
      if ($0 ~ /^[[:space:]]*blockers:/) final_section_blockers++
      if ($0 ~ /^[[:space:]]*required_fixes:/) final_section_required_fixes++
      if ($0 ~ /^[[:space:]]*final_safety_level:/) final_section_final_safety_level++
      if ($0 ~ /^[[:space:]]*safety_review:/) final_section_root++
    }
  }
}

END {
  if (!legacy && current_section == 13) {
    flush_followup(NR)
  }

  if (!output_file_seen) {
    add_error(1, "Missing exact Output file: label")
  }
  if (require_tasks && !tasks_md_seen) {
    add_error(1, "Missing tasks.md subsection")
  }
  if (heading_count != expected_count) {
    add_error(1, "Expected " expected_count " exact top-level headings, found " heading_count)
  }

  if (legacy && !plan_target_seen) {
    add_error(1, "Missing plan_target: echo in Section " target_lock_section)
  }
  if (legacy && !tooling_marker_seen) {
    add_error(1, "Section " tooling_section " missing \"No tooling gaps detected.\" or a verify-latest-at-execution: true install task")
  }

  if (!legacy) {
    for (i = 1; i <= 12; i++) {
      if (pointer_count[i] == 1 && nonpointer_content[i] == 0) {
        add_error(heading_line[i], section_label(i) " uses only the generic Section 13 pointer; expected \"No findings.\"")
      }
    }
  }

  if (final_section_started == 0) {
    add_error(1, "Missing final safety section content")
  } else {
    if (final_section_code_fences != 2) {
      add_error(1, "Final safety section must contain exactly one fenced YAML block")
    }
    if (final_section_outside_text > 0) {
      add_error(1, "Final safety section must not contain prose outside the fenced YAML block")
    }
    if (final_section_root != 1 || final_section_status != 1 || final_section_blockers != 1 || final_section_required_fixes != 1 || final_section_final_safety_level != 1) {
      add_error(1, "Final safety fenced YAML must contain exactly safety_review/status/blockers/required_fixes/final_safety_level")
    }
  }

  if (error_count > 0) {
    for (i = 1; i <= error_count; i++) {
      print errors[i]
    }
    exit 1
  }
}
' "$plan_file" > "$errors_file"; then
  awk_status=0
else
  awk_status=$?
fi

if [ "$awk_status" -ne 0 ] || [ -s "$errors_file" ]; then
  echo "plan-lint: FAIL $plan_file" >&2
  cat "$errors_file" >&2
  exit 1
fi

echo "plan-lint: OK $plan_file"
