# Review Domain

Adversarial Judgment and Socratic Defend run through one direct review primary with isolated judge workers.

## Quick path

1. Select `review-coordinator` or run `/judgment` or `/defend`.
2. Answer authorization or defense questions directly.
3. Review the verdict, ledger, and changed paths.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/judgment` | Review code adversarially | Findings and bounded authorized fixes |
| `/defend` | Challenge design decisions | Evidence-backed defense verdict |

Full Judgment runs blind A/B judges, synthesizes evidence, and fixes only authorized confirmed findings. Light Judgment uses one solo judge; Defend remains read-only.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `review-coordinator` | Coordinates Judgment and Defend directly |
| Agent (subagent) | `jd-fix` | Applies authorized confirmed review fixes |
| Agent (subagent) | `jd-judge-a` | Reviews correctness and edge cases |
| Agent (subagent) | `jd-judge-b` | Reviews security and performance risks |
| Agent (subagent) | `jd-solo` | Runs one balanced light review |
| Command | `/defend` | Starts Socratic design defense |
| Command | `/judgment` | Starts adversarial code review |
| Skill | `code-conventions` | Applies code and test conventions |
| Skill | `graphify-cli` | Queries code graphs read-only |
| Skill | `judgment-day` | Runs dual blind adversarial reviews |
| Skill | `programming-practices-core` | Evaluates language-neutral code quality |
