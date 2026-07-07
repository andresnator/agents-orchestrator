---
description: Pre-mortem interview that produces a prioritized risk register
argument-hint: "[feature, plan, or change to stress-test]"
---
# /premortem

Run a pre-mortem interview on the requested feature, plan, or change. If no target is provided, ask for it before starting.

Premise: assume the work shipped and failed six months from now. The interview reconstructs why.

## Flow

1. Load the `grilling` and `risk-assessment` skills. Follow `grilling` throughout: one question at a time via `native-question-ux`, attach a recommended answer, stop and wait, and explore the codebase instead of asking when the answer is discoverable.
2. Interview across failure categories, moving on when a category is exhausted or clearly not applicable: technical/design failure, scope and requirements, external dependencies and integrations, people and process, security and data, operations and rollout.
3. For each failure the user (or your codebase evidence) surfaces, capture it as a risk and rate it with the `risk-assessment` skill: likelihood, impact, and a concrete mitigation or early-warning signal.
4. Stop interviewing when new questions stop producing new risks, or the user calls it.

## Output

Close with a prioritized risk register (likelihood × impact ordering): risk, category, rating, mitigation, and owner/next step when known.

Offer once to write the register to `.ai/plan-architect/plans/{kebab-case-topic}-premortem.md`; on no, leave it inline. Interview in the user's language; the written artifact defaults to English.
