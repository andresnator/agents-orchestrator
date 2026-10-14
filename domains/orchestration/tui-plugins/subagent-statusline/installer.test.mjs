import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = fileURLToPath(new URL("../../../../", import.meta.url));
const INSTALLER = join(ROOT, "installers/opencode.sh");
const PLUGIN_SPEC = "./plugins/subagent-statusline.tsx";
const FOREIGN_SPEC = "./plugins/foreign.tsx";
const CLI_CONFIG = JSON.stringify({ plugins: [FOREIGN_SPEC], theme: "user-theme" });
const INSTALLED_FILES = [
  "plugins/subagent-statusline.tsx",
  "plugins/subagent-statusline/tui.tsx",
  "plugins/subagent-statusline/statusline.mjs",
  "plugins/subagent-statusline/package.json",
];

async function fixture(t, version = "2.0.28") {
  const root = await mkdtemp(join(tmpdir(), "statusline-installer-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const target = join(root, "config");
  const binary = join(root, "opencode");
  await writeFile(binary, `#!/bin/sh\nprintf 'opencode v${version}\\n'\n`, { mode: 0o700 });
  const env = { ...process.env, OPENCODE_BIN: binary };
  const args = (action, extra) => [
    INSTALLER, action, "--domain", "orchestration", "--target", target,
    ...(action === "install" ? ["--no-install-brew-tools"] : []), ...extra,
  ];
  return {
    target,
    run: (action, extra = []) => execFileSync("bash", args(action, extra), { cwd: ROOT, env, encoding: "utf8" }),
    attempt: (extraEnv = {}) => spawnSync("bash", args("install", []), {
      cwd: ROOT, env: { ...env, ...extraEnv }, encoding: "utf8",
    }),
  };
}

async function snapshot(directory) {
  const entries = {};
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    entries[entry.name] = entry.isDirectory() ? await snapshot(path) : await readFile(path, "utf8");
  }
  return entries;
}

test("shouldPlanCompleteNativeStatuslineWhenOrchestrationIsDryRun", async (t) => {
  // Given
  const f = await fixture(t);

  // When
  const output = f.run("install", ["--dry-run"]);

  // Then
  for (const path of INSTALLED_FILES) assert.ok(output.includes(join(f.target, path)), path);
  assert.ok(output.includes("cli.json.plugins = " + PLUGIN_SPEC));
  assert.doesNotMatch(output, /(?:installer|statusline)\.test\.mjs/);
  await assert.rejects(readdir(f.target), { code: "ENOENT" });
});

test("shouldPreserveForeignConfigWhenInstallingReinstallingAndUninstallingStatusline", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  await writeFile(join(f.target, "cli.json"), CLI_CONFIG);
  await writeFile(join(f.target, "tui.json"), '{"plugin":["foreign-legacy"]}');
  await writeFile(join(f.target, "foreign.txt"), "preserve");

  // When
  f.run("install");
  const manifest = await readFile(join(f.target, ".agents-orchestrator-manifest"), "utf8");
  const config = JSON.parse(await readFile(join(f.target, "cli.json"), "utf8"));
  const installed = await import(pathToFileURL(join(f.target, "plugins/subagent-statusline/statusline.mjs")));
  f.run("install");
  const secondManifest = await readFile(join(f.target, ".agents-orchestrator-manifest"), "utf8");
  const status = f.run("status");
  const support = await readdir(join(f.target, "plugins/subagent-statusline"));
  f.run("uninstall");

  // Then
  assert.deepEqual(config, { plugins: [FOREIGN_SPEC, PLUGIN_SPEC], theme: "user-theme" });
  assert.equal(typeof installed.statuslineDefinition, "function");
  assert.equal(secondManifest, manifest);
  for (const path of INSTALLED_FILES) assert.ok(manifest.includes("file\t" + join(f.target, path) + "\n"), path);
  assert.match(status, /subagent-statusline\.tsx.*generated\+registered/);
  assert.deepEqual(support.sort(), ["package.json", "statusline.mjs", "tui.tsx"]);
  assert.deepEqual(JSON.parse(await readFile(join(f.target, "cli.json"), "utf8")), {
    plugins: [FOREIGN_SPEC], theme: "user-theme",
  });
  assert.equal(await readFile(join(f.target, "tui.json"), "utf8"), '{"plugin":["foreign-legacy"]}');
  assert.equal(await readFile(join(f.target, "foreign.txt"), "utf8"), "preserve");
  await assert.rejects(readFile(join(f.target, INSTALLED_FILES[0])), { code: "ENOENT" });
});

test("shouldDetectAndRepairSupportDriftWhenOwnedMjsOrManifestChanges", async (t) => {
  // Given
  const f = await fixture(t);
  f.run("install");
  const support = ["statusline.mjs", "package.json"];

  // When
  for (const name of support) {
    const path = join(f.target, "plugins/subagent-statusline", name);
    await writeFile(path, "stale");
    const status = f.run("status");
    assert.doesNotMatch(status, /subagent-statusline\.tsx.*generated\+registered/);
    f.run("install");
  }

  // Then
  for (const name of support) {
    assert.equal(await readFile(join(f.target, "plugins/subagent-statusline", name), "utf8"),
      await readFile(new URL(name, import.meta.url), "utf8"));
  }
  assert.match(f.run("status"), /subagent-statusline\.tsx.*generated\+registered/);
});

for (const name of ["statusline.mjs", "package.json"]) {
  test(`shouldRejectBeforeMutationWhenSupportFileIsForeign_${name}`, async (t) => {
    // Given
    const f = await fixture(t);
    const directory = join(f.target, "plugins/subagent-statusline");
    await mkdir(directory, { recursive: true });
    await writeFile(join(directory, name), "foreign");
    await writeFile(join(f.target, "cli.json"), CLI_CONFIG);
    const before = await snapshot(f.target);

    // When
    const result = f.attempt();

    // Then
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /not an installer-owned TUI source/);
    assert.deepEqual(await snapshot(f.target), before);
  });
}

test("shouldRejectBeforeMutationWhenNativeCliPluginListIsInvalid", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  await writeFile(join(f.target, "cli.json"), '{"plugins":"not-an-array"}');
  const before = await snapshot(f.target);

  // When
  const result = f.attempt();

  // Then
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /not valid supported JSONC/);
  assert.deepEqual(await snapshot(f.target), before);
});

test("shouldRejectBeforeMutationWhenHostCannotLoadNativeV2Plugin", async (t) => {
  // Given
  const f = await fixture(t, "1.17.15");

  // When
  const result = f.attempt();

  // Then
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /opencode >= 2\.0\.28/);
  await assert.rejects(readdir(f.target), { code: "ENOENT" });
});

test("shouldRestoreTargetWhenNativeRegistrationFailsMidInstall", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  await writeFile(join(f.target, "cli.json"), CLI_CONFIG);
  await writeFile(join(f.target, "foreign.txt"), "preserve");
  const before = await snapshot(f.target);

  // When
  const result = f.attempt({ AGENTS_ORCHESTRATOR_TEST_FAIL_STEP: "after-managed-array" });

  // Then
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /injected installer failure/);
  assert.deepEqual(await snapshot(f.target), before);
});
