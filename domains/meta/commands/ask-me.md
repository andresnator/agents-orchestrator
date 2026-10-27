---
description: "Recommend which oc-* harness skills fit a use case, discovered dynamically from the installed skill catalog."
argument-hint: "[describe your use case]"
---
Raw arguments: `$ARGUMENTS`

Recommend skills from this harness only. Harness skills are the identifiers that start with `oc-`; ignore every other skill. Only recommend: never load a recommended skill, read its body, or start the work.

1. If the use case is missing, ask for it in one direct question and wait.
2. Build the candidates at runtime; never use a remembered or hardcoded list. Read `.ai/atl/skill-registry.md` by literal path and take each `Skill ID` that starts with `oc-` with its `Description`. If the registry is absent, malformed, or lacks an `oc-` skill, use the native skill catalog's available skills filtered to `oc-`. Never read `SKILL.md` files directly.
3. Match the use case against each candidate's description and trigger words. Choose the best `oc-*` skill, plus at most two complementary ones only when the use case needs them. When two candidates fit equally and the choice changes the outcome, ask one closed question.
4. If no `oc-` skill fits, say so plainly, name the closest candidate if one is near, and recommend nothing else.

Reply in the user's language:

- `oc-<name>`: why it fits, citing its description.
- How to use it: a harness command that wraps it when one is installed (for example `/judgment` for `oc-review`), otherwise one example request to `orchestraitor` that uses the skill's trigger words.

List the primary recommendation first. Do not include skill bodies, file paths, or skills outside this harness.
