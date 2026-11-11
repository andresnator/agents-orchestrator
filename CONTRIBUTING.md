# Contributing

This repository stores OpenCode agent artifacts, not application code. Start with [README.md](README.md).

agents-orchestrator is a set of OpenCode commands, skills, and plugins. One agent, `orchestraitor`, does all routes: it loads `oc-*` skills or gives work to the `general` subagent. The installer (`installers/opencode.sh`) links the files into the OpenCode configuration folder.

## Repository contract

- Read [standards/README.md](standards/README.md) and all files that it lists before you make a change. They own the language, ASD-STE100, and trigger rules.
- Add each new abbreviation or term to [standards/glossary.md](standards/glossary.md) before you use it.
- The layout is flat by type: `agents/`, `commands/`, `skills/`, `tui-plugins/`, and `external-plugins/`.
- The installer links `standards/` beside `AGENTS.md`.
- `global/AGENTS.md` is the installable runtime rules file. `CONTRIBUTING.md` is maintainer guidance. Do not merge their roles.
- A new component must not require edits to `installers/opencode.sh`.
- Do not track `.ai/`, other runtime state, root `/AGENTS.md`, or root `/CLAUDE.md`.

## Agents and commands

`orchestraitor` (`agents/orchestraitor.md`, `mode: primary`) is the only agent. Do not add agents. Add an `oc-*` skill.

Store commands at `commands/<name>.md`. The command `agent:` is `orchestraitor`, a built-in agent such as `build`, or omitted. Names are globally unique in their type.

Agent frontmatter order:

```text
description, mode, permission, tools?, disable?
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

Do not copy the question rule of `global/AGENTS.md` into an agent, skill, or command. Keep only a nuance that is specific to the skill.

## Skills

Each skill has exactly one body. Put every skill at `skills/<skill>/SKILL.md`. Do not copy skill bodies or add symlinks.

Name each skill `oc-<short-name>`: kebab-case, three short words maximum after the prefix, identical to the directory name.

Skill frontmatter contains `name`, `description`, `license`, `metadata.author`, strict SemVer `metadata.version`, and `metadata.status`. Status is `backlog`, `in-progress`, `testing`, or `done`.

Bump the version for each skill change:

- Patch: wording or internal fixes.
- Minor: added capability.
- Major: breaking activation or output behavior.

Keep the runtime contract short. Put concrete templates in `assets/`. Put extended guidance in `references/`.

## Keeping the catalog accurate

To add a component, add its folder or file in the correct type directory. Then update the `## Catalog` in [README.md](README.md): add a command to "Entry points" and a skill to "Skills by purpose". Do the same when you remove or rename a component. For GitHub-bundled external plugins, update the version, commit, artifact, and SHA-256 lock together. For npm plugins, keep the package, exact version pin, and runtime target aligned.

## Validation

Run `make hooks` one time. Before you complete a change, run `make test`. The pre-push hook runs it too.

Syntax-check a changed executable, for example `bash -n <script>`. Test behavior in a disposable target. Model-backed checks spend credits. Run them only with a separate explicit authorization.

Do not commit unless a person explicitly asks.

## Make targets

- Keep all targets in the root `Makefile`. Do not use `include`: shell completion reads only the root `Makefile`.
- The `Makefile` holds commands only. A recipe has one command line.
- If an action needs more logic, put it in `make-scripts/<action>.sh`. One script has one responsibility, for example `make-scripts/default-agent.sh`. The target calls the script and gives values as environment variables or arguments.
- Each script follows "Shell scripts" in [standards/code-conventions.md](standards/code-conventions.md) and starts with a comment that tells its purpose and usage.
- Write a `## <description>` comment after each public target. `make help` reads these comments. Add each target to `.PHONY`.
