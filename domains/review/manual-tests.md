# Review manual tests

Run these cases against a disposable diff with known review signals. Review stays independent from Orchestration; code changes occur only inside an explicitly authorized Judgment fix.

## Quick path

1. Install the current checkout's `review,common` domains into a disposable project with a reviewable diff.
2. Run the affected IDs from the catalog summary.
3. Compare findings and authorized edits with the original diff, then discard the project.

### MT-REVIEW-JUDGMENT-FULL

- **Title:** Synthesize two blind full Judgment reviews
- **Coverage key:** `review/judgment/full-synthesis`
- **Applies to:** `domains/review/agents/review-coordinator.md`, `domains/review/agents/jd-judge-a.md`, `domains/review/agents/jd-judge-b.md`, `domains/review/commands/judgment.md`, `domains/review/skills/judgment-day/**`
- **Preconditions:** Use a disposable diff with one observable correctness issue and one harmless style difference; do not authorize fixes.
- **Steps:**
  1. Run `/judgment <exact-diff>` without the `light` selector.
  2. Inspect task activity, evidence lines, synthesis, ledger, and working tree before any fix answer.
- **Expected result:** Two isolated blind judges run with different emphases, findings require exact failure evidence, synthesis removes unsupported noise, and no file changes before explicit authorization.
- **Cleanup:** Close the review session and discard the disposable project.

### MT-REVIEW-JUDGMENT-LIGHT

- **Title:** Run one balanced light Judgment sweep
- **Coverage key:** `review/judgment/light-sweep`
- **Applies to:** `domains/review/agents/review-coordinator.md`, `domains/review/agents/jd-solo.md`, `domains/review/commands/judgment.md`, `domains/review/skills/judgment-day/**`
- **Preconditions:** Use a disposable diff with one observable critical defect and one non-critical improvement.
- **Steps:**
  1. Run `/judgment light <exact-diff>`.
  2. Inspect worker activity, findings, totals, and any offered fix boundary.
- **Expected result:** Exactly one solo judge performs a balanced sweep, reports exact evidence, never re-judges, and treats only a critical finding as eligible for the bounded light fix.
- **Cleanup:** Close the session and discard the disposable project.

### MT-REVIEW-FIX-AUTHORIZATION

- **Title:** Apply only explicitly authorized review fixes
- **Coverage key:** `review/fixes/authorization-boundary`
- **Applies to:** `domains/review/agents/review-coordinator.md`, `domains/review/agents/jd-fix.md`, `domains/review/commands/judgment.md`, `domains/review/skills/judgment-day/**`, `domains/review/skills/code-conventions/**`
- **Preconditions:** Complete a full Judgment in a disposable project with two confirmed findings in separate files.
- **Steps:**
  1. Authorize exactly one finding and decline the other.
  2. Inspect the diff, named check, re-judgment verdict for the authorized ID, and open ledger entry.
- **Expected result:** `jd-fix` changes only the authorized finding with a minimal diff, runs its named check, leaves the declined finding and unrelated code untouched, and performs no Git delivery.
- **Essential negative variant:** Decline every fix and confirm the working tree remains byte-for-byte unchanged.
- **Cleanup:** Discard the disposable project.

### MT-REVIEW-DEFEND

- **Title:** Challenge one design decision read-only
- **Coverage key:** `review/defend/socratic-verdict`
- **Applies to:** `domains/review/agents/review-coordinator.md`, `domains/review/commands/defend.md`, `domains/review/skills/programming-practices-core/**`
- **Preconditions:** Use a disposable diff containing one deliberate design trade-off with available source evidence.
- **Steps:**
  1. Run `/defend <exact-scope>` and answer the first evidence-backed design question.
  2. Defend the decision, then inspect the challenge, verdict, findings, and working tree.
- **Expected result:** The coordinator handles one observable decision at a time, includes the strongest evidence-backed defense, accepts or challenges it once, and never delegates a fix or edits files.
- **Cleanup:** Close the session and discard the disposable project.
