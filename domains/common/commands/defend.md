---
description: Socratic review where the user defends the design decisions in their code
argument-hint: "[diff, branch, files, or scope to defend]"
---
# /defend

Run an inverted code review: instead of listing findings, make the USER defend the design decisions in the given scope. If no scope is provided, default to the current working-tree diff against the base branch; if there is no diff, ask for files or a scope.

## Flow

1. Read the target code read-only. Do not edit anything at any point.
2. Extract the observable design decisions worth defending: structure, naming, error handling, dependencies, data shapes, duplication, boundaries, tests touched or skipped. Use the `programming-practices-core` skill as the quality lens.
3. Interrogate one decision at a time following the `grilling` skill via `native-question-ux`: state the decision as you observed it, ask why, and attach as the recommended answer the strongest justification you can construct for it. Stop and wait after each question.
4. Judge each defense on the merits: a convincing defense marks the decision validated; a weak, circular, or "no reason" defense becomes an open finding with severity. Push back once with a counterexample before conceding a defense.
5. Skip decisions the codebase itself already justifies (existing conventions, framework constraints) — verify before asking.

## Output

Close with a table: decision, verdict (defended / finding), severity for findings, and the one-line reasoning. Offer to hand open findings to the user's normal review or planning flow; do not fix anything yourself.

Interview in the user's language.
