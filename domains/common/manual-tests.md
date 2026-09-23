# Common manual tests

Run these cases after changing Common commands, plugins, or the directly named shared skills. Use disposable sessions and repositories because some cases create `.ai/` state.

## Quick path

1. Install the current checkout's `common` domain into a disposable project.
2. Run the affected IDs from the pull-request summary.
3. Inspect shared mode behavior or generated local state, then clean it up.

### MT-COMMON-CAVEMAN

- **Title:** Share a persistent global mode across primaries and real subagents
- **Coverage key:** `common/caveman/global-persistence`
- **Applies to:** `global/AGENTS.md`, `domains/common/commands/caveman.md`, `domains/common/plugins/caveman-mode.ts`, `domains/common/skills/caveman/**`, `domains/common/README.md`
- **Preconditions:** Use two independent OpenCode processes in Herdr-managed panes, with primary sessions A and B sharing one disposable global configuration directory via `OPENCODE_CONFIG_DIR`. Install the current plugin, command, skill, and global instructions there; verify the plugin and global-instructions symlinks target this checkout. Start with no `caveman-mode.json` in that disposable directory. Quit and restart both processes after installation to load the current code. Use the runtime's actual delegation and continuation controls; a primary imitating a subagent is not a substitute.
- **Steps:**
   1. Ask A and B for the same short technical explanation. Have A delegate a real subagent S and retain its continuation identifier. Confirm all three use the `lite` fallback without an explicit selection.
   2. Run `/caveman full` in A. Request the explanation from A, existing B, continuing S, and a newly delegated subagent. Open a new primary C with the same configuration and ask it too. Each next response must use `full` without a local command.
   3. Run `/caveman wenyan` in B. Repeat the existing-primary and continuing/new-subagent checks. They must use `wenyan`, not their earlier `full` selection. Check that technical literals remain intact.
   4. Send the standalone message `normal mode` in A. Check A, B, C, continuing S, and a new subagent: every next response must use normal prose (`off`).
   5. Quit and restart B's OpenCode process with the same configuration. Request an explanation from a primary and a real subagent without selecting a mode. Both must still use `off`.
   6. Run `/caveman ultra` in B. Confirm existing A and continuing S use `ultra` next. Restart B again; its primary and a subagent must retain `ultra`. Send `stop caveman` in B and confirm A and S return to `off` next.
   7. Run bare `/caveman` in A. Confirm B and continuing/new subagents switch from `off` to `lite` on their next responses.
- **Expected result:** All sessions and processes in the shared configuration follow the latest saved level, including durable `off`; no session or ancestor retains a private override. Restart preserves the selection. Prior responses remain unchanged. Inspect the saved `caveman-mode.json` alongside actual response behavior; where runtime diagnostics expose the system prompt, confirm one current `CAVEMAN SESSION MODE:` marker. A model's claim about its mode alone is not proof.
- **Essential negative variant:** Run `/caveman invalid` and `/caveman off`. Each must show `Usage: /caveman [lite|full|ultra|wenyan]`, leave the saved state unchanged, and leave B and continuing S using `lite` on their next responses.
- **Evidence:** Record pane/process and session identifiers, the real subagent's continuation identifier, selected levels, observed responses, and restart results. If Herdr, real delegation, continuation, or runtime evidence is unavailable, mark that case **unverified** with the blocker; do not infer a pass from automated plugin tests.
- **Cleanup:** Close the test processes and remove only the disposable configuration directory and project. Closing sessions alone does not clear the saved level. Never delete or reset the user's normal global state.

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
