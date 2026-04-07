---
name: tcr
description: |
  Implements the TCR (Test && Commit || Revert) methodology for ultra-short, safe commits
  during refactoring and development. Use this skill whenever the user wants to apply TCR,
  make atomic commits after each green test, commit frequently during refactoring, or
  follow a test-driven commit workflow. Also trigger when the user mentions "TCR",
  "test and commit", "commit after each test", "atomic commits", "micro commits",
  "revert on red", or asks for a disciplined commit cadence during code changes.
  Uses the team's standard commit format (BRANCH-ID type: description) with Co-Authored-By trailer,
  matching the git-commit skill conventions. Integrates naturally with refactoring workflows.
  También se activa en castellano: "test y commit", "commitear tras cada test",
  "commits atómicos", "micro commits", "revertir en rojo",
  "commit después de cada test", "cadencia de commits", "commit frecuente",
  "commitear si pasa el test", "revertir si falla", "commits pequeños",
  "flujo TCR", "metodología TCR", "test verde y commit".
license: MIT
metadata:
  author: andresnator
  version: "1.0"
---

# TCR Commit Skill

**TCR = Test && Commit || Revert**

The core loop is simple: run the tests. If they pass, commit immediately. If they fail, revert the change. This forces small, safe steps and makes every commit a known-good state.

## The TCR Loop

```
1. Make a small change (test or production code)
2. Run the relevant tests
3. GREEN? → git add + git commit (with Conventional Commit message)
4. RED?   → git checkout -- <changed files> (revert to last green state)
```

The discipline is in the **size of the step**. If reverting feels painful, the step was too big.

## Commit Message Format

Use the same commit convention as the team's `git-commit` skill.

### Step 1: Get the branch ID

Run:
```bash
git rev-parse --abbrev-ref HEAD | awk -F'[-/]' '{print $2 "-" $3}'
```

- If output matches `[A-Z]+-[0-9]+` (e.g., `COMPANY-37094`), use it as the branch ID.
- Otherwise, use `COMPANY-00000`.

### Step 2: Format the message

```
BRANCH-ID <type>: brief description
```

Conventional commit types:

| Type       | When to use                                  |
|------------|----------------------------------------------|
| `test`     | Adding or updating tests                     |
| `refactor` | Code change that is not a fix or feature     |
| `fix`      | Bug fix                                      |
| `feat`     | New feature or behavior                      |
| `chore`    | Build, config, tooling, dependency changes   |
| `docs`     | Documentation only changes                   |
| `style`    | Formatting, whitespace (no logic change)     |
| `perf`     | Performance improvement                      |

Types by TCR context:

| Context | Type | Example |
|---------|------|---------|
| New test (characterization or unit) | `test` | `COMPANY-1234 test: add characterization test for calculateTotal` |
| Test passes after refactor step | `refactor` | `COMPANY-1234 refactor: extract calculateDiscount method` |
| Bug fix confirmed by test | `fix` | `COMPANY-1234 fix: correct null handling in getItems` |
| New functionality via Sprout/Wrap | `feat` | `COMPANY-1234 feat: add loyalty discount calculation` |

Keep descriptions concise (imperative mood, no trailing period).

### Step 3: Commit using a HEREDOC

Include a `Co-Authored-By` trailer using the developer's identity from `git config user.name` and `git config user.email`.

```bash
git commit -m "$(cat <<EOF
BRANCH-ID type: brief description

Co-Authored-By: $(git config user.name) <$(git config user.email)>
EOF
)"
```

## TCR During Refactoring (the critical workflow)

When refactoring, the commit order matters. Follow this sequence:

### Phase 1: Commit the safety net first

Before touching production code, ensure tests exist and are committed:

1. Write or verify characterization/unit tests for the code you will refactor
2. Run tests → GREEN
3. **Commit the tests separately**: `BRANCH-ID test: add tests for <behavior>`
4. This commit is your safety net. If anything goes wrong later, you can always return here.

### Phase 2: Refactor in micro-steps

Each refactoring technique becomes one or more TCR cycles:

1. Apply **one small mechanical step** of the technique (e.g., extract a method, rename a variable, move a field)
2. Run tests → GREEN → `BRANCH-ID refactor: <what you did>`
3. RED → revert immediately, try a smaller step
4. Repeat until the technique is fully applied

**Example — Extract Method in 3 TCR cycles:**
```
COMPANY-1234 refactor: extract calculateSubtotal method signature
COMPANY-1234 refactor: move subtotal logic into calculateSubtotal
COMPANY-1234 refactor: inline temp variable after extraction
```

### Phase 3: Harden

After refactoring is complete:

1. Add new unit tests for the refactored structure
2. Run tests → GREEN → `BRANCH-ID test: add tests for <new structure>`

## When to Revert vs. When to Fix

- **Revert** when the change was a refactoring step and tests fail — the refactoring introduced a behavioral change, which means it was wrong. Start over with a smaller step.
- **Fix forward** only when you are writing a new test and the test itself has a bug (typo in assertion, wrong setup). In this case, fix the test, not the production code.

## Practical Commands

### After a green test run:
```bash
# Stage only the files you changed in this step
git add <specific-files>

# Commit with HEREDOC (branch ID already extracted in Step 1 above)
git commit -m "$(cat <<EOF
BRANCH-ID type: brief description

Co-Authored-By: $(git config user.name) <$(git config user.email)>
EOF
)"
```

### After a red test run (revert):
```bash
# Discard uncommitted changes, return to last green state
git checkout -- <changed-files>
```

Always stage specific files, never `git add .` or `git add -A`. This prevents accidental inclusion of unrelated changes.

## Rules

- Never use `--no-verify` or amend published commits unless explicitly requested.
- Never commit `.env` files or credentials.
- Never push unless explicitly asked.
- Keep descriptions concise (imperative mood, no trailing period).

## Integration with Refactoring Agents

When used inside a refactoring workflow (e.g., the java-refactoring-expert agent), TCR modifies the workflow as follows:

| Workflow Step | TCR Behavior |
|---------------|--------------|
| **Cover (Step 3)** | Write tests → run → GREEN → commit with `BRANCH-ID test: ...` |
| **Refactor (Step 4)** | Each micro-step → run → GREEN → commit with `BRANCH-ID refactor: ...` |
| **Harden (Step 5)** | New tests → run → GREEN → commit with `BRANCH-ID test: ...` |
| **Any RED** | Revert the last uncommitted change immediately |

The agent should announce each commit to the user so they can see the trail of safe steps.

## Key Principles

1. **Every commit is green** — no broken commits, ever
2. **Tests before production code** — always commit the safety net first
3. **Revert is not failure** — it means you tried a step that was too big, try smaller
4. **One concern per commit** — a test commit and a refactor commit are separate
5. **The branch prefix is mandatory** — extract it from the branch name automatically
6. **Specific file staging** — never use `git add .`, always name the files
