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

TMPDIR=${TMPDIR:-/tmp}
errors_file=$(mktemp "$TMPDIR/plan-lint-errors.XXXXXX")
cleanup() {
  rm -f "$errors_file"
}
trap cleanup EXIT INT TERM HUP

if awk -v FILE_PATH="$plan_file" '
BEGIN {
  expected[1] = "## 1. Executive Summary"
  expected[2] = "## 2. Target and Scope"
  expected[3] = "## 3. Risk and Depth Assessment"
  expected[4] = "## 4. Observations"
  expected[5] = "## 5. Goals"
  expected[6] = "## 6. Non-Goals"
  expected[7] = "## 7. Findings by Category"
  expected[8] = "## 8. Characterization Coverage Plan"
  expected[9] = "## 9. Tooling Audit"
  expected[10] = "## 10. Backlog"
  expected[11] = "## 11. Sequence"
  expected[12] = "## 12. OpenSpec-Style Change"
  expected[13] = "## 13. Validation"
  expected[14] = "## 14. Risk & Rollback"
  expected[15] = "## 15. Execution Contract"
  expected[16] = "## 16. Follow-up"
  expected[17] = "## 17. Safety Gate Result"
  expected_count = 17

  category[1] = "### 7.1 Naming and Readability"
  category[2] = "### 7.2 Function Size and Responsibility"
  category[3] = "### 7.3 SOLID Design"
  category[4] = "### 7.4 Duplication and Simplicity"
  category[5] = "### 7.5 Cohesion and Coupling"
  category[6] = "### 7.6 Type Contracts and Nullability"
  category[7] = "### 7.7 Complexity and Performance"
  category[8] = "### 7.8 Antipatterns"
  category[9] = "### 7.9 Logging and Observability"
  category[10] = "### 7.10 Characterization and Seams"
  category_count = 10

  heading_count = 0
  current_section = 0
  output_file_seen = 0
  risk_seen = 0
  depth_seen = 0
  depth_value = ""
  plan_target_seen = 0
  placeholder8_seen = 0
  placeholder9_seen = 0
  proposal_seen = 0
  design_seen = 0
  spec_seen = 0
  tasks_seen = 0
  in_tasks = 0
  contract_approved_seen = 0
  contract_validation_seen = 0
  contract_tasks_seen = 0
  contract_evidence_seen = 0
  contract_deviation_seen = 0
  contract_tcr_seen = 0
  contract_revert_seen = 0
  contract_drift_seen = 0
  final_section_started = 0
  final_section_code_fences = 0
  final_section_outside_text = 0
  final_section_root = 0
  final_section_status = 0
  final_section_blockers = 0
  final_section_required_fixes = 0
  final_section_final_safety_level = 0
  expected_task_number = 1
  in_task_block = 0
}

function add_error(line, message) {
  errors[++error_count] = sprintf("%d:%s", line, message)
}

function is_blank(value) {
  return value ~ /^[[:space:]]*$/
}

function flush_task(line_number) {
  if (!in_task_block) return
  if (!task_evidence_seen) add_error(line_number, "tasks.md task missing Evidence")
  if (!task_validation_seen) add_error(line_number, "tasks.md task missing Validation")
  if (!task_rollback_seen) add_error(line_number, "tasks.md task missing Rollback")
  in_task_block = 0
  task_evidence_seen = 0
  task_validation_seen = 0
  task_rollback_seen = 0
}

{
  line = $0

  if (line ~ /^Output file:[[:space:]]*`\.ia-refactor\/plan\/[0-9]{8}\/[^`]+\.md`[[:space:]]*$/) output_file_seen = 1
  if (line ~ /^Risk:[[:space:]]*(low|medium|high|critical)[[:space:]]*$/) risk_seen = 1
  if (line ~ /^Depth:[[:space:]]*(light|standard|deep|smoke)[[:space:]]*$/) {
    depth_seen = 1
    depth_value = line
    sub(/^Depth:[[:space:]]*/, "", depth_value)
    sub(/[[:space:]]*$/, "", depth_value)
  }

  if (line ~ /^## [0-9]+\./) {
    if (in_tasks) flush_task(NR - 1)
    in_tasks = 0
    heading_count++
    if (heading_count > expected_count) {
      add_error(NR, "Unexpected extra top-level heading: " line)
    } else if (line != expected[heading_count]) {
      add_error(NR, "Expected heading \"" expected[heading_count] "\" but found \"" line "\"")
    }
    current_section = heading_count
    next
  }

  if (current_section == 0) next

  if (current_section == 2 && line ~ /^[[:space:]]*plan_target:/) plan_target_seen = 1

  if (current_section == 7) {
    for (i = 1; i <= category_count; i++) {
      if (line == category[i]) category_seen[i]++
    }
  }

  if (current_section == 8 && line ~ /^Not required at depth: (light|standard|smoke)\.[[:space:]]*$/) placeholder8_seen = 1
  if (current_section == 9 && line ~ /^Not required at depth: (light|standard|smoke)\.[[:space:]]*$/) placeholder9_seen = 1

  if (current_section == 12) {
    if (line ~ /^### proposal\.md[[:space:]]*$/) proposal_seen++
    if (line ~ /^### design\.md[[:space:]]*$/) design_seen++
    if (line ~ /^### specs\/<capability>\/spec\.md[[:space:]]*$/) spec_seen++
    if (line ~ /^### tasks\.md[[:space:]]*$/) {
      tasks_seen++
      in_tasks = 1
      next
    }
  }

  if (in_tasks) {
    if (line ~ /^- \[ \] Task [0-9]+:/) {
      flush_task(NR - 1)
      task_number = line
      sub(/^- \[ \] Task /, "", task_number)
      sub(/:.*/, "", task_number)
      if ((task_number + 0) != expected_task_number) {
        add_error(NR, "tasks.md task numbers must be sequential starting at 1")
      }
      expected_task_number++
      in_task_block = 1
      task_evidence_seen = 0
      task_validation_seen = 0
      task_rollback_seen = 0
    } else if (line ~ /^  - Evidence:/) {
      task_evidence_seen = 1
    } else if (line ~ /^  - Validation:/) {
      task_validation_seen = 1
    } else if (line ~ /^  - Rollback:/) {
      task_rollback_seen = 1
    } else if (!is_blank(line)) {
      add_error(NR, "tasks.md contains a non-contract line")
    }
  }

  if (current_section == 15) {
    if (line ~ /(approved|Section 17)/) contract_approved_seen = 1
    if (line ~ /Validation/) contract_validation_seen = 1
    if (line ~ /tasks\.md/) contract_tasks_seen = 1
    if (line ~ /Evidence/) contract_evidence_seen = 1
    if (line ~ /deviation/) contract_deviation_seen = 1
    if (line ~ /TCR/) contract_tcr_seen = 1
    if (line ~ /revert/) contract_revert_seen = 1
    if (line ~ /drift/) contract_drift_seen = 1
  }

  if (current_section != 16 && current_section != 17) {
    lower = tolower(line)
    if (lower ~ /deprecat/) add_error(NR, "Section 16 leak heuristic matched deprecat outside Section 16")
    if (line ~ /public API/) add_error(NR, "Section 16 leak heuristic matched public API outside Section 16")
    if (line ~ /Hypothesis:/) add_error(NR, "Section 16 leak heuristic matched Hypothesis outside Section 16")
    if (line ~ /\b(FOLLOW[- ]?UP|FU)-[A-Za-z0-9_-]+\b/) add_error(NR, "Section 16 leak heuristic matched follow-up identifier outside Section 16")
  }

  if (current_section == 17) {
    if (!final_section_started) final_section_started = 1
    if (line ~ /^```ya?ml[[:space:]]*$/ || line ~ /^```[[:space:]]*$/) {
      final_section_code_fences++
      in_final_fence = !in_final_fence
      next
    }
    if (!in_final_fence && !is_blank(line)) final_section_outside_text++
    if (in_final_fence) {
      if (line ~ /^[[:space:]]*safety_review:/) final_section_root++
      if (line ~ /^[[:space:]]*status:/) {
        final_section_status++
        status_value = line
        sub(/^[[:space:]]*status:[[:space:]]*/, "", status_value)
        gsub(/"/, "", status_value)
        gsub(/\047/, "", status_value)
        if (status_value !~ /^(approved|needs_changes)$/) add_error(NR, "Final safety status must be approved or needs_changes")
      }
      if (line ~ /^[[:space:]]*blockers:/) {
        final_section_blockers++
        if (line !~ /^[[:space:]]*blockers:[[:space:]]*\[/) add_error(NR, "Final safety blockers must be an array")
      }
      if (line ~ /^[[:space:]]*required_fixes:/) {
        final_section_required_fixes++
        if (line !~ /^[[:space:]]*required_fixes:[[:space:]]*\[/) add_error(NR, "Final safety required_fixes must be an array")
      }
      if (line ~ /^[[:space:]]*final_safety_level:/) {
        final_section_final_safety_level++
        safety_value = line
        sub(/^[[:space:]]*final_safety_level:[[:space:]]*/, "", safety_value)
        gsub(/"/, "", safety_value)
        gsub(/\047/, "", safety_value)
        if (safety_value !~ /^(low|medium|high)$/) add_error(NR, "Final safety level must be low, medium, or high")
      }
    }
  }
}

END {
  if (in_tasks) flush_task(NR)

  if (!output_file_seen) add_error(1, "Missing exact Output file: label")
  if (!risk_seen) add_error(1, "Missing Risk: prelude")
  if (!depth_seen) add_error(1, "Missing Depth: prelude")
  if (heading_count != expected_count) add_error(1, "Expected 17 exact top-level headings, found " heading_count)
  if (!plan_target_seen) add_error(1, "Missing plan_target: echo in Section 2")

  for (i = 1; i <= category_count; i++) {
    if (category_seen[i] != 1) add_error(1, "Missing or duplicate findings subsection: " category[i])
  }

  if (depth_value == "light" || depth_value == "standard" || depth_value == "smoke") {
    if (!placeholder8_seen) add_error(1, "Section 8 missing required depth placeholder")
    if (!placeholder9_seen) add_error(1, "Section 9 missing required depth placeholder")
  }

  if (proposal_seen != 1 || design_seen != 1 || spec_seen != 1 || tasks_seen != 1) {
    add_error(1, "Section 12 must contain proposal.md/design.md/specs/<capability>/spec.md/tasks.md exactly once")
  }

  if (contract_approved_seen + contract_validation_seen + contract_tasks_seen + contract_evidence_seen + contract_deviation_seen + contract_tcr_seen + contract_revert_seen + contract_drift_seen < 8) {
    add_error(1, "Section 15 execution contract is missing required executor constraints")
  }

  if (!final_section_started) {
    add_error(1, "Missing final safety section content")
  } else {
    if (final_section_code_fences != 2) add_error(1, "Final safety section must contain exactly one fenced YAML block")
    if (final_section_outside_text > 0) add_error(1, "Final safety section must not contain prose outside the fenced YAML block")
    if (final_section_root != 1 || final_section_status != 1 || final_section_blockers != 1 || final_section_required_fixes != 1 || final_section_final_safety_level != 1) {
      add_error(1, "Final safety fenced YAML must contain exactly safety_review/status/blockers/required_fixes/final_safety_level")
    }
  }

  if (error_count > 0) {
    for (i = 1; i <= error_count; i++) print errors[i]
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
