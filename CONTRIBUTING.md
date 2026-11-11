# Contributing

This repository stores OpenCode agent artifacts, not application code. Start with [README.md](README.md) and the README of the domain that you change.

## Repository contract

- Read [standards/README.md](standards/README.md) and all files that it lists before you make a change. They own the language, ASD-STE100, and trigger rules.
- `domains/` owns agents, commands, repository plugins, external-plugin locks, and skills used by one domain.
- `skills/` holds only skill bodies that more than one domain uses.
- The installer links `standards/` beside `AGENTS.md`.
- `global/AGENTS.md` is the installable runtime rules file. `CONTRIBUTING.md` is maintainer guidance. Do not merge their roles.
- A new component must not require edits to `installers/opencode.sh`.
- Do not track `.ai/`, other runtime state, root `/AGENTS.md`, or root `/CLAUDE.md`.

## Agents and commands

`orchestraitor` (`domains/orchestration/agents/orchestraitor.md`, `mode: primary`) is the only agent. Do not add agents. Add an `oc-*` skill.

Store commands at `domains/<domain>/commands/<name>.md`. The command `agent:` is `orchestraitor`, a built-in agent such as `build`, or omitted. Names are globally unique in their type.

Agent frontmatter order:

```text
description, mode, temperature?, permission, tools?, disable?
```

Command frontmatter order:

```text
description, agent?, model?, subtask?, argument-hint?
```

Do not add `name`, `prompt`, `license`, or `metadata` to agent or command frontmatter. Do not hardcode models or provider options. Write short prompts in the IDSD format below. Put fork attribution outside executable frontmatter.

## IDSD format

Agents, skills, and plans use Intent-Driven Software Development (IDSD). Each body states one complete ICE (Intent, Context, Expectations) for one capability. Then it gives only the method knowledge that a model cannot infer.

```markdown
# <Title>

## Intent

- **Goal:** <one observable outcome>
- **Limits:** <boundaries, forbidden actions, ownership>
- **Fails if:** <observable conditions that make the result wrong>

## Context

- **Reads:** <inputs, files, skills, and evidence it uses>
- **Never reads:** <sources it must ignore>
- **Persona:** <role and stance>
- **Scope:** <activation and where it applies>

## Expectations

- **Scenarios:** <WHEN ... THEN ... behaviors>
- **Done means:** <completion criteria and exact return contract>
- **Quality needs:** <quality bar>

## Method

<Optional: decision tables, protocols, formats, and resource pointers. Describe what to achieve, not a rigid script.>
```

Keep the bold field labels exact. Use nested bullets or a short table for a long field. Keep literal triggers, return lines such as `OK ...` and `BLOCK ...`, and paths exactly.

For free-text questions, ask one direct question in normal chat, add `Recommendation: ...` only when it helps, and wait. Use the `question` tool only for closed choices.

## Skills

Each skill has exactly one body. Put a single-domain skill at `domains/<domain>/skills/<skill>/SKILL.md`. Put a shared skill at `skills/<skill>/SKILL.md`, and link it from each owning domain with a relative `domains/<domain>/skills/<skill>` symlink. Do not copy skill bodies.

Name each skill `oc-<short-name>`: kebab-case, three short words maximum after the prefix, identical to the directory name.

Skill frontmatter contains `name`, `description`, `license`, `metadata.author`, strict SemVer `metadata.version`, and `metadata.status`. Status is `backlog`, `in-progress`, `testing`, or `done`.

Bump the version for each skill change:

- Patch: wording or internal fixes.
- Minor: added capability.
- Major: breaking activation or output behavior.

Keep the runtime contract short. Put concrete templates in `assets/`. Put extended guidance in `references/`.

## Keeping the catalog accurate

Each domain README uses this H2 sequence: `## Quick path`, `## Entry points`, then `## Components`. Limits: two intro sentences, two or three quick-path steps, and 3-8 words for each component purpose. `## Components` is the final authoritative section.

When you add, remove, or move a component, update the `## Components` table of the owning domain. Update the root domain table only when the entry points or the domain purpose change. For GitHub-bundled external plugins, update the version, commit, artifact, and SHA-256 lock together. For npm plugins, keep the package, exact version pin, and runtime target aligned.

## Validation

Syntax-check a changed executable, for example `bash -n <script>`. Test behavior in a disposable target. Model-backed checks spend credits. Run them only with a separate explicit authorization.

Do not commit unless a person explicitly asks.
