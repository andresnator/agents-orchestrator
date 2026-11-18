# Glossary

This glossary defines only the terms that are specific to this repository or that have a specific meaning here. A common industry abbreviation (`API`, `JSON`, `CLI`) needs no entry.

## Abbreviations

| Abbreviation | Full form | Meaning here |
| --- | --- | --- |
| ASD-STE100, STE | ASD Simplified Technical English | The writing standard for all repository text. See [writing-conventions.md](writing-conventions.md). |
| ICE | Intent, Context, Expectations | The three sections that each IDSD body states. |
| IDSD | Intent-Driven Software Development | The body format for agents and skills. `CONTRIBUTING.md` owns it. |
| RFC | Request for Comments | A design proposal that the `oc-rfc` skill writes. It is not an internet standard. |
| USM | User Story Map | A map of user stories by user activity. The `oc-usm` skill writes it. |

## Terms

| Term | Meaning here |
| --- | --- |
| brief | The self-contained text that gives one task to a subagent. The subagent sees no other context. |
| coordinator skill | A skill that controls workers or modes through its references: `oc-plan` and `oc-build`. |
| `Deviations` | The plan section where `oc-build` records each change to the plan and each failed task. |
| `Done means` | The completion criteria. It is a field of an IDSD body and a section of a plan. |
| factory | The `oc-factory` flow. It runs independent tasks at the same time, each in its own Git worktree. |
| group | One numbered part of a plan: one goal with its `Files:` and `Depends on:` lines. |
| `orchestraitor` | The primary agent. It routes, plans, coordinates, and owns Git. The spelling with "ai" is correct. |
| `scout` | The read-only subagent. It explores, verifies, and judges for one brief. |
| `worker` | The subagent that implements one brief and runs its check. |

## Technical terms (do not translate)

The "Spanglish" rule in [writing-conventions.md](writing-conventions.md) keeps technical terms in their original form in all languages. These terms are examples of the rule, not a complete list:

`agent`, `branch`, `build`, `cluster`, `commit`, `container`, `deploy`, `endpoint`, `framework`, `hook`, `issue`, `Kubernetes`, `merge`, `mock`, `pipeline`, `plugin`, `prompt`, `pull request`, `release`, `repository`, `skill`, `subagent`, `token`, `workflow`.

## Add a term

1. Make sure that the term is specific to this repository or has a specific meaning here.
2. Add the term to the correct table in alphabetical order.
3. Give a one-sentence meaning in STE. For an abbreviation, give the full form too.
