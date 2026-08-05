# Delegation Receipts

A delegation receipt is the compact, machine-scannable return a subagent sends back to its caller instead of prose or a full artifact. Subagent returns are injected verbatim into the parent's context, so their size is a direct token cost multiplied by every delegation; receipts keep that cost flat and let the parent branch on fields instead of re-reading files. The pattern was adapted from the Caveman project's cavecrew agents onto the receipt idiom this repo already used in `refactor-analyzer` and `arch-analyzer`.

## Conventions

Every receipt in this repo follows the same conventions; the concrete schema lives inline in each agent's Output section, not in a shared skill.

- **Compact YAML.** One block, keys the caller branches on, no surrounding prose.
- **Identity echo.** The receipt echoes the identity keys from the brief (`change`, `wave`, `diff_range`, …) so the caller can match returns to briefs without inference; only the receipt's own clean-case terminal token may precede them.
- **Evidence stays pointers.** `file:line` references and one-line test results only — never logs, code blocks, or diff excerpts. The parent verifies by following pointers, not by trusting pasted output.
- **Terminal token for the clean case.** A fixed string the caller can match exactly: `VERDICT: CLEAN — No issues found.` (judges), `VERIFY: ALL PASS — <n>/<n> scenarios.` (verify), `FIX: <n> fixed, <m> open.` (fix rounds). Each receipt's template fixes the token's position — the verify receipts emit it as the first line of the receipt, `jd-fix` as the last. Callers key control flow on these strings; change them only as a breaking contract change.
- **`blockers: []` as the refusal channel.** A subagent that cannot proceed says why in `blockers` (or `open_questions` for drafting agents, `nf: <reason>` for read-only fan-outs) instead of guessing or returning partial prose.
- **Per-item size caps, not count caps.** Findings are capped in size (scenario ≤ 2 lines, fix = 1 line of intent), and repeated instances of one defect collapse into one row with multiple `evidence` entries. Real defects are never dropped to fit a count.
- **Never return the artifact.** An agent that writes a file returns its path plus assertion fields (`first_line`, `forecast_guards`, …) the caller checks instead of re-reading the file wholesale.

## Where it is used

- `domains/sdd/agents/sdd-verify.md` — scenario receipt with `gaps` rows that seed fix briefs directly.
- `domains/sdd-lite/agents/lite-verify.md` — the sdd-lite fork of the `sdd-verify` receipt (same shape and terminal token), consumed by `orchestralite`; duplicated deliberately so the POC domain installs standalone.
- `domains/sdd/agents/sdd-implement.md` — wave receipt with one `assertions` row per task (`task -> file:line`) so the orchestraitor integrates from fields instead of rereading the wave's files; a non-empty `out_of_scope` triggers re-planning. Workers never stage or commit; the orchestraitor owns the Git index after reconciliation. A `merge` brief returns a different receipt: `merged` rows (one per delta, RENAMED naming both sides), `specs_written`, and `stale` as the leftover channel.
- `domains/sdd/agents/jd-judge-a.md`, `jd-judge-b.md`, `jd-solo.md` — findings receipt (plus `verdicts` in re-judge rounds); consumed by the `judgment-day` synthesis.
- `domains/sdd/agents/jd-fix.md` — fixes receipt.
- `domains/sdd/agents/sdd-proposal.md`, `sdd-spec.md`, `sdd-design.md`, `sdd-tasks.md` — drafting receipts echo `draft_context: active | handoff` plus path and assertion fields; consumed by the sdd `orchestraitor` and the plan `deep-planner` (step 8 reconciles from receipts and re-reads only `tasks.md`). In light mode `sdd-proposal` extends its receipt with `deltas`, `task_ids`, and one aggregate `files` scope; the orchestraitor runs that bounded change as one sequential wave without reading `change.md`.
- `domains/refactor/agents/refactor-analyzer.md`, `domains/architecture/agents/arch-analyzer.md` — the pre-existing analyzer idiom (max 7 findings, `Output budget` brief field) this pattern generalizes.

## Writing a new one

Give the subagent's Output section a receipt matched to what its caller actually branches on — nothing more. Echo identity keys, define the clean-case terminal token, add the refusal channel, and cap per-item size. In the caller, briefs say "return your Output receipt" and never restate the shape; skill or registry context injected into a brief stays capped at the 3–5 most relevant skills as distilled rules.
