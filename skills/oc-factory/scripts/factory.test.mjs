import test from "node:test";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";

const FACTORY = join(dirname(fileURLToPath(import.meta.url)), "factory.sh");

// The fake runner reads the mode from the brief. The prompt is its last argument.
const FAKE_RUNNER = `#!/usr/bin/env bash
set -euo pipefail
for prompt; do :; done
id="$(basename "$PWD")"
commit() { echo "$2" >"$1"; git add -- "$1"; git commit -q -m "task: $1"; }
case "$prompt" in
  *"mode: write"*) commit "$id.txt" "made by $id"; echo "FACTORY: done" ;;
  *"mode: readme"*) commit README.md "from the task"; echo "FACTORY: done" ;;
  *"mode: ask"*)
    case "$prompt" in
      *"## Answer"*8080*) commit port.txt 8080; echo "FACTORY: done" ;;
      *) echo "FACTORY: needs-input Which port?" ;;
    esac ;;
  *"mode: hold"*) echo "$$" >"$HOLD_FILE.$id.pid"; while [ ! -f "$HOLD_FILE" ]; do sleep 0.05; done; echo "FACTORY: done" ;;
  *"mode: exit-3"*) echo "FACTORY: done"; exit 3 ;;
  *"mode: no-line"*) echo "work finished" ;;
  *"mode: give-up"*) echo "FACTORY: failed tests are red" ;;
  *"mode: echo-prompt"*) printf '%s\\n' "$prompt" ;;
  *"mode: decorated"*) printf 'caf\\377\\376 output\\n'; echo "FACTORY: failed early try"; printf '  **FACTORY: needs-input: Which port?**  \\r\\n' ;;
  *"mode: untracked"*) commit "$id.txt" "made by $id"; echo "draft" >notes.txt; echo "FACTORY: done" ;;
esac
`;

const FAKE_OPENCODE = `#!/usr/bin/env bash
if [ "$1 $2" = "run --help" ]; then
  echo "  --agent string   Agent to use"
  [ -z "\${FAKE_AUTO:-}" ] || echo "  --auto           Auto-approve permissions"
  exit 0
fi
printf '%s\\n' "$#" "$1" "$2" "$3" "$4" "$5" "$6" >"$ARGS_FILE"
for last; do :; done
printf '%s' "$last" >"$ARGS_FILE.prompt"
echo "FACTORY: done"
`;

function git(cwd, ...args) {
  const result = spawnSync("git", args, { cwd, encoding: "utf8", env: gitEnv() });
  assert.equal(result.status, 0, `git ${args.join(" ")}: ${result.stderr}`);
  return result.stdout.trim();
}

function gitEnv() {
  return { PATH: process.env.PATH, HOME: process.env.HOME, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };
}

// Make <tmp>/repo with one commit and a fake runner. Remove all of it after the test.
function fixture(t) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "factory-test-")));
  const repo = join(root, "repo");
  const runner = join(root, "runner.sh");
  const holdFile = join(root, "release");
  mkdirSync(repo);
  writeFileSync(runner, FAKE_RUNNER);
  chmodSync(runner, 0o755);
  git(repo, "init", "-q", "-b", "main");
  git(repo, "config", "user.name", "Factory Test");
  git(repo, "config", "user.email", "factory@example.invalid");
  writeFileSync(join(repo, "README.md"), "base\n");
  git(repo, "add", "--", "README.md");
  git(repo, "commit", "-q", "-m", "chore: base");
  const env = { ...gitEnv(), FACTORY_RUNNER: runner, HOLD_FILE: holdFile };
  const fx = {
    root, repo, runner, holdFile, env,
    worktree: (id) => join(root, ".repo-factory", id),
    run: (args, options = {}) => spawnSync("bash", [FACTORY, ...args], {
      cwd: options.cwd ?? repo, encoding: "utf8", input: options.input ?? "", env: { ...env, ...options.env },
    }),
    ok(args, options) {
      const result = fx.run(args, options);
      assert.equal(result.status, 0, `factory ${args.join(" ")}: ${result.stderr}`);
      return result.stdout;
    },
    add: (id, brief) => fx.ok(["add", id, "-"], { input: brief }),
    board() {
      const rows = {};
      for (const line of fx.ok(["status"]).split("\n")) {
        const cells = line.split("|").map((cell) => cell.trim());
        if (cells.length === 6 && cells[1] !== "Task" && cells[1] !== "---") {
          rows[cells[1]] = { state: cells[2], commits: cells[3], note: cells[4] };
        }
      }
      return rows;
    },
    async waitFor(id, state, timeoutMs = 120000) {
      const end = Date.now() + timeoutMs;
      let row;
      while (Date.now() < end) {
        row = fx.board()[id];
        if (row?.state === state) return row;
        await sleep(100);
      }
      assert.fail(`task ${id} did not reach ${state}; last row: ${JSON.stringify(row)}`);
    },
  };
  t.after(() => {
    writeFileSync(holdFile, "");
    const tasks = join(repo, ".ai/factory/tasks");
    for (const file of existsSync(tasks) ? readdirSync(tasks) : []) fx.run(["drop", file.replace(/\.md$/, "")]);
    rmSync(root, { recursive: true, force: true });
  });
  return fx;
}

function pidAlive(pid) {
  try { process.kill(pid, 0); return true; } catch { return false; }
}

test("shouldReachDoneWithOneCommitAheadWhenRunnerCommitsAndReportsDone", async (t) => {
  const fx = fixture(t);

  assert.equal(fx.add("add-feature", "mode: write\n"), "add-feature: queued\n");
  assert.deepEqual(fx.board()["add-feature"], { state: "queued", commits: "-", note: "" });
  fx.ok(["start"]);
  const row = await fx.waitFor("add-feature", "done");

  assert.deepEqual(row, { state: "done", commits: "1", note: "" });
  assert.equal(readFileSync(join(fx.worktree("add-feature"), "add-feature.txt"), "utf8"), "made by add-feature\n");
  assert.equal(git(fx.repo, "log", "-1", "--format=%s", "factory/add-feature"), "task: add-feature.txt");
  assert.equal(git(fx.repo, "status", "--porcelain"), "", ".ai/ must be ignored in the main working tree");
  const printed = fx.ok(["status"]);
  assert.equal(readFileSync(join(fx.repo, ".ai/factory/board.md"), "utf8"), printed);
  assert.match(printed, /^# Factory board\n\nUpdated: \d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\n\n\| Task \| State \| Commits \| Note \|\n/);
});

test("shouldShowQuestionWhileSecondTaskFinishesWhenFirstTaskNeedsInput", async (t) => {
  const fx = fixture(t);
  fx.add("ask-port", "mode: ask\n");
  fx.add("write-file", "mode: write\n");

  fx.ok(["start"]);
  const asked = await fx.waitFor("ask-port", "needs-input");
  const finished = await fx.waitFor("write-file", "done");

  assert.deepEqual(asked, { state: "needs-input", commits: "0", note: "Which port?" });
  assert.deepEqual(finished, { state: "done", commits: "1", note: "" });
});

test("shouldRestartTaskInSameWorktreeAndReachDoneWhenUserAnswers", async (t) => {
  const fx = fixture(t);
  fx.add("ask-port", "mode: ask\n");
  fx.ok(["start", "ask-port"]);
  await fx.waitFor("ask-port", "needs-input");

  assert.equal(fx.ok(["answer", "ask-port", "Use", "8080"]), "ask-port: running (answer added)\n");
  const row = await fx.waitFor("ask-port", "done");

  assert.deepEqual(row, { state: "done", commits: "1", note: "" });
  assert.equal(readFileSync(join(fx.repo, ".ai/factory/tasks/ask-port.md"), "utf8"), "mode: ask\n\n## Answer\n\nUse 8080\n");
  assert.equal(readFileSync(join(fx.worktree("ask-port"), "port.txt"), "utf8"), "8080\n");
});

test("shouldReportFailedWithExitCodeWhenRunnerExitsNonZero", async (t) => {
  const fx = fixture(t);
  fx.add("crash", "mode: exit-3\n");

  fx.ok(["start"]);
  const row = await fx.waitFor("crash", "failed");

  assert.deepEqual(row, { state: "failed", commits: "0", note: "runner exit code 3" });
});

test("shouldReportFailedWhenRunnerEndsWithoutFactoryLineOrWithFailedLine", async (t) => {
  const fx = fixture(t);
  fx.add("silent", "mode: no-line\n");
  fx.add("red", "mode: give-up\n");

  fx.ok(["start"]);

  assert.equal((await fx.waitFor("silent", "failed")).note, "no FACTORY line in the log");
  assert.equal((await fx.waitFor("red", "failed")).note, "tests are red");
  assert.match(fx.ok(["logs", "red", "1"]), /^FACTORY: failed tests are red\n$/);
});

test("shouldRemoveWorktreeAndBranchWhenMergeSucceeds", async (t) => {
  const fx = fixture(t);
  fx.add("add-feature", "mode: write\n");
  fx.ok(["start"]);
  await fx.waitFor("add-feature", "done");

  const out = fx.ok(["merge", "add-feature"]);

  assert.equal(out, "add-feature: merged into main (commits: 1); worktree and branch removed\n");
  assert.equal(readFileSync(join(fx.repo, "add-feature.txt"), "utf8"), "made by add-feature\n");
  assert.equal(existsSync(fx.worktree("add-feature")), false);
  assert.equal(git(fx.repo, "branch", "--list", "factory/add-feature"), "");
  assert.deepEqual(fx.board()["add-feature"], { state: "merged", commits: "1", note: "" });
});

test("shouldKeepWorktreeWhenMergedTaskHasFilesWithoutCommit", async (t) => {
  const fx = fixture(t);
  fx.add("with-draft", "mode: untracked\n");
  fx.ok(["start"]);
  await fx.waitFor("with-draft", "done");

  fx.ok(["merge", "with-draft"]);

  assert.equal(readFileSync(join(fx.worktree("with-draft"), "notes.txt"), "utf8"), "draft\n");
  assert.equal(fx.board()["with-draft"].state, "merged");
  assert.match(fx.board()["with-draft"].note, /^worktree kept: /);
});

test("shouldAbortMergeAndMarkConflictWhenBranchConflictsWithMainTree", async (t) => {
  const fx = fixture(t);
  fx.add("edit-readme", "mode: readme\n");
  fx.ok(["start"]);
  await fx.waitFor("edit-readme", "done");
  writeFileSync(join(fx.repo, "README.md"), "from the user\n");
  writeFileSync(join(fx.repo, "notes.md"), "v1\n");
  git(fx.repo, "add", "--", "README.md", "notes.md");
  git(fx.repo, "commit", "-q", "-m", "docs: user edit");
  writeFileSync(join(fx.repo, "notes.md"), "work without commit\n");

  const result = fx.run(["merge", "edit-readme"]);

  assert.equal(result.status, 1);
  assert.match(result.stderr, /edit-readme: conflict \(merge aborted; files: README\.md\)/);
  assert.equal(git(fx.repo, "status", "--porcelain"), "M notes.md");
  assert.equal(readFileSync(join(fx.repo, "notes.md"), "utf8"), "work without commit\n");
  assert.equal(existsSync(join(fx.repo, ".git/MERGE_HEAD")), false);
  assert.equal(readFileSync(join(fx.repo, "README.md"), "utf8"), "from the user\n");
  assert.deepEqual(fx.board()["edit-readme"], { state: "conflict", commits: "1", note: "merge conflict in: README.md" });
  assert.equal(git(fx.repo, "branch", "--list", "factory/edit-readme").replace(/^[+* ]+/, ""), "factory/edit-readme");
});

test("shouldRefuseMergeWhenTaskIsNotDone", async (t) => {
  const fx = fixture(t);
  fx.add("crash", "mode: exit-3\n");
  fx.add("waiting", "mode: write\n");
  fx.ok(["start", "crash"]);
  await fx.waitFor("crash", "failed");

  const failed = fx.run(["merge", "crash"]);
  const queued = fx.run(["merge", "waiting"]);

  assert.equal(failed.status, 1);
  assert.equal(failed.stderr, "factory: cannot merge crash: state is failed (merge needs done)\n");
  assert.equal(queued.stderr, "factory: cannot merge waiting: state is queued (merge needs done)\n");
  assert.equal(git(fx.repo, "rev-list", "--count", "HEAD"), "1");
});

test("shouldStopRunnerAndRemoveAllWhenRunningTaskIsDropped", async (t) => {
  const fx = fixture(t);
  fx.add("long-task", "mode: hold\n");
  fx.ok(["start"]);
  await fx.waitFor("long-task", "running");
  const pid = Number(readFileSync(join(fx.repo, ".ai/factory/state/long-task.pid"), "utf8"));
  // The wrapper is "running" before the runner under it writes its pid.
  let runnerPid = 0;
  for (const end = Date.now() + 120000; !runnerPid && Date.now() < end; await sleep(50)) {
    if (existsSync(`${fx.holdFile}.long-task.pid`)) runnerPid = Number(readFileSync(`${fx.holdFile}.long-task.pid`, "utf8"));
  }
  assert.notEqual(runnerPid, 0, "the runner did not write its pid");
  assert.equal(pidAlive(pid), true);
  assert.equal(pidAlive(runnerPid), true);

  assert.equal(fx.ok(["drop", "long-task"]), "long-task: dropped\n");

  assert.equal(pidAlive(pid), false);
  assert.equal(pidAlive(runnerPid), false, "drop must stop the process group, not only the wrapper");
  assert.equal(existsSync(fx.worktree("long-task")), false);
  assert.equal(git(fx.repo, "branch", "--list", "factory/long-task"), "");
  assert.equal(git(fx.repo, "worktree", "list").split("\n").length, 1);
  assert.equal(existsSync(join(fx.repo, ".ai/factory/tasks/long-task.md")), false);
  assert.equal(existsSync(join(fx.repo, ".ai/factory/logs/long-task.log")), false);
  assert.match(fx.ok(["status"]), /\nNo tasks\.\n$/);
});

test("shouldStartOnlyFreeSlotsWhenMaxIsSet", async (t) => {
  const fx = fixture(t);
  fx.add("task-a", "mode: hold\n");
  fx.add("task-b", "mode: hold\n");
  fx.add("task-c", "mode: hold\n");
  const states = () => Object.values(fx.board()).map((row) => row.state).sort();

  const first = fx.ok(["start", "--max", "2"]);
  assert.match(first, /task-c: queued \(limit --max 2 reached\)/);
  assert.deepEqual(states(), ["queued", "running", "running"]);

  fx.ok(["start", "--max", "2"]);
  assert.deepEqual(states(), ["queued", "running", "running"], "two tasks run already, so no slot is free");

  writeFileSync(fx.holdFile, "");
  await fx.waitFor("task-a", "done");
  await fx.waitFor("task-b", "done");
  fx.ok(["start", "--max", "2"]);
  await fx.waitFor("task-c", "done");
});

test("shouldRejectInvalidInputWithPlainMessage", (t) => {
  const fx = fixture(t);
  fx.add("task-a", "mode: write\n");
  const cases = [
    [["add", "task-a", "-"], "factory: task exists already: task-a\n"],
    [["add", "Bad_Id", "-"], "factory: invalid id: Bad_Id (use kebab-case, for example fix-login)\n"],
    [["add", "task-b", "missing.md"], "factory: brief file not found: missing.md\n"],
    [["add", "task-b", "-"], "factory: brief is empty: task-b\n"],
    [["start", "nope"], "factory: unknown task: nope\n"],
    [["answer", "nope", "text"], "factory: unknown task: nope\n"],
    [["answer", "task-a", "text"], "factory: task is not started: task-a (run start)\n"],
    [["logs", "nope"], "factory: unknown task: nope\n"],
    [["merge", "nope"], "factory: unknown task: nope\n"],
    [["drop", "nope"], "factory: unknown task: nope\n"],
    [["drop", "-rf"], "factory: invalid id: -rf (use kebab-case, for example fix-login)\n"],
    [["logs", "task a"], "factory: invalid id: task a (use kebab-case, for example fix-login)\n"],
    [["start", "--max"], "factory: --max needs a number\n"],
    [["start", "--max", "0"], "factory: --max needs a number greater than 0\n"],
  ];

  for (const [args, message] of cases) {
    const result = fx.run(args);
    assert.equal(result.status, 1, args.join(" "));
    assert.equal(result.stderr, message);
  }
  assert.deepEqual(Object.keys(fx.board()), ["task-a"]);
});

test("shouldFailWhenDirectoryIsNotGitRepository", (t) => {
  const fx = fixture(t);

  const result = fx.run(["status"], { cwd: fx.root });

  assert.equal(result.status, 1);
  assert.equal(result.stderr, "factory: not in a Git repository\n");
  assert.equal(existsSync(join(fx.root, ".ai")), false);
});

test("shouldFailAndStartNothingWhenRunnerIsMissing", (t) => {
  const fx = fixture(t);
  fx.add("task-a", "mode: write\n");

  const result = fx.run(["start"], { env: { FACTORY_RUNNER: "/nonexistent/factory-runner --flag" } });

  assert.equal(result.status, 1);
  assert.equal(result.stderr, "factory: runner not found: /nonexistent/factory-runner (from FACTORY_RUNNER)\n");
  assert.equal(fx.board()["task-a"].state, "queued");
  assert.equal(existsSync(fx.worktree("task-a")), false);
});

function fakeOpencode(fx) {
  const bin = join(fx.root, "bin");
  mkdirSync(bin);
  writeFileSync(join(bin, "opencode"), FAKE_OPENCODE);
  chmodSync(join(bin, "opencode"), 0o755);
  const argsFile = join(fx.root, "args");
  return { argsFile, env: { FACTORY_RUNNER: "", PATH: `${bin}:${process.env.PATH}`, ARGS_FILE: argsFile } };
}

test("shouldPrintDefaultRunnerCommandAndStartNothingWhenDryRunIsSet", (t) => {
  const fx = fixture(t);
  const fake = fakeOpencode(fx);
  fx.add("task-a", "mode: write\n");

  const v2 = fx.ok(["start"], { env: { ...fake.env, FACTORY_DRY_RUN: "1", FAKE_AUTO: "1" } });
  const v1 = fx.ok(["start"], { env: { ...fake.env, FACTORY_DRY_RUN: "1" } });

  assert.equal(v2, 'task-a: dry-run: opencode run --agent worker --title "factory/task-a" --auto <prompt>\n');
  assert.equal(v1, 'task-a: dry-run: opencode run --agent worker --title "factory/task-a" <prompt>\n');
  assert.equal(fx.board()["task-a"].state, "queued");
  assert.equal(existsSync(fx.worktree("task-a")), false);
  assert.equal(existsSync(fake.argsFile), false);
});

test("shouldPassAgentTitleAndPromptAsLastArgumentWhenRunnerIsDefault", async (t) => {
  const fx = fixture(t);
  const fake = fakeOpencode(fx);
  fx.add("task-a", "Goal: add a health endpoint.\n");

  fx.ok(["start"], { env: { ...fake.env, FAKE_AUTO: "1" } });
  await fx.waitFor("task-a", "done");

  assert.equal(readFileSync(fake.argsFile, "utf8"), "7\nrun\n--agent\nworker\n--title\nfactory/task-a\n--auto\n");
  const prompt = readFileSync(`${fake.argsFile}.prompt`, "utf8");
  assert.match(prompt, /^You are a factory worker\. You work alone in a Git worktree on the branch factory\/task-a\./);
  assert.match(prompt, /\n   When you cannot continue without the user, the line is: FACTORY: needs-input <one question>\n/);
  assert.match(prompt, /\nBrief:\n\nGoal: add a health endpoint\.$/);
});

test("shouldKeepFilesOutsideFactoryWhenDropGetsIdWithPathParts", (t) => {
  const fx = fixture(t);
  mkdirSync(join(fx.repo, ".ai/plans"), { recursive: true });
  writeFileSync(join(fx.repo, ".ai/plans/login.md"), "# Plan\n");

  const result = fx.run(["drop", "../../plans/login"]);

  assert.equal(result.status, 1);
  assert.equal(result.stderr, "factory: invalid id: ../../plans/login (use kebab-case, for example fix-login)\n");
  assert.equal(readFileSync(join(fx.repo, ".ai/plans/login.md"), "utf8"), "# Plan\n");
});

test("shouldReadLastDecoratedFactoryLineWhenLogHasInvalidBytes", async (t) => {
  const fx = fixture(t);
  fx.add("decorated", "mode: decorated\n");

  fx.ok(["start"]);
  const row = await fx.waitFor("decorated", "needs-input");

  assert.deepEqual(row, { state: "needs-input", commits: "0", note: "Which port?" });
});

test("shouldNotReadResultFromContractWhenRunnerEchoesPrompt", async (t) => {
  const fx = fixture(t);
  fx.add("echo", "mode: echo-prompt\n");

  fx.ok(["start"]);
  const row = await fx.waitFor("echo", "failed");

  assert.equal(row.note, "no FACTORY line in the log");
  assert.match(fx.ok(["logs", "echo", "200"]), /the line is: FACTORY: done\n/);
});

test("shouldReportFailedAndSpareProcessWhenPidBelongsToDifferentProcess", async (t) => {
  const fx = fixture(t);
  fx.add("long-task", "mode: hold\n");
  fx.ok(["start"]);
  await fx.waitFor("long-task", "running");
  const pidFile = join(fx.repo, ".ai/factory/state/long-task.pid");
  process.kill(-Number(readFileSync(pidFile, "utf8")), "SIGKILL");
  // The clock of ps has a resolution of one second. Make the start times different.
  await sleep(1100);
  const other = spawn("sleep", ["300"], { detached: true, stdio: "ignore" });
  t.after(() => other.kill("SIGKILL"));
  writeFileSync(pidFile, `${other.pid}\n`);

  const row = fx.board()["long-task"];
  fx.ok(["drop", "long-task"]);

  assert.deepEqual(row, { state: "failed", commits: "0", note: "runner stopped without an exit code" });
  assert.equal(pidAlive(other.pid), true, "drop must not stop a process that is not the runner");
});

test("shouldRefuseMergeAndKeepUserMergeWhenMergeIsInProgress", async (t) => {
  const fx = fixture(t);
  fx.add("add-feature", "mode: write\n");
  fx.ok(["start"]);
  await fx.waitFor("add-feature", "done");
  git(fx.repo, "switch", "-q", "-c", "other");
  writeFileSync(join(fx.repo, "README.md"), "other\n");
  git(fx.repo, "commit", "-q", "-m", "docs: other", "--", "README.md");
  git(fx.repo, "switch", "-q", "main");
  writeFileSync(join(fx.repo, "README.md"), "main\n");
  git(fx.repo, "commit", "-q", "-m", "docs: main", "--", "README.md");
  spawnSync("git", ["merge", "other"], { cwd: fx.repo, env: gitEnv() });
  writeFileSync(join(fx.repo, "README.md"), "resolved by the user\n");

  const result = fx.run(["merge", "add-feature"]);

  assert.equal(result.status, 1);
  assert.equal(result.stderr, `factory: a merge is in progress in ${fx.repo}; complete it or abort it, then merge add-feature again\n`);
  assert.equal(existsSync(join(fx.repo, ".git/MERGE_HEAD")), true);
  assert.equal(readFileSync(join(fx.repo, "README.md"), "utf8"), "resolved by the user\n");
  git(fx.repo, "merge", "--abort");
  assert.equal(fx.board()["add-feature"].state, "done");
});

test("shouldRefuseToRunWhenDirectoryIsFactoryWorktree", async (t) => {
  const fx = fixture(t);
  fx.add("add-feature", "mode: write\n");
  fx.ok(["start"]);
  await fx.waitFor("add-feature", "done");

  const result = fx.run(["status"], { cwd: fx.worktree("add-feature") });

  assert.equal(result.status, 1);
  assert.equal(result.stderr, "factory: this is a factory worktree; run from the main working tree of the repository\n");
  assert.equal(existsSync(join(fx.worktree("add-feature"), ".ai")), false);
});

test("shouldUseSameStateAndWorktreeWhenRunFromSubdirectoryWithRelativeWorktrees", async (t) => {
  const fx = fixture(t);
  mkdirSync(join(fx.repo, "src"));
  const options = { cwd: join(fx.repo, "src"), env: { FACTORY_WORKTREES: "../trees" } };
  fx.ok(["add", "add-feature", "-"], { ...options, input: "mode: write\n" });

  fx.ok(["start"], options);
  const row = await fx.waitFor("add-feature", "done");

  assert.deepEqual(row, { state: "done", commits: "1", note: "" });
  assert.equal(readFileSync(join(fx.root, "trees/add-feature/add-feature.txt"), "utf8"), "made by add-feature\n");
  assert.equal(existsSync(join(fx.repo, "src/.ai")), false);
  fx.ok(["drop", "add-feature"], options);
  assert.equal(existsSync(join(fx.root, "trees")), false);
});

test("shouldWriteCompleteBoardWhenStatusRunsEightTimesAtSameTime", async (t) => {
  const fx = fixture(t);
  fx.add("task-a", "mode: write\n");

  const codes = await Promise.all(Array.from({ length: 8 }, () => new Promise((resolve) => {
    spawn("bash", [FACTORY, "status"], { cwd: fx.repo, env: fx.env, stdio: "ignore" }).on("close", resolve);
  })));

  assert.deepEqual(codes, [0, 0, 0, 0, 0, 0, 0, 0]);
  assert.match(readFileSync(join(fx.repo, ".ai/factory/board.md"), "utf8"), /\| task-a \| queued \| - \|  \|\n$/);
  assert.deepEqual(readdirSync(join(fx.repo, ".ai/factory")).sort(), ["board.md", "logs", "state", "tasks"]);
});
