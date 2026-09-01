# Manual regression catalog

Use this catalog to choose short, observable regression checks by changed surface. The only automated check is the catalog linter: it validates this Markdown and reports affected case IDs, but never executes OpenCode, installers, plugins, or the cases themselves.

## Quick path

1. Run `python3 scripts/lint-manual-tests.py` before opening a pull request.
2. In a pull request, open the `manual-test-catalog` summary and follow only the listed IDs.
3. Run each case in a disposable target and compare the observable result. No PASS/FAIL template or stored evidence is required.

For a local branch comparison, run:

```bash
python3 scripts/lint-manual-tests.py --base origin/main --head HEAD
```

## Domain index

| Owner | Manual cases |
|---|---|
| Repository | Cases below for installers, profiles, plugins, tools, and the catalog gate |
| Architecture | [Architecture manual tests](../domains/architecture/manual-tests.md) |
| Common | [Common manual tests](../domains/common/manual-tests.md) |
| Docs | [Docs manual tests](../domains/docs/manual-tests.md) |
| Learning | [Learning manual tests](../domains/learning/manual-tests.md) |
| Meta | [Meta manual tests](../domains/meta/manual-tests.md) |
| Orchestration | [Orchestration manual tests](../domains/orchestration/manual-tests.md) |
| Plan | [Plan manual tests](../domains/plan/manual-tests.md) |
| Review | [Review manual tests](../domains/review/manual-tests.md) |

Reusable human inputs live under `manual-tests/fixtures/`. Copy them to a disposable directory before changing or running them; no runner consumes these fixtures.

## Case format

Keep IDs and coverage keys immutable. If a behavior already has the same coverage key, update that case instead of adding another ID. Titles use sentence case without terminal punctuation, and `Applies to` contains repository-relative paths or globs.

Every case follows this field order: Title, Coverage key, Applies to, Preconditions, Steps, Expected result, optional Essential negative variant, then Cleanup. Keep one happy flow; add a negative variant only when the safety boundary is essential.

## Pull request gate

The read-only workflow runs on every pull request with one job, `manual-test-catalog`. It compares base and head, expands a changed shared skill to every domain symlink that owns it, includes cases added or modified in the pull request, and fails when a changed runtime artifact matches no case.

A documentation-only pull request can report that no runtime manual cases are affected. After an authorized GitHub delivery and the workflow's first check run, a repository administrator can add `manual-test-catalog` from GitHub Actions as a required, non-strict check in the existing `Main` ruleset while preserving every other rule. GitHub documents the [required-check source and loose/strict policy](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) and the [job-name context format](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/troubleshooting-rules).

## Repository cases

### MT-REPOSITORY-INSTALL-LIFECYCLE

- **Title:** Install and remove selected components
- **Coverage key:** `repository/installer/selected-lifecycle`
- **Applies to:** `installers/opencode.sh`, `installers/lib/**`, `global/AGENTS.md`
- **Preconditions:** Create an empty disposable target outside this repository.
- **Steps:**
  1. Run `installers/opencode.sh install --domain docs --target <target>`, then run `status` with the same domain and target.
  2. Run `uninstall --target <target>` and inspect the target plus its manifest before and after removal.
- **Expected result:** Install links only selected components and `AGENTS.md`, status reports them as installed, and uninstall removes only manifest-owned content.
- **Cleanup:** Remove the disposable target after confirming that no unrelated path changed.

### MT-REPOSITORY-INSTALL-IDEMPOTENCY

- **Title:** Repeat installation without drift
- **Coverage key:** `repository/installer/idempotent-sync`
- **Applies to:** `installers/opencode.sh`, `installers/lib/**`
- **Preconditions:** Create a disposable target containing one unrelated file and a valid foreign OpenCode setting.
- **Steps:**
  1. Install the same domain and status selection into the target twice.
  2. Compare the second status, manifest, unrelated file, and foreign setting with the first installation.
- **Expected result:** The second install reports no ownership drift, keeps one manifest entry per managed item, and preserves all foreign content.
- **Cleanup:** Uninstall the managed selection, confirm the foreign content remains, then remove the disposable target.

### MT-REPOSITORY-EXTERNAL-PLUGIN-LIFECYCLE

- **Title:** Preserve external plugin registrations
- **Coverage key:** `repository/plugins/registration-lifecycle`
- **Applies to:** `installers/opencode.sh`, `installers/lib/**`, `scripts/jsonc-array.py`, `domains/*/external-plugins/**`, `manual-tests/fixtures/external-plugins/**`
- **Preconditions:** Copy one JSONC before fixture to a disposable target and keep its matching after fixture available for comparison.
- **Steps:**
  1. Install `common,meta` into the target and inspect server and TUI plugin registrations plus the installer manifest.
  2. Reinstall, run status, then uninstall and compare the JSONC comments, foreign entries, and managed entries.
- **Expected result:** Each pinned npm plugin is registered once in its correct runtime config, comments and foreign values survive, and uninstall removes only manifest-owned registrations.
- **Cleanup:** Delete the disposable target and fixture copy.

### MT-REPOSITORY-BREW-TOOLS

- **Title:** Plan selected Homebrew tools
- **Coverage key:** `repository/installer/brew-selection`
- **Applies to:** `installers/opencode.sh`, `installers/lib/**`, `installers/brew-tools.tsv`
- **Preconditions:** Ensure the repository checkout is readable; no Homebrew installation is required for this dry-run case.
- **Steps:**
  1. Run a global `architecture` install with `--dry-run`, then repeat it with `--no-install-brew-tools`.
  2. Run a disposable explicit-target dry run once without and once with `--install-brew-tools`.
- **Expected result:** Global default and target opt-in plan only the formulas required by selected components; global opt-out and target default plan none, and no manifest claims Homebrew ownership.
- **Cleanup:** Remove the disposable target if the dry run created its parent.

### MT-REPOSITORY-MULTI-PRIMARY-PROFILE

- **Title:** Install and remove the multi-primary profile
- **Coverage key:** `repository/profile/multi-primary-lifecycle`
- **Applies to:** `scripts/multi-primary-profile.sh`, `scripts/jsonc-array.py`
- **Preconditions:** Create a disposable Git project with a valid commented `opencode.jsonc`, a foreign setting, and no link to this worktree.
- **Steps:**
  1. Run profile `install`, `status`, and a second `install` with `--project-root <project>`.
  2. Inspect selected domains, four primaries, six primary commands, `subagent_depth`, then run `uninstall`.
- **Expected result:** The profile selects `plan,orchestration,architecture,review,common`, preserves the default agent and foreign JSONC content, and restores prior managed values on uninstall.
- **Cleanup:** Remove the disposable Git project.

### MT-REPOSITORY-UNSAFE-TARGETS

- **Title:** Reject unsafe installation targets
- **Coverage key:** `repository/safety/target-rejection`
- **Applies to:** `installers/opencode.sh`, `installers/lib/**`, `scripts/multi-primary-profile.sh`
- **Preconditions:** Create a disposable Git project and a symlink at its `.opencode` path; record checksums of surrounding files.
- **Steps:**
  1. Ask the multi-primary profile to install into the source repository or one of its worktrees.
  2. Ask it to install into the disposable project whose `.opencode` target is a symlink.
- **Expected result:** Both requests fail before mutation with a message naming the unsafe source-worktree or symlink boundary.
- **Essential negative variant:** Pass `/` as the project root and confirm it is rejected as broad before any target directory or manifest is written.
- **Cleanup:** Compare the recorded checksums, remove the symlink, and delete the disposable project.

### MT-REPOSITORY-CATALOG-GATE

- **Title:** Reject an invalid manual catalog
- **Coverage key:** `repository/catalog/schema-gate`
- **Applies to:** `scripts/lint-manual-tests.py`, `.github/workflows/manual-test-catalog.yml`, `docs/manual-testing.md`, `domains/*/manual-tests.md`
- **Preconditions:** Use a disposable copy of this repository with Python 3 and Git available.
- **Steps:**
  1. Run `python3 scripts/lint-manual-tests.py`, then compare a committed base and head and inspect the affected-ID summary.
  2. Change one case while keeping its ID and coverage key, commit it, and rerun the base/head comparison.
- **Expected result:** The valid catalog passes, the changed case appears automatically, and the workflow contains one read-only job without path filters or product execution.
- **Essential negative variant:** Duplicate an ID or coverage key and confirm the linter exits nonzero with both source locations; restore the file and confirm it passes.
- **Cleanup:** Discard the disposable repository copy.
