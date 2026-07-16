---
name: judgment-day
description: "Parallel adversarial review protocol that launches two independent blind judge sub-agents simultaneously to review the same target, synthesizes their findings, applies fixes, and re-judges until both pass or escalates after 2 iterations. Trigger: When user says \"judgment day\", \"judgment-day\", \"review adversarial\", \"dual review\", \"doble review\", \"juzgar\", \"que lo juzguen\"."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "1.8.1"
  status: in-progress
---

## When to Use

- User explicitly asks for "judgment day", "judgment-day", or equivalent trigger phrases
- After significant implementations before merging
- When high-confidence review of code, features, or architecture is needed
- When a single reviewer might miss edge cases or have blind spots
- When the cost of a production bug is higher than the cost of two review rounds

### Cost Gate

Judgment-day is the most expensive review in the toolkit (two blind judges + fix agent + re-judge rounds). Do not make it the default reflex: routine or small changes get the cheap single-reviewer check formalized as **Light Mode** below. Reserve the dual protocol for high-risk changes, large diffs, or SDD verification gates. An explicit user request always runs what was asked.

## Protocol

Only the orchestrator runs this protocol; it coordinates and synthesizes but NEVER reviews code itself. Judge and fix delegates work only on the scoped input they receive — they never coordinate rounds, synthesize buckets, decide escalation, or ask the user anything. If the target scope is unclear, stop and ask before launching — partial reviews are useless.

### Pattern 0: Skill Resolution (before launching judges)

Resolve project standards before launching ANY sub-agent. In OpenCode installs, the `skill-registry` plugin generates `.ai/atl/skill-registry.md` on session start.

1. Read `.ai/atl/skill-registry.md` from the project root if it exists; skip registry injection if it does not.
2. Identify the target files/scope the judges will review.
3. Match relevant skills from the registry's `## Skills` table by code context (file extensions/paths of the target) and task context (e.g., "review code" → framework/language skills).
4. Read the matched skills' `SKILL.md` files, cap the set to the 3-5 most relevant, and distill their actionable rules into a `## Project Standards (auto-resolved)` block.
5. Inject this block identically into BOTH judge prompts AND the fix agent prompt.

**If no registry exists**: warn the user ("No skill registry found — judges will review without project-specific standards. Ensure the skill-registry plugin is installed or wait for startup generation.") and proceed with generic review only.

### Pattern 1: Parallel Blind Review

- Launch **TWO** judge sub-agents via the runtime's sub-agent mechanism (e.g., the OpenCode `task` tool, Claude Code `Task`). When the runtime pre-registers `jd-judge-a`, `jd-judge-b`, and `jd-fix`, delegate to those agents; otherwise use the fallback prompts in `assets/judge-prompt.md`.
- Prefer parallel execution; if the runtime cannot run sub-agents in parallel, run the judges sequentially with isolated blind prompts.
- Each judge receives the **same target** but works **independently** — neither knows about the other, no cross-contamination.
- If the user provides custom review criteria, include them identically in BOTH judge prompts.
- **Review budget**: each judge performs exactly ONE full sweep of the target — two sweeps only when the diff exceeds ~400 changed lines or the brief flags hot paths. No loop-until-dry: when the sweep budget is spent, the judge reports what it has.
- Always wait for BOTH judges to complete before synthesizing — never accept a partial verdict.

**Result validity**: a judge result is valid only if it is exactly `VERDICT: CLEAN — No issues found.` or contains at least one well-formed finding (stable id + severity + `file:line` + failure scenario). An empty, truncated, or malformed response is **invalid — never CLEAN**. Relaunch only that judge once (fresh delegate, same blind prompt). If the retry is still invalid, the round is invalid: emit `JUDGMENT: INVALID ROUND` (see `assets/output-formats.md`) preserving the valid judge's findings in the ledger as unsynthesized — never synthesize a verdict from one judge, never report clean.

### Pattern 2: Verdict Synthesis

The **orchestrator** (NOT a sub-agent) compares both judges' returned results:

```
Confirmed          → found by BOTH agents                          → high confidence, fix immediately
Emphasis-confirmed → found by ONE judge, inside its emphasis zone,
                     severity CRITICAL or WARNING                  → treated exactly like Confirmed
Suspect A          → found ONLY by Judge A, outside its zone
                     or SUGGESTION                                 → needs triage
Suspect B          → found ONLY by Judge B, outside its zone
                     or SUGGESTION                                 → needs triage
Contradiction      → agents DISAGREE on the same thing             → flag for manual decision
```

**Emphasis zones**: Judge A's zone is correctness + edge-case; Judge B's zone is security + performance; `standards` findings are never emphasis-confirmed. Rationale: the judges intentionally sweep the same criteria in divergent priority order with a one-sweep budget, so a single-judge finding inside that judge's emphasis zone is expected coverage, not low confidence. An emphasis-confirmed finding keeps the reporting judge's id and records `zone: A|B` in the ledger.

**Findings ledger**: each judge numbers its own findings with stable ids (`JA-001`, `JA-002`… for Judge A; `JB-001`… for Judge B). The synthesis merges them into one findings ledger — the verdict table plus a `Status` column with lifecycle `open | fixed | verified | refuted | wont-fix`. Every finding enters as `open`; ids are never renumbered or reused across rounds. A confirmed finding keeps the A-side id and records the B-side id alongside it.

Present the ledger as a structured verdict table (see `assets/output-formats.md`). Suspect findings are reported but NOT automatically fixed — triage and escalate to the user if needed.

**CLEAN persistence**: a clean round still produces the full record — emit the verdict with its (empty) ledger even when both judges return `VERDICT: CLEAN`; the empty ledger is the evidence. When judgment-day runs inside an SDD change, the orchestrator stores each round's ledger in `.ai/orchestrator/changes/<change>/judgment.md`.

### Pattern 3: Fix and Re-judge (opt-in, user-gated)

Round 1 and the verdict synthesis always run. **After the verdict, nothing touches code without confirmation** — the fix/re-judge loop is opt-in.

1. If both judges return clean → JUDGMENT: APPROVED ✅ (no gate needed).
2. If **confirmed issues** exist → **verdict gate** (skipped when a mode is pre-set, see below). Summarize the verdict, then offer exactly:
   - **Fix and re-judge (full loop)** — run Fix 1, then continue with the gated loop below
   - **Fix only** — apply Fix 1, then stop and emit `JUDGMENT: FIXED (unverified)` 🔧
   - **Stop here (verdict only)** — emit `JUDGMENT: VERDICT` 📋 without touching code
3. Full loop: delegate a **Fix Agent** (a separate sub-agent, never one of the judges; fallback prompt in `assets/fix-prompt.md`); the fixer only touches confirmed and emphasis-confirmed findings. After Fix 1 completes → **loop gate** → re-launch **both judges in parallel** (same blind protocol, fresh delegates).
4. If the re-judge still finds confirmed issues → **loop gate** → Fix 2 → **loop gate** → re-judge (Round 3).
5. **Max 2 fix iterations.** If still failing → JUDGMENT: ESCALATED — report to user with full history; do not loop forever.
6. If both judges return clean → JUDGMENT: APPROVED ✅

**Pre-set mode**: when the caller declares a mode (e.g. the SDD `Judgment: light | verdict-only | full` line in `proposal.md`), skip the verdict gate: `light` runs Light Mode (below) with its automatic CRITICAL-only fix; `verdict-only` stops after the verdict report without asking; `full` proceeds as if "Fix and re-judge" was chosen. The loop gates still apply either way.

**Gates**: every gate is one question, presented via the `native-question-ux` skill (native mechanism when the runtime has one — e.g. Claude Code `AskUserQuestion`, OpenCode `question` — plain chat otherwise). The verdict gate offers the three options above; each **loop gate** (every re-judge and every fix after Fix 1) summarizes the current verdict, then offers exactly:

- **Continue (recommended)** — run the next step (re-judge or fix)
- **Escalate now** — stop looping, emit `JUDGMENT: ESCALATED` with the history so far
- **Stop here** — end the protocol, emit `JUDGMENT: STOPPED` reporting findings and fixes applied

The orchestrator owns every gate; judge and fix delegates never ask the user anything.

### Light Mode (single judge)

The cheap tier for bounded, medium-risk changes: ONE blind judge instead of two. Run it when the caller pre-sets `Judgment: light`, when the user asks for a light/solo judgment, or as the Cost Gate's single-reviewer check.

- Launch ONE judge: the pre-registered `jd-solo` agent when available, otherwise the fallback prompt in `assets/judge-prompt.md` in its solo variant (no A/B emphasis block, ids `JS-nnn`). Pattern 0 (skill resolution) applies unchanged.
- The Pattern 1 **result validity** rule applies to the single result: an empty, truncated, or malformed response is never CLEAN — retry that judge once (fresh delegate, same blind prompt); if still invalid, emit `JUDGMENT: INVALID ROUND` and stop.
- No Pattern 2 synthesis: there is nothing to cross-check. The ledger is single-judge — every well-formed finding enters as `open`; no Confirmed/Emphasis-confirmed/Suspect buckets.
- Fix flow: only **CRITICAL** findings go to the fix agent — maximum ONE fix round, and light mode never re-judges. With mode pre-set `light`, the fix launches without asking; otherwise the normal verdict gate applies. WARNING and SUGGESTION findings are reported, never auto-fixed.
- Verdicts (templates in `assets/output-formats.md`): `JUDGMENT: LIGHT APPROVED` ✅ (clean), `JUDGMENT: LIGHT VERDICT` 📋 (findings, none CRITICAL — or fixes declined), `JUDGMENT: LIGHT FIXED (unverified)` 🔧 (CRITICALs fixed, unverified by any re-judge), `JUDGMENT: INVALID ROUND` ⚠️.
- Escalation path: if a light verdict looks worse than expected (multiple CRITICALs, contradictory evidence), recommend re-running the full dual protocol on the same target instead of looping light rounds.

## Templates

Read these files on demand — each one says when:

- `assets/judge-prompt.md` — fallback judge prompt; only when `jd-judge-a`/`jd-judge-b` (or `jd-solo` for light mode) are not pre-registered, with an optional A/B emphasis differentiation mirroring those agents and a solo variant for light mode.
- `assets/fix-prompt.md` — fallback fix agent prompt; only when `jd-fix` is not pre-registered.
- `assets/output-formats.md` — verdict table plus APPROVED/VERDICT/FIXED/ESCALATED/STOPPED templates; read when synthesizing a verdict and when emitting the final judgment.
- `references/decision-tree.md` — the full step-by-step flow diagram with every confirmation gate.

## Language

- **Spanish input → Rioplatense**: "Juicio iniciado", "Los jueces están trabajando en paralelo...", "Los jueces coinciden", "Juicio terminado — Aprobado", "Escalado — necesita revisión humana"
- **English input**: "Judgment initiated", "Both judges are working in parallel...", "Both judges agree", "Judgment complete — Approved", "Escalated — requires human review"
