---
name: judgment-day
description: "Parallel adversarial review protocol that launches two independent blind judge sub-agents simultaneously to review the same target, synthesizes their findings, applies fixes, and re-judges until both pass or escalates after 2 iterations. Trigger: When user says \"judgment day\", \"judgment-day\", \"review adversarial\", \"dual review\", \"doble review\", \"juzgar\", \"que lo juzguen\".\n"
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "1.4.1"
  status: in-progress
---

## When to Use

- User explicitly asks for "judgment day", "judgment-day", or equivalent trigger phrases
- After significant implementations before merging
- When high-confidence review of code, features, or architecture is needed
- When a single reviewer might miss edge cases or have blind spots
- When the cost of a production bug is higher than the cost of two review rounds

### Cost Gate

Judgment-day is the most expensive review in the toolkit (two blind judges + fix agent + re-judge rounds). Do not make it the default reflex: routine or small changes get a cheap single-reviewer check. Reserve judgment-day for high-risk changes, large diffs, or SDD verification gates. An explicit user request always runs it.

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
- Always wait for BOTH judges to complete before synthesizing — never accept a partial verdict.

### Pattern 2: Verdict Synthesis

The **orchestrator** (NOT a sub-agent) compares both judges' returned results:

```
Confirmed   → found by BOTH agents          → high confidence, fix immediately
Suspect A   → found ONLY by Judge A         → needs triage
Suspect B   → found ONLY by Judge B         → needs triage
Contradiction → agents DISAGREE on the same thing → flag for manual decision
```

Present findings as a structured verdict table (see `assets/output-formats.md`). Suspect findings are reported but NOT automatically fixed — triage and escalate to the user if needed.

### Pattern 3: Fix and Re-judge (user-gated after the first fix)

Round 1 and the first fix run automatically. After Fix 1, **every** further step — each re-judge round and each additional fix — requires explicit user confirmation first.

1. If **confirmed issues** exist → delegate a **Fix Agent** (a separate sub-agent, never one of the judges; fallback prompt in `assets/fix-prompt.md`). Fix 1 needs no confirmation, and the fixer only touches confirmed findings.
2. After Fix 1 completes → **confirmation gate** → re-launch **both judges in parallel** (same blind protocol, fresh delegates).
3. If the re-judge still finds confirmed issues → **confirmation gate** → Fix 2 → **confirmation gate** → re-judge (Round 3).
4. **Max 2 fix iterations.** If still failing → JUDGMENT: ESCALATED — report to user with full history; do not loop forever.
5. If both judges return clean → JUDGMENT: APPROVED ✅

**Confirmation gate**: one question, presented via the `native-question-ux` skill (native mechanism when the runtime has one — e.g. Claude Code `AskUserQuestion`, OpenCode `question` — plain chat otherwise). Summarize the current verdict, then offer exactly:

- **Continue (recommended)** — run the next step (re-judge or fix)
- **Escalate now** — stop looping, emit `JUDGMENT: ESCALATED` with the history so far
- **Stop here** — end the protocol, emit `JUDGMENT: STOPPED` reporting findings and fixes applied

The orchestrator owns the gate; judge and fix delegates never ask the user anything.

## Templates

Read these files on demand — each one says when:

- `assets/judge-prompt.md` — fallback judge prompt; only when `jd-judge-a`/`jd-judge-b` are not pre-registered, with an optional A/B emphasis differentiation mirroring those agents.
- `assets/fix-prompt.md` — fallback fix agent prompt; only when `jd-fix` is not pre-registered.
- `assets/output-formats.md` — verdict table plus APPROVED/ESCALATED/STOPPED templates; read when synthesizing a verdict and when emitting the final judgment.
- `references/decision-tree.md` — the full step-by-step flow diagram with every confirmation gate.

## Language

- **Spanish input → Rioplatense**: "Juicio iniciado", "Los jueces están trabajando en paralelo...", "Los jueces coinciden", "Juicio terminado — Aprobado", "Escalado — necesita revisión humana"
- **English input**: "Judgment initiated", "Both judges are working in parallel...", "Both judges agree", "Judgment complete — Approved", "Escalated — requires human review"
