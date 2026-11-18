# Contributing

This repository stores OpenCode agent artifacts, not application code. Start with [README.md](README.md).

agents-orchestrator is a set of OpenCode agents, commands, skills, and plugins. The primary agent, `orchestraitor`, does all routes: it loads `oc-*` skills or gives work to the `worker` and `scout` subagents. The installer (`installers/opencode.sh`) links the files into the OpenCode configuration folder.

## Repository contract

- Read [standards/README.md](standards/README.md) and all files that it lists before you make a change. They own the language, ASD-STE100, and trigger rules.
- Add a term to [standards/glossary.md](standards/glossary.md) only if it is specific to this repository or has a specific meaning here. A common industry abbreviation needs no entry. Do not invent abbreviations.
- The layout is flat by type: `agents/`, `commands/`, `skills/`, `tui-plugins/`, and `external-plugins/`.
- `standards/` applies to this repository only. The installer does not install it. The root `AGENTS.md` tells agents in this repository to read it.
- `global/AGENTS.md` is the installable runtime rules file. `CONTRIBUTING.md` is maintainer guidance. Do not merge their roles.
- A new component must not require edits to `installers/opencode.sh`.
- Do not track `.ai/`, other runtime state, or root `/CLAUDE.md`. The root `/AGENTS.md` is tracked: keep it short, with pointers only.

## Agents and commands

Three agents are allowed and no more:

| Agent | Mode | Role |
| --- | --- | --- |
| `orchestraitor` | `primary` | Routes, plans, coordinates, and owns Git in the main working tree. |
| `worker` | `all` | Implements one self-contained brief. The factory also starts it directly. |
| `scout` | `subagent` | Read-only: explores, verifies, judges. `edit` is denied. |

Do not add agents. Add an `oc-*` skill. Delegation is one level deep. The three agents let the user give a different model to each role.

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

Agent bodies and skills use Intent-Driven Software Development (IDSD). Plans do not: they use the `oc-plan` template. Each body states one complete ICE (Intent, Context, Expectations) for one capability. Then it gives only the method knowledge that a model cannot infer.

```markdown
# <Title>

## Intent

- **Goal:** <one observable outcome>
- **Limits:** <boundaries, forbidden actions, ownership>
- **Fails if:** <observable conditions that make the result wrong>

## Context

- **Reads:** <inputs, files, skills, and evidence it uses>
- **Never reads:** <optional: sources it must ignore>
- **Persona:** <optional: a stance that changes behavior>
- **Scope:** <activation and where it applies>

## Expectations

- **Scenarios:** <optional: WHEN ... THEN ... for real branches and edge cases>
- **Done means:** <completion criteria and exact return contract>
- **Quality needs:** <optional: quality bar>

## Method

<Method knowledge that a model cannot infer. See "Method rule".>
```

Keep the bold field labels exact. Use nested bullets or a short table for a long field. Keep literal triggers, return lines such as `RESULT: ok | failed`, and paths exactly.

Do not copy the question rule of `global/AGENTS.md` into an agent, skill, or command. Keep only a nuance that is specific to the skill.

### Required and optional fields

| Field | Status | Rule |
| --- | --- | --- |
| `Goal`, `Limits`, `Fails if`, `Reads`, `Scope`, `Done means` | Required | Always write them. |
| `Method` | Required | Required in agent and skill bodies. A reference can omit it if it adds no method. |
| `Never reads` | Optional | Use it only for a real source that the body must ignore. |
| `Persona` | Optional | Use it only for a stance that changes behavior. Do not restate the title or the `Goal`. |
| `Scenarios` | Optional | Use it only for real branches and edge cases. Do not repeat `Method`. |
| `Quality needs` | Optional | Use it only for a quality bar that no other field states. |

- Omit an optional field if its value is `none`, is empty, or restates the title or the `Goal`.
- Put each rule in one field only. For example, a language rule goes in `Limits` or `Quality needs`, not in `Persona`.
- `Fails if` has three items maximum.
- The `oc-plan` skill owns the plan template. A plan requires only `Goal`, `Done means`, and `Tasks`.

### Method rule

Write for a small model:

- Give concrete numbered steps for the main path. Use short positive sentences.
- Write few rules. Do not write a long list of prohibitions.
- Do not write a stop condition for a recoverable gap. See "Flow rules".
- Give one small example where a format is important.

Use an exact format only when one of these conditions is true:

- The order of the steps is important, or a step cannot be undone.
- Another program parses the output.
- Each run must give the same result.
- The model cannot infer a detail of the environment.

Put determinism in a script, not in prose. Keep owner conventions, exact formats, and project contracts.

### Flow rules

Each agent, skill, and command obeys these rules:

- **Assume, note, continue.** Ask the user only before an action that is irreversible or visible to other people: push, PR, merge into the user's branch, delete user data or untracked work, run a migration on real data, rewrite history. For all other gaps, select the most reasonable option, continue, and report the assumption at the end.
- **No stop for a recoverable gap.** A worker with missing input makes the smallest safe assumption and reports it. Stop only when the target cannot be found or the rule above applies.
- **Save tokens.** A subagent brief is self-contained: the subagent does not load the coordinator skill. Keep the brief in the skill: a file in `assets/` or one code block. Delete legacy notes such as "formerly ...".

## Skills

Each skill has exactly one body. Put every skill at `skills/<skill>/SKILL.md`. Do not copy skill bodies or add symlinks.

Name each skill `oc-<short-name>`: kebab-case, three short words maximum after the prefix, identical to the directory name.

Skill frontmatter contains `name`, `description`, `license`, `metadata.author`, strict SemVer `metadata.version`, and `metadata.status`. Status is `backlog`, `in-progress`, `testing`, or `done`. The `description` has 160 characters maximum, triggers included. A new skill starts at version `1.0.0` with status `testing`.

Bump the version for each skill change:

- Patch: wording or internal fixes.
- Minor: added capability.
- Major: breaking activation or output behavior.

Keep the runtime contract short. Put concrete templates in `assets/`. Put extended guidance in `references/`.

Line cap for `SKILL.md`:

- A skill has 80 lines maximum.
- A coordinator skill has 120 lines maximum. A coordinator skill controls workers or modes through its references. The coordinator skills are `oc-plan` and `oc-build`.

Put each rule in one place. A reference adds only its own procedure. A mode reference of a coordinator skill can use its own headings and inherits the IDSD fields of its parent `SKILL.md`. It does not copy the `Limits` or `Fails if` of its parent `SKILL.md`. Define a shared term one time, where the skill first uses it.

## Keeping the catalog accurate

To add a component, add its folder or file in the correct type directory. Then update the `## Catalog` in [README.md](README.md): add a command to "Entry points" and a skill to "Skills by purpose". Do the same when you remove or rename a component. For npm plugins, keep the package, exact version pin, and runtime target aligned.

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
