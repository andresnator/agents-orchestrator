---
name: fable-planning
description: "Trigger: deep plan, plan like Fable, planificar a fondo, fable plan. Fable-5-style planning: evidence before opinion, outcome-first selectivity, minimal calibrated questions, explicit edge-case validation, end-to-end verification plan."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "1.1.0"
---

## Activation Contract

Use when planning a feature, change, bugfix, or technical decision and the user wants a rigorous plan document before any code is written. Standalone in any agent, or as the methodology contract of the `deep-planner` agent (`/deep-plan`).

## Hard Rules

- Plan-only: read-only codebase access; no code edits, builds, installs, tests, or state-changing commands. The only writes are the planning artifacts themselves (the plan document, or the executor bundle files — see Output Contract).
- Every claim carries `path:line` evidence or is explicitly marked `hypothesis`. Verify that every referenced function, file, or utility exists before naming it.
- Every edge case ends in exactly one of three destinations — handled, explicitly out of scope, or open question. Never silently dropped.
- Interview/summaries use the user's language; the plan artifact defaults to English unless Spanish is explicitly requested.
- Calibrated reporting: state verified facts plainly without hedging; flag unverified or failed items just as plainly.

## Method

The four disciplines, applied as reasoning habits rather than pipeline phases:

1. **Evidence before opinion.** Never propose a design without having read the relevant code. Explore first: existing implementations, contracts, callers, test patterns. Reuse-first — search for existing functions, utilities, and patterns before proposing new code, and name everything reused as `path:symbol`. Record considered alternatives in one line each with why they were rejected. No speculative abstractions.
2. **Minimal calibrated questions.** The question test: if the repo can answer it, explore instead of asking. Only decisions that are genuinely the user's (scope, product trade-offs, acceptance criteria) reach the user — one grouped round after exploring, each question with a recommended answer first, skipping anything already stated in the request and never re-asking a decided question. Present via the `grilling` and `native-question-ux` skills when installed; otherwise plain chat. Record each answer as a decision in the plan's Context. See `references/question-economy.md`.
3. **Edge-case validation (the distinctive step).** Before closing the design, walk each branch of it against `references/edge-validation.md`: what inputs or states break this? Apply the three-destinations rule and build the plan's Edge Case Matrix (`edge | decision | where`). Open questions from this step get at most one extra mini-round.
4. **Outcome-first selectivity.** The plan opens with Context: what is being done, why, and the decisions already made with their rationale. Include only what changes what the executor will do; omit detail that alters no action. Depth is proportional to the task — a small task gets a short plan, and non-contributing sections are omitted, not padded.

Then always:

5. **End-to-end verification plan.** Every plan closes with how to prove the change by exercising the real flow — commands, the flow to drive, the observable expected result. Tests come after, not instead.
6. **Self-check before delivering** (fix violations first): every claim evidenced or `hypothesis`; every matrix edge has a destination; everything reused verified to exist; sections proportional to task size; Verification present and executable. Then offer an optional adversarial review of the plan (the `judgment-day` skill, when installed).

## Decision Gates

| Situation | Action |
| --- | --- |
| Answer is discoverable from repo/docs | Explore read-only instead of asking. |
| Scope spans several independent areas | Split exploration into parallel read-only briefs when the runtime supports sub-agents; otherwise explore sequentially. |
| Edge case has no destination | Resolve it (handle, scope out, or ask) before delivering; never drop it. |
| Task is small | Collapse the plan: Context + changes + Verification; state why edges are not relevant in one line. |
| A referenced skill is not installed | Say so and continue with the chat/plain fallback; never silently skip the discipline itself. |

## Output Contract

The disciplines above are the same regardless of what you emit; the artifact has two shapes:

- **Plan document** (default; decisions, investigations, and any runtime without a handoff contract): one document following `assets/plan-template.md` — Context (why + decisions), Design (approach, rejected alternatives, files with their content, reused `path:symbol`), Edge Case Matrix with a destination per row, and an executable end-to-end Verification section.
- **Executor bundle** (when the goal is an executable change and a handoff contract to an executor exists): the artifacts that contract defines, carrying the same Context / Design / Edge decisions and end-to-end Verification. Compose it by delegating each artifact to the executor's drafting sub-agents when the runtime provides them (e.g. OpenCode's `sdd-proposal` / `sdd-spec` / `sdd-design` / `sdd-tasks`); otherwise draft it inline from the executor's templates. You own the decisions and the evidence; the templates own the shape.

Report outcome-first in 2-4 lines: what was planned and where the artifact is, key decisions, and the optional next steps (adversarial review, execution).

## References

- `assets/plan-template.md`
- `references/edge-validation.md`
- `references/question-economy.md`
- `grilling` skill (question discipline)
- `native-question-ux` skill (question presentation)
- `judgment-day` skill (optional adversarial plan review)
