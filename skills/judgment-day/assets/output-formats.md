# Output Format Templates

Read this file when synthesizing a verdict and when emitting the final judgment.

## Round Verdict + Approved

```markdown
## Judgment Day — {target}

### Round {N} — Verdict

| Finding | Judge A | Judge B | Severity | Status |
|---------|---------|---------|----------|--------|
| Missing null check in auth.go:42 | ✅ | ✅ | CRITICAL | Confirmed |
| SQL injection in query.go:57 | ❌ | ✅ | CRITICAL | Emphasis-confirmed (B zone) |
| Race condition in worker.go:88 | ✅ | ❌ | WARNING | Emphasis-confirmed (A zone) |
| Naming mismatch in handler.go:15 | ❌ | ✅ | SUGGESTION | Suspect (B only) |
| Error swallowed in db.go:201 | ✅ | ✅ | CRITICAL | Confirmed |

**Confirmed issues**: 2 CRITICAL
**Emphasis-confirmed issues**: 1 CRITICAL, 1 WARNING
**Suspect issues**: 1 SUGGESTION
**Contradictions**: none

### Fixes Applied (Round {N})
- `auth.go:42` — Added nil check before dereferencing user pointer
- `query.go:57` — Parameterized the query instead of string concatenation
- `worker.go:88` — Guarded shared counter with a mutex
- `db.go:201` — Propagated error instead of silently returning nil

### Round {N+1} — Re-judgment
- Judge A: PASS ✅ — No issues found
- Judge B: PASS ✅ — No issues found

---

### JUDGMENT: APPROVED ✅
Both judges pass clean. The target is cleared for merge.
```

## Verdict-Only Format (user chose "Stop here" at the verdict gate, or pre-set mode `verdict-only`)

```markdown
## Judgment Day — {target}

### JUDGMENT: VERDICT 📋

Review-only run — no fixes applied, no code touched.

### Findings
| Finding | Judge A | Judge B | Severity | Status |
|---------|---------|---------|----------|--------|
| {description} | ✅ | ✅ | CRITICAL | Confirmed |
| {description} | ❌ | ✅ | CRITICAL | Emphasis-confirmed (B zone) |
| {description} | ✅ | ❌ | SUGGESTION | Suspect (A only) |

**Confirmed issues**: {N}
**Emphasis-confirmed issues**: {N}
**Suspect issues**: {N}
**Contradictions**: {N}

Re-run judgment day and choose the fix loop to address the confirmed and emphasis-confirmed findings.
```

## Fixed-Unverified Format (user chose "Fix only" at the verdict gate)

```markdown
## Judgment Day — {target}

### JUDGMENT: FIXED (unverified) 🔧

Fix 1 applied to confirmed findings; no re-judge ran, so the fixes are unverified by the judges.

### Fixes Applied
- `{file:line}` — {what was fixed}

### Still Open (not fixed)
| Finding | Judge A | Judge B | Severity | Status |
|---------|---------|---------|----------|--------|
| {description} | ✅ | ❌ | WARNING | Suspect (A only) |

Re-run judgment day on the same target to verify the fixes.
```

## Escalation Format (after 2 failed fix iterations)

```markdown
## Judgment Day — {target}

### JUDGMENT: ESCALATED ⚠️

After 2 fix iterations, both judges still report issues.
Manual review required before proceeding.

### Remaining Issues
| Finding | Judge A | Judge B | Severity |
|---------|---------|---------|----------|
| {description} | ✅ | ✅ | CRITICAL |

### History
- Round 1: {N} confirmed issues found
- Fix 1: applied {list}
- Round 2: {N} issues remain
- Fix 2: applied {list}
- Round 3: {N} issues remain → escalated

Recommend: human review of the remaining issues above before re-running judgment day.
```

## Light Mode Formats (single judge, no synthesis)

Single-judge ledger — no A/B columns, no Confirmed/Suspect buckets. `JUDGMENT: INVALID ROUND` applies unchanged when the solo judge fails validity twice (there are no findings to preserve).

```markdown
## Judgment Day (light) — {target}

### JUDGMENT: LIGHT APPROVED ✅

Solo judge returned clean. The target is cleared for merge.
```

```markdown
## Judgment Day (light) — {target}

### JUDGMENT: LIGHT VERDICT 📋

Findings reported; no CRITICAL issues (or fixes declined) — no code touched.

| Finding | Severity | Category | Status |
|---------|----------|----------|--------|
| {description} | WARNING | {category} | open |
| {description} | SUGGESTION | {category} | open |

For higher confidence or automatic fixes beyond CRITICALs, re-run the full dual protocol.
```

```markdown
## Judgment Day (light) — {target}

### JUDGMENT: LIGHT FIXED (unverified) 🔧

CRITICAL findings fixed in one round; light mode never re-judges, so the fixes are unverified.

### Fixes Applied
- `{file:line}` — {what was fixed} ({JS-nnn})

### Still Open (reported, not auto-fixed)
| Finding | Severity | Category | Status |
|---------|----------|----------|--------|
| {description} | WARNING | {category} | open |

Re-run judgment day (full dual protocol) on the same target to verify the fixes.
```

## Invalid Round Format (a judge returned empty/malformed output twice)

```markdown
## Judgment Day — {target}

### JUDGMENT: INVALID ROUND ⚠️

Judge {A|B} returned an empty or malformed result and its single retry also failed.
No verdict was synthesized — one judge's view is not a judgment, and an empty result is never CLEAN.

### Unsynthesized Findings (Judge {A|B}, preserved in the ledger)
| Finding | Severity | Status |
|---------|----------|--------|
| {description} | {severity} | open (unsynthesized) |

Re-run judgment day on the same target; the preserved findings will be cross-checked in the new round.
```

## Stopped Format (user chose "Stop here" at a confirmation gate)

```markdown
## Judgment Day — {target}

### JUDGMENT: STOPPED 🛑 (user)

Protocol halted by user at the gate before {Round N | Fix N}.
No escalation implied — this is a deliberate stop, not a failure.

### Current State
| Finding | Judge A | Judge B | Severity | Status |
|---------|---------|---------|----------|--------|
| {description} | ✅ | ✅ | CRITICAL | {Fixed \| Open} |

### History
- Round 1: {N} confirmed issues found
- Fix 1: applied {list}
- {further rounds/fixes completed before the stop}
- Stopped by user before {next step}

Re-run judgment day on the same target to resume review.
```
