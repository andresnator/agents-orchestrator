# Review Domain

Adversarial Judgment and Socratic Defend run through orchestraitor loading `oc-review`, with blind judge subagents.

## Quick path

1. Run `/review judgment`, `/review light`, or `/review defend`.
2. Answer authorization or defense questions directly.
3. Review the verdict, ledger, and changed paths.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/review judgment` or `/review light` | Review code adversarially | Findings and bounded authorized fixes |
| `/review defend` | Challenge design decisions | Evidence-backed defense verdict |

Full Judgment runs blind A/B judges, synthesizes evidence, and fixes only authorized confirmed findings. Light Judgment uses one solo judge (`oc-judge lens=solo`); Defend remains read-only.

After changing this domain, run the affected [Review manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/review` | Starts Judgment or Defend review |
| Skill | `oc-conventions` | Applies code and test conventions |
| Skill | `oc-graphify` | Queries code graphs read-only |
| Skill | `oc-judge` | Runs one blind lens review |
| Skill | `oc-judge-fix` | Applies authorized confirmed review fixes |
| Skill | `oc-practices` | Evaluates language-neutral code quality |
| Skill | `oc-review` | Coordinates Judgment and Defend |
