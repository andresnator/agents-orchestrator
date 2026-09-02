# Common manual tests

Run these cases after changing Common commands, plugins, or the directly named shared skills. Use disposable sessions and repositories because some cases create `.ai/` state.

## Quick path

1. Install the current checkout's `common` domain into a disposable project.
2. Run the affected IDs from the pull-request summary.
3. Inspect session inheritance or generated local state, then clean it up.

### MT-COMMON-CAVEMAN

- **Title:** Inherit and override response compression
- **Coverage key:** `common/caveman/session-inheritance`
- **Applies to:** `domains/common/commands/caveman.md`, `domains/common/plugins/caveman-mode.ts`, `domains/common/skills/caveman/**`
- **Preconditions:** Start an OpenCode parent session in a disposable project and ensure the `caveman-mode` plugin is loaded.
- **Steps:**
  1. Run `/caveman full`, open a child session, and ask both sessions for the same short explanation.
  2. Set the child to `/caveman ultra`, ask again, then say `normal mode` in the parent.
- **Expected result:** The child first inherits `full`, its explicit `ultra` override does not alter the parent, and the parent's subtree returns to normal prose without duplicate mode markers.
- **Essential negative variant:** Run `/caveman invalid` and confirm the current mode stays unchanged while the response lists only the valid syntax.
- **Cleanup:** Close the session tree and remove the disposable project.

### MT-COMMON-GRAPHIFY-INDEX

- **Title:** Index one repository after explicit consent
- **Coverage key:** `common/graphify/first-index-consent`
- **Applies to:** `domains/common/commands/graphify-index.md`, `domains/common/external-plugins/opencode-graphify-init.npm-server.json`, `domains/common/skills/graphify-cli/**`
- **Preconditions:** Use a small disposable Git repository, an installed pinned Graphify binary, and no `.ai/graphify-out/graph.json`.
- **Steps:**
  1. Run `/graphify-index <repository>`, choose code-only in chat, and wait for the announced extraction to finish.
  2. Inspect `.ai/graphify-out/graph.json`, `.opencode-index-mode`, the lock cleanup, and the repository's Git exclude file.
- **Expected result:** Indexing starts only after consent, every Graphify call uses `.ai/graphify-out`, the mode records `code-only`, a healthy graph and node count are reported, and later startup refresh owns no first index.
- **Essential negative variant:** Target the filesystem or home root and confirm the command refuses before writing mode, lock, graph, or exclude state.
- **Cleanup:** Remove Graphify global registration if one was created, then delete `.ai/graphify-out/` and the disposable repository.

### MT-COMMON-GRILL

- **Title:** Stress-test an idea without implementation
- **Coverage key:** `common/grill/focused-interview`
- **Applies to:** `domains/common/commands/grill.md`, `domains/common/skills/grill/**`, `domains/common/skills/grilling/**`, `domains/common/skills/execution-plan/**`
- **Preconditions:** Use a disposable repository and one proposal with an unresolved trade-off.
- **Steps:**
  1. Run `/grill me <proposal>` and answer the focused questions one at a time.
  2. Run `/grill sdd <proposal>`, approve plan creation, and inspect the resulting neutral plan.
- **Expected result:** Plain mode revises the outcome without writing files; `sdd` mode writes at most one approved `.ai/deep-planner/plans/<slug>.md` and never edits code, build files, tests, or Git.
- **Cleanup:** Remove the generated plan and disposable repository.
