# Full Decision Tree

Complete flow of the judgment-day protocol including every confirmation gate. The compact protocol in `SKILL.md` is authoritative; this diagram expands it step by step.

## Light Mode branch (single judge)

Entered when the caller pre-set `Judgment: light`, or the user asked for a light/solo judgment.

```
Light mode requested
│
├── Target is specific files/feature/component?
│   ├── YES → continue
│   └── NO → ask user to specify scope before proceeding
▼
Resolve skills (Pattern 0) → launch ONE judge (jd-solo, or solo-variant fallback prompt)
▼
Result valid? (exact CLEAN string, or ≥1 well-formed finding)
├── NO → retry that judge once → still invalid → JUDGMENT: INVALID ROUND ⚠️ (stop)
└── YES ▼
    ├── CLEAN → JUDGMENT: LIGHT APPROVED ✅
    ├── Findings, none CRITICAL → JUDGMENT: LIGHT VERDICT 📋 (report; no auto-fix)
    └── CRITICAL findings →
        [verdict gate — skipped when mode pre-set `light`: fix without asking]
        ├── decline → JUDGMENT: LIGHT VERDICT 📋
        └── fix → Delegate Fix Agent (CRITICALs only, max ONE round, no re-judge)
            → JUDGMENT: LIGHT FIXED (unverified) 🔧
            (worse than expected? recommend re-running the full dual protocol)
```

## Full dual protocol

```
User asks for "judgment day"
│
├── Target is specific files/feature/component?
│   ├── YES → continue
│   └── NO → ask user to specify scope before proceeding
│
▼
Resolve skills (Pattern 0): read .ai/atl registry if present → match by code + task context → build Project Standards block
▼
Launch Judge A + Judge B with isolated prompts — in parallel when the runtime supports it
▼
Wait for both to complete
▼
Both results valid? (exact CLEAN string, or ≥1 well-formed finding — empty/malformed is NEVER clean)
├── YES → continue
└── NO → relaunch only the invalid judge once (fresh delegate, same blind prompt)
    ├── retry valid → continue
    └── still invalid → JUDGMENT: INVALID ROUND ⚠️ (preserve the valid judge's findings as unsynthesized; stop)
▼
Synthesize verdict (Confirmed = both judges; Emphasis-confirmed = one judge, inside its emphasis zone, CRITICAL/WARNING — treated like Confirmed)
│
├── No issues found?
│   └── JUDGMENT: APPROVED ✅ (stop here)
│
├── Issues found (confirmed, suspect, or contradictions)?
│   └── [verdict gate via native-question-ux — skipped when a mode is pre-set:
│        `verdict-only` → report and stop; `full` → continue as "Fix and re-judge"]
│       ├── Stop here (verdict only) → JUDGMENT: VERDICT 📋 (no code touched)
│       ├── Fix only → Delegate Fix Agent (confirmed + emphasis-confirmed issues) → JUDGMENT: FIXED (unverified) 🔧
│       └── Fix and re-judge (full loop) ▼
│       Delegate Fix Agent with confirmed + emphasis-confirmed issues list (Fix 1)
│       ▼
│       Wait for Fix Agent to complete
│       ▼
│       [loop gate via native-question-ux] — re-judge?
│       ├── Escalate now → JUDGMENT: ESCALATED ⚠️ (history so far)
│       ├── Stop here → JUDGMENT: STOPPED 🛑 (report state)
│       └── Continue ▼
│       Re-launch Judge A + Judge B in parallel (Round 2)
│       ▼
│       Synthesize verdict
│       │
│       ├── Clean → JUDGMENT: APPROVED ✅
│       │
│       └── Still issues →
│           [loop gate via native-question-ux] — apply Fix 2?
│           ├── Escalate now → JUDGMENT: ESCALATED ⚠️
│           ├── Stop here → JUDGMENT: STOPPED 🛑
│           └── Continue ▼
│           Delegate Fix Agent again (Fix 2 / iteration 2)
│           ▼
│           [loop gate via native-question-ux] — re-judge?
│           ├── Escalate now → JUDGMENT: ESCALATED ⚠️
│           ├── Stop here → JUDGMENT: STOPPED 🛑
│           └── Continue ▼
│           Re-launch Judge A + Judge B in parallel (Round 3)
│           ▼
│           Synthesize verdict
│           │
│           ├── Clean → JUDGMENT: APPROVED ✅
│           └── Still issues → JUDGMENT: ESCALATED ⚠️ (report to user)
```
