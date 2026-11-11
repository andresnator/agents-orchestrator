import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = new URL("../", import.meta.url).pathname;
const script = join(root, "make-scripts/mini.sh");

function setup(t, text) {
  const dir = mkdtempSync(join(tmpdir(), "mini-settings-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const file = join(dir, "cli.json");
  if (text !== undefined) writeFileSync(file, text);
  const env = { ...process.env, OPENCODE_DIR: dir, FORCE: "" };
  return {
    dir, file, env,
    run: (action = "set", overrides = {}) => spawnSync("bash", [script, action], {
      cwd: root, env: { ...env, ...overrides }, encoding: "utf8",
    }),
  };
}

test("shouldCreatePrivateMiniSettingsWhenConfigIsMissing", (t) => {
  // Given
  const { file, run } = setup(t);
  // When
  const result = run();
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), {
    $schema: "https://opencode.ai/v2/cli.json",
    mini: { thinking: "hide", tools: "show", shell_output: "hide" },
  });
  assert.equal(statSync(file).mode & 0o777, 0o600);
});

test("shouldKeepCommentsAndOtherSettingsWhenConfigExists", (t) => {
  // Given
  const { dir, file, run } = setup(t, '{\n  // keep this\n  "plugins": ["example"],\n  "session": {"permissions":"prompt"},\n  "mini": {"footer":"show"}\n}\n');
  const before = readFileSync(file, "utf8");
  writeFileSync(join(dir, "opencode.json"), '{"model":"test/model"}');
  // When
  const result = run();
  // Then
  assert.equal(result.status, 0, result.stderr);
  const after = readFileSync(file, "utf8");
  assert.match(after, /\/\/ keep this/);
  assert.deepEqual(JSON.parse(after.replace(/\/\/ keep this/, "")), {
    plugins: ["example"], session: { permissions: "prompt" },
    mini: { footer: "show", thinking: "hide", tools: "show", shell_output: "hide" },
  });
  assert.equal(readFileSync(`${file}.bak`, "utf8"), before);
  assert.equal(readFileSync(join(dir, "opencode.json"), "utf8"), '{"model":"test/model"}');
});

test("shouldKeepConfigAndBackupUnchangedWhenRunTwice", (t) => {
  // Given
  const { file, run } = setup(t, "{}\n");
  assert.equal(run().status, 0);
  const before = readFileSync(file, "utf8");
  // When
  const result = run();
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(file, "utf8"), before);
  assert.equal(readFileSync(`${file}.bak`, "utf8"), "{}\n");
});

test("shouldRefuseAllChangesWhenALaterSettingConflicts", (t) => {
  // Given
  const original = '{"mini":{"shell_output":"show"}}';
  const { file, run } = setup(t, original);
  // When
  const result = run();
  // Then
  assert.equal(result.status, 1);
  assert.match(result.stderr, /FORCE=1/);
  assert.equal(readFileSync(file, "utf8"), original);
  assert.equal(existsSync(`${file}.bak`), false);
});

test("shouldReplaceConflictsWhenForceIsOne", (t) => {
  // Given
  const { file, run } = setup(t, '{"mini":{"thinking":"show","footer":"hide"}}');
  // When
  const result = run("set", { FORCE: "1" });
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), {
    mini: { thinking: "hide", tools: "show", shell_output: "hide", footer: "hide" },
  });
});

for (const text of ["", " \n", "{}", '{"mini":{}}']) {
  test(`shouldAcceptEmptyConfigWhenInputIs${JSON.stringify(text)}`, (t) => {
    // Given
    const { file, run } = setup(t, text);
    // When
    const result = run();
    // Then
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(readFileSync(file, "utf8")).mini, {
      thinking: "hide", tools: "show", shell_output: "hide",
    });
  });
}

for (const text of ['{"mini":', '{"mini":[]}', '[]', '{"mini":null}']) {
  test(`shouldKeepInvalidConfigWhenInputIs${text}`, (t) => {
    // Given
    const { file, run } = setup(t, text);
    // When
    const result = run();
    // Then
    assert.equal(result.status, 1);
    assert.match(result.stderr, /cannot read/);
    assert.equal(readFileSync(file, "utf8"), text);
    assert.equal(existsSync(`${file}.bak`), false);
  });
}

test("shouldRemoveOnlyManagedFieldsWhenOtherSettingsExist", (t) => {
  // Given
  const { file, run } = setup(t, '{"mini":{"thinking":"hide","tools":"show","shell_output":"hide","footer":"show"},"theme":{"name":"system"}}');
  // When
  const result = run("remove");
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), {
    mini: { footer: "show" }, theme: { name: "system" },
  });
});

test("shouldLeaveNoMiniObjectWhenAllManagedFieldsAreRemoved", (t) => {
  // Given
  const { file, run } = setup(t, '{"mini":{"thinking":"hide","tools":"show","shell_output":"hide"},"mouse":true}');
  // When
  const result = run("remove");
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), { mouse: true });
});

test("shouldNotCreateConfigWhenRemoveRunsBeforeSet", (t) => {
  // Given
  const { file, run } = setup(t);
  // When
  const result = run("remove");
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(file), false);
});

test("shouldKeepSymlinkAndModeWhenUpdatingConfig", (t) => {
  // Given
  const { dir, file, run } = setup(t);
  const target = join(dir, "real.json");
  writeFileSync(target, "{}");
  chmodSync(target, 0o640);
  symlinkSync(target, file);
  // When
  const result = run();
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.equal(lstatSync(file).isSymbolicLink(), true);
  assert.equal(statSync(file).mode & 0o777, 0o640);
  assert.deepEqual(JSON.parse(readFileSync(target, "utf8")).mini, {
    thinking: "hide", tools: "show", shell_output: "hide",
  });
});

test("shouldKeepConfigWhenPythonFails", (t) => {
  // Given
  const { dir, file, run } = setup(t, "{}\n");
  const bin = join(dir, "bin");
  mkdirSync(bin);
  writeFileSync(join(bin, "python3"), "#!/bin/sh\nexit 7\n", { mode: 0o755 });
  // When
  const result = run("set", { PATH: `${bin}:${process.env.PATH}` });
  // Then
  assert.equal(result.status, 1);
  assert.match(result.stderr, /cannot read/);
  assert.equal(readFileSync(file, "utf8"), "{}\n");
});

test("shouldRejectUnknownActionWithoutChangingConfig", (t) => {
  // Given
  const { file, run } = setup(t, "{}\n");
  // When
  const result = run("unknown");
  // Then
  assert.equal(result.status, 2);
  assert.match(result.stderr, /usage:/);
  assert.equal(readFileSync(file, "utf8"), "{}\n");
});

test("shouldUseXdgConfigHomeWhenMakeHasNoDirectoryOverride", (t) => {
  // Given
  const { dir, env } = setup(t);
  delete env.OPENCODE_DIR;
  env.XDG_CONFIG_HOME = dir;
  // When
  const result = spawnSync("make", ["mini"], { cwd: root, env, encoding: "utf8" });
  // Then
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(join(dir, "opencode/cli.json"), "utf8")), {
    $schema: "https://opencode.ai/v2/cli.json",
    mini: { thinking: "hide", tools: "show", shell_output: "hide" },
  });
});
