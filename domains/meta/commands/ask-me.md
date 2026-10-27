---
description: "Recommend which oc-* harness skills fit a use case, discovered dynamically from the installed skill catalog."
argument-hint: "[describe your use case]"
---
Raw arguments: `$ARGUMENTS`

Recommend skills from this harness only. Harness skills are the identifiers that start with `oc-`; ignore every other skill. Only recommend: never load a recommended skill, read its body, or start the work.

1. If the use case is missing, ask for it in one direct question and wait.
2. Build the candidates at runtime; never use a remembered or hardcoded list. Read `.ai/atl/skill-registry.md` by literal path and take each `Skill ID` that starts with `oc-` with its `Description`, keeping only IDs the native skill catalog lists as available. If the registry is absent, malformed, or lacks a matching `oc-` skill, use the native catalog's available skills filtered to `oc-`. Never read `SKILL.md` files directly.
3. Find wrapping commands at runtime: read the installed command files (`.opencode/commands/*.md`, then `$OPENCODE_CONFIG_DIR/commands/*.md` or `~/.config/opencode/commands/*.md`) and pair a command with a skill only when its body loads that exact Skill ID. Command descriptions alone never establish a pairing.
4. Match the use case against each candidate's description and trigger words. Prefer the entry skill: rank first a skill that an installed command loads or whose description says it coordinates another candidate; list sub-protocols and building blocks only as complementary. Choose one primary and at most two complementary skills. Ask one closed question only when two entry skills fit equally and the choice changes the outcome.
5. Before saying nothing fits, check the native catalog filtered to `oc-`. If still no `oc-` skill fits, say so plainly, name the closest candidate if one is near, and recommend nothing else.

Reply in the user's language, primary first:

- `oc-<name>`: why it fits, citing its description.
- How to use it: the paired command from step 3, otherwise one example request to `orchestraitor` that uses the skill's trigger words.

Do not include skill bodies, file paths, or skills outside this harness.
