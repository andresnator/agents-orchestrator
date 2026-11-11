# Question Economy

Questions are expensive: each one blocks the user and interrupts their flow. Spend them only where they buy something exploration cannot.

## The question test

Before asking anything, classify it:

- **The repo can answer it** (does X exist? how is Y called? what pattern do tests use? which framework version?) → explore read-only. Asking these erodes trust in every question that follows.
- **Only the user can answer it** (scope boundaries, product trade-offs, priorities, acceptance criteria, risk appetite) → it earns a slot in the round.

## Before you ask

- Explore first, then ask: exploration removes questions and sharpens the ones that remain.
- Skip anything the user already stated; restating it as a question reads as not listening.

## Edge validation

Edge-case validation may surface decisions only the user can make, such as retention, failure policy, or rollout. Ask each blocking open decision conversationally. Defer it to an explicit out-of-scope or open-question entry only when the user chooses not to resolve it now.

## Record the answers

Record every answer with its rationale in the plan, so a fresh session or executor never re-litigates it: a design choice goes in `Approach`; a risk, a deferred decision, or a rollback condition goes in `Risks and open questions`.
