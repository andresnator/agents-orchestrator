# Meta manual tests

Run these cases after changing Meta commands, skills, or pinned utilities. Use disposable repositories and OpenCode configuration because plugin cases may refresh local state.

## Quick path

1. Install the current checkout's `meta,common` domains into a disposable project.
2. Run the affected IDs from the catalog summary.
3. Inspect only the named report, skill, registry, or configuration target.

### MT-META-ABSORB

- **Title:** Compare an external agent harness
- **Coverage key:** `meta/absorb/adoption-report`
- **Applies to:** `domains/meta/commands/absorb.md`, `domains/meta/skills/absorb/**`
- **Preconditions:** Prepare a small local external repository with one visible agent or prompt convention and use a disposable target repository.
- **Steps:**
  1. Run `/absorb <external-path>` and authorize only read access to the named project.
  2. Inspect the evidence-backed comparison and selective adoption recommendations.
- **Expected result:** The result analyzes AI-harness practices rather than application code, contrasts them with this repository, labels unsupported claims, and makes no implementation or external-repository change.
- **Cleanup:** Remove any local report created for the disposable comparison and delete the disposable repositories.

### MT-META-PROMPT-STRUCTURE

- **Title:** Convert a rough idea into an executable prompt
- **Coverage key:** `meta/prompt/structured-output`
- **Applies to:** `domains/meta/skills/prompt-structure-writer/**`
- **Preconditions:** Use a session where `prompt-structure-writer` is available and prepare a loose request with an outcome, constraints, and one ambiguity.
- **Steps:**
  1. Ask to improve the rough prompt for a local coding agent.
  2. Inspect the returned prompt for objective, context, boundaries, deliverable, and verification.
- **Expected result:** The skill preserves intent and technical literals, resolves or exposes the material ambiguity, and returns a brief directly executable prompt without performing the requested implementation.
- **Cleanup:** Close the disposable session.

### MT-META-SKILL-CREATION

- **Title:** Create a skill with manual regression coverage
- **Coverage key:** `meta/skills/creation-contract`
- **Applies to:** `domains/meta/skills/skill-creator/**`
- **Preconditions:** Use a disposable copy of this repository and request one clearly reusable, single-domain skill.
- **Steps:**
  1. Invoke `skill-creator`, approve the new skill, and inspect its location and frontmatter.
  2. Ask for a behavior change to that skill and inspect the version plus the owning domain's manual case.
- **Expected result:** The skill has one body in the correct owner, complete strict-SemVer metadata, concise resources, a patch-or-larger version bump, and an updated existing coverage key or one new immutable manual ID.
- **Cleanup:** Discard the disposable repository copy.

### MT-META-SKILL-REGISTRY

- **Title:** Refresh the resolved skill registry
- **Coverage key:** `meta/registry/startup-snapshot`
- **Applies to:** `domains/meta/external-plugins/opencode-skill-registry.npm-server.json`, `global/AGENTS.md`, `domains/meta/skills/skill-creator/**`
- **Preconditions:** Install the Meta domain into a disposable project with at least one project skill and no stale OpenCode process.
- **Steps:**
  1. Start OpenCode, inspect `.ai/atl/skill-registry.md`, then add or remove one disposable project skill.
  2. Restart OpenCode and inspect the refreshed snapshot and native `/skill` catalog.
- **Expected result:** The pinned server plugin alone owns the snapshot, canonical runtime sections and `Description | Skill | Location` columns reflect resolved skills, and no repository generator is required.
- **Cleanup:** Remove the disposable skill, generated `.ai/atl/` state, and project.

### MT-META-MODEL-PROFILES

- **Title:** Apply and restore model profile assignments
- **Coverage key:** `meta/models/profile-lifecycle`
- **Applies to:** `domains/meta/external-plugins/opencode-models-presets.npm-tui.json`
- **Preconditions:** Install the Meta domain in a disposable project whose OpenCode config contains a default agent and one foreign model assignment.
- **Steps:**
  1. Run `/models-profiles`, choose a preset, and apply it only to the disposable project.
  2. Inspect effective agent assignments, then restore or remove the selected preset.
- **Expected result:** The pinned TUI plugin updates only selected agent model/variant fields, preserves the default and foreign configuration, and restores its managed values without editing repository artifacts.
- **Cleanup:** Remove the disposable OpenCode configuration and project.
