# Contributing

This repository stores reusable OpenCode agent artifacts, not application code. Keep changes compact, contract-focused, and organized by domain. Start with [README.md](README.md), then read the README for the domain you change.

## Repository contract

- Write documentation, descriptions, prompts, and comments in English.
- Preserve literal runtime triggers such as `"ejecuta el plan <change>"` and Spanish skill triggers. They are activation contracts, not prose to translate.
- `domains/` owns agents, commands, repository plugins, external-plugin locks, and skills used by one domain.
- `skills/` owns only skill bodies shared by multiple domains.
- `global/AGENTS.md` is the installable runtime rules file. `CONTRIBUTING.md` is maintainer guidance; do not merge their roles.
- `installers/opencode.sh` discovers and installs components. Adding a component must not require installer edits.
- `.ai/` and other runtime-state directories are ignored state, not repository artifacts.
- Root `/AGENTS.md` and `/CLAUDE.md` are ignored local runtime entrypoints; do not track them.

## Agents and commands

`orchestraitor` (`domains/orchestration/agents/orchestraitor.md`, `mode: primary`) is the only agent. Every other capability is an `oc-*` skill that orchestraitor loads itself or names in a brief to OpenCode's built-in `general` subagent; do not add agents. Store commands at `domains/<domain>/commands/<name>.md`; command `agent:` is `orchestraitor`, a built-in OpenCode agent such as `build`, or omitted. Names must be globally unique within their type.

Agent frontmatter order:

```text
description, mode, temperature?, permission, tools?, disable?
```

Command frontmatter order:

```text
description, agent?, model?, subtask?, argument-hint?
```

Do not add `name`, `prompt`, `license`, or `metadata` to agent or command frontmatter. Agent `mode` is `primary`. Do not hardcode agent models or provider options; users configure those in OpenCode.

Keep prompts short and write them in the IDSD format below. Put fork attribution outside executable frontmatter.

## IDSD format

Agents, skills, and plans follow Intent-Driven Software Development (IDSD). Each body states one ICE (Intent, Context, Expectations) for one capability, then only the method knowledge a model cannot infer. An ICE with a missing part is not ready.

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

Keep the bold field labels exact. Use nested bullets or a short table under a field when it needs more than one line. Preserve literal triggers, return lines such as `OK ...` and `BLOCK ...`, and paths exactly.

Open-ended interviews, debriefs, teach-backs, and other free-text questions use normal chat: ask one direct question, add `Recommendation: ...` only when useful, then wait. Do not require question headings, numbering, rationale blocks, or interview-length estimates. Reserve the `question` tool for closed choices such as confirmations, modes, ratings, and enumerated options.

## Skills

Each skill has exactly one body. A skill used by one domain lives directly at `domains/<domain>/skills/<skill>/SKILL.md`. A skill used by multiple domains lives at `skills/<skill>/SKILL.md`, and every owning domain declares it with a relative `domains/<domain>/skills/<skill>` symlink. Do not copy skill bodies or keep an exclusive skill at the top level.

Name every skill `oc-<short-name>`: kebab-case, at most three short words after the prefix, and identical to its directory name.

Skill frontmatter contains `name`, `description`, `license`, and `metadata.author`, strict SemVer `metadata.version`, and `metadata.status`. Status is `backlog`, `in-progress`, `testing`, or `done`.

Bump the version whenever a skill changes: patch for wording or internal fixes, minor for additive capability, major for breaking activation or output behavior. Keep the runtime contract concise; place concrete templates in `assets/` and extended guidance in `references/`.

## Keeping the catalog accurate

Every domain README uses this H2 sequence: `## Quick path`, `## Entry points`, then `## Components`. Keep the introduction to at most two sentences, the quick path to two or three steps, entry points compact, and component purposes to 3-8 words. `## Components` is the final authoritative section. Use only small diagrams that clarify a material relationship.

When adding, removing, or moving a component, update the owning domain README's single `## Components` table. Update the root domain table only when entry points or domain purpose change. For GitHub-bundled external plugins, update the version, commit, artifact, and SHA-256 lock together. For npm plugins, keep the package, exact version pin, and runtime target aligned.

Every runtime behavior change also updates the matching case in the [manual regression catalog](docs/manual-testing.md). Keep its ID and canonical coverage key immutable. If no case covers the changed surface, add one short case under the owning domain instead of adding an automated runner.

## Validation

Lint the catalog, then run the affected manual IDs in a disposable target:

```bash
python3 scripts/lint-manual-tests.py
```

The pull-request job reports the union of IDs matched by changed paths and cases edited in the branch. It is a catalog-only gate: it never runs installers, plugins, agents, or OpenCode. Syntax-check a changed executable when appropriate, but use the documented manual case for behavior. Model-backed cases spend credits and require separate explicit authorization.

Do not commit unless explicitly asked.
