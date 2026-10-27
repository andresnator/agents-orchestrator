---
name: oc-debug
description: "Trigger: debug, debugging, root cause, root-cause analysis, why does this fail, intermittent failure, shotgun fixes. Root-cause debugging loop: reproduce, gather evidence, one falsifiable hypothesis, minimal verified fix."
license: MIT
metadata:
  author: obra
  adapted_by: andresnator
  source: obra/superpowers
  version: "2.1.0"
  status: testing
---

# Systematic Debugging

## Intent

- **Goal:** Find and fix the verified root cause of a failure with a minimal fix.
- **Limits:** No fix before a reproduction exists; without one, the work is still investigation. Never dump environment variables, credentials, tokens, or full config files into output or logs; for sensitive values log names, lengths, or shapes, not contents. Skip a phase only when you can state why its output is already known.
- **Fails if:** Shotgun debugging (changing several things at once to "see if it helps"); stacking a second speculative fix on an unverified first one; silencing the symptom (catch-and-ignore, retry loops, widened timeouts) while the cause is unknown; declaring "fixed" without a fresh run of the original reproduction.

## Context

- **Reads:** The actual error, stack trace, and logs (quote the relevant lines, not a paraphrase); a known-working state such as recent diffs, a passing sibling case, or another environment.
- **Never reads:** Secret values.
- **Persona:** Disciplined investigator.
- **Scope:** Debugging and root-cause analysis, including intermittent failures and shotgun fixes.

## Expectations

- **Scenarios:**
  - WHEN a failure is reported THEN capture the exact command or interaction, its full output, and exit status, then shrink it to the smallest failing input and scope.
  - WHEN the failure is intermittent THEN record the observed frequency and conditions instead of treating it as deterministic.
  - WHEN three consecutive hypotheses are refuted THEN stop and reassess: question the layer, widen the evidence, or surface what you know and ask the user.
- **Done means:** The verified cause is fixed with one coherent change; the original reproduction is re-run and its fresh result cited; a regression test is added, or its absence is stated explicitly (no harness, out-of-scope infrastructure); experiment leftovers (probes, temporary logging, disabled checks) are reverted.
- **Quality needs:** A fix claim needs the evidence standard of any completion claim.

## Method

1. **Gather evidence:** locate the failure boundary, the last point where state is known good and the first point where it is wrong.
2. **One hypothesis:** state exactly one falsifiable hypothesis ("X causes this; if true I will observe A, if false B"). Test it with the smallest probe that can refute it (a log line, a focused test, a narrowed input), not a speculative code change. Record the result; a refuted hypothesis is progress, an untested one is noise.
