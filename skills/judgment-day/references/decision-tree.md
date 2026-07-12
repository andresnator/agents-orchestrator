# Full Decision Tree

Complete flow of the judgment-day protocol including every confirmation gate. The compact protocol in `SKILL.md` is authoritative; this diagram expands it step by step.

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
Synthesize verdict
│
├── No issues found?
│   └── JUDGMENT: APPROVED ✅ (stop here)
│
├── Issues found (confirmed, suspect, or contradictions)?
│   └── Delegate Fix Agent with confirmed issues list (Fix 1 — automatic)
│       ▼
│       Wait for Fix Agent to complete
│       ▼
│       [confirm with user via native-question-ux] — re-judge?
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
│           [confirm with user via native-question-ux] — apply Fix 2?
│           ├── Escalate now → JUDGMENT: ESCALATED ⚠️
│           ├── Stop here → JUDGMENT: STOPPED 🛑
│           └── Continue ▼
│           Delegate Fix Agent again (Fix 2 / iteration 2)
│           ▼
│           [confirm with user via native-question-ux] — re-judge?
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
