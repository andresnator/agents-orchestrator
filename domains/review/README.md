# Review Domain

`orchestraitor` loads `oc-review` for adversarial Judgment and Socratic Defend with blind judge subagents.

## Quick path

1. Run `/review judgment`, `/review light`, or `/review defend`.
2. Answer authorization or defense questions.
3. Review the verdict, the ledger, and the changed paths.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/review judgment` or `/review light` | Review code adversarially | Findings and bounded authorized fixes |
| `/review defend` | Challenge design decisions | Evidence-backed defense verdict |

Full Judgment combines blind A/B judges and fixes only authorized, confirmed findings. Light uses one solo judge (`oc-judge lens=solo`). Defend is read-only.

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `/review` | Starts Judgment or Defend review |
| `oc-conventions` | Applies code and test conventions |
| `oc-judge` | Runs one blind lens review |
| `oc-judge-fix` | Applies authorized review fixes |
| `oc-practices` | Evaluates language-neutral code quality |
| `oc-review` | Coordinates Judgment and Defend |
