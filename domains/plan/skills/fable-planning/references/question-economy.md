# Question Economy

Questions are expensive: each one blocks the user and interrupts their flow. Spend them only where they buy something exploration cannot.

## The question test

Before asking anything, classify it:

- **The repo can answer it** (does X exist? how is Y called? what pattern do tests use? which framework version?) → explore read-only. Asking these erodes trust in every question that follows.
- **Only the user can answer it** (scope boundaries, product trade-offs, priorities, acceptance criteria, risk appetite) → it earns a slot in the round.

## One grouped round, after exploring

- Explore first, then ask: exploration removes questions and sharpens the ones that remain.
- Batch every surviving question into a single round; do not drip them one turn at a time unless the runtime's interview skill (`grilling`) requires sequential flow.
- Each question carries a recommended answer, placed first, with a one-line reason. The user should be able to accept every recommendation and get a good plan.
- Skip anything the user already stated; restating it as a question reads as not listening.

## The edge-validation mini-round

Edge-case validation may surface decisions only the user can make (retention, failure policy, rollout). Accumulate them and ask at most **one** extra mini-round; anything that cannot wait for an answer becomes an explicit out-of-scope entry instead.

## Record the answers

Every answer becomes a decision line in the plan's Context, with its rationale — so a fresh session (or the executor) never re-litigates it.
