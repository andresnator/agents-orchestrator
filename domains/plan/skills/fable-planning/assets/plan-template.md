# <change, verb-led>

<!-- Proportionality: for small tasks, Edge cases may be a single line
     ("no relevant edges: <why>") and Design collapses into the change list.
     Omit non-contributing sections; never pad them. -->

## Context

<Why this is being done, what prompted it, and the intended outcome.
Decisions already made with the user and their rationale, in prose.>

## Design

<Chosen approach and why. Rejected alternatives: one line each.>

<Files to touch, with what goes in each. Reuse `path:symbol` instead of
creating new code; every claim carries `path:line` evidence or `hypothesis`.>

## Edge cases

| Edge | Decision | Where |
|---|---|---|

<!-- Decision is exactly one of: handled / out of scope / open question.
     Open questions must be resolved before the plan is delivered. -->

## Verification

<How to prove the change end-to-end by exercising the real flow:
commands, the flow to drive, the observable expected result.
Tests come after, not instead.>
