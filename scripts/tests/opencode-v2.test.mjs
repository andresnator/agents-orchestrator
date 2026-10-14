import assert from "node:assert/strict";
import test from "node:test";
import { execFileSync, spawnSync } from "node:child_process";
import { link, mkdtemp, mkdir, readFile, readdir, readlink, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("../../", import.meta.url));
const INSTALLER = join(ROOT, "installers/opencode.sh");
const PROFILE = join(ROOT, "scripts/multi-primary-profile.sh");
const EDITOR = join(ROOT, "scripts/jsonc-array.py");
const MODELS_SPEC = "opencode-models-presets@0.4.0";
const FOREIGN_SPEC = "foreign-plugin@1.0.0";
const NATIVE_DEPTH = "experimental.subagent_depth";

async function fixture(t, version = "2.0.28") {
  const root = await mkdtemp(join(tmpdir(), "harness-v2-test-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = join(root, "home");
  const project = join(root, "project");
  await mkdir(home);
  await mkdir(project);
  const target = join(project, ".opencode");
  const binary = join(root, "opencode");
  await writeFile(binary, `#!/bin/sh\nprintf 'opencode v${version}\\n'\n`, { mode: 0o700 });
  const env = { ...process.env, HOME: home, OPENCODE_BIN: binary };
  const invoke = (script, action, args, extraEnv = {}) => spawnSync("bash", [script, action, ...args], {
    cwd: project, env: { ...env, ...extraEnv }, encoding: "utf8",
  });
  return {
    root, home, project, target,
    installer: (action, domain = "meta", extra = [], extraEnv = {}) => invoke(INSTALLER, action, [
      "--domain", domain, "--target", target, ...(action === "install" ? ["--no-install-brew-tools"] : []), ...extra,
    ], extraEnv),
    projectInstall: () => invoke(INSTALLER, "install", ["--domain", "meta", "--project", "--no-install-brew-tools"]),
    profile: (action, extraEnv = {}) => invoke(PROFILE, action, ["--project-root", project, ...(action === "install" ? ["--no-install-brew-tools"] : [])], extraEnv),
    value: (file, path) => execFileSync("python3", [EDITOR, "get-path", file, path], { encoding: "utf8" }).trim(),
    set: async (file, path, value) => writeFile(file, execFileSync("python3", [EDITOR, "set-path", file, path, JSON.stringify(value)], { encoding: "utf8" })),
  };
}

function succeeds(result) {
  assert.equal(result.status, 0, result.stdout + result.stderr);
}

async function snapshot(directory) {
  const result = {};
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    result[entry.name] = entry.isDirectory() ? await snapshot(path)
      : entry.isSymbolicLink() ? { link: await readlink(path) } : await readFile(path, "utf8");
  }
  return result;
}

for (const domain of ["meta", "common"]) {
  test(`shouldRejectV1BeforeMutationWhenInstalling${domain}`, async (t) => {
    // Given
    const f = await fixture(t, "1.17.15");
    // When
    const result = f.installer("install", domain);
    // Then
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /opencode >= 2\.0\.28/);
    await assert.rejects(readdir(f.target), { code: "ENOENT" });
  });
}

test("shouldPreserveForeignEntriesWhenRegisteringNativeModelsPlugin", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  const cli = join(f.target, "cli.json");
  const legacy = '{"plugin":["foreign-legacy"]}';
  await writeFile(cli, JSON.stringify({ plugins: [FOREIGN_SPEC], theme: "custom" }));
  await writeFile(join(f.target, "tui.json"), legacy);
  // When
  succeeds(f.installer("install"));
  const registered = JSON.parse(await readFile(cli, "utf8"));
  succeeds(f.installer("install"));
  const repeated = await readFile(cli, "utf8");
  const status = f.installer("status");
  succeeds(status);
  succeeds(f.installer("uninstall"));
  // Then
  assert.deepEqual(registered, { plugins: [FOREIGN_SPEC, MODELS_SPEC], theme: "custom" });
  assert.deepEqual(JSON.parse(repeated), registered);
  assert.match(status.stdout, /opencode-models-presets.*registered@0\.4\.0/);
  assert.deepEqual(JSON.parse(await readFile(cli, "utf8")), { plugins: [FOREIGN_SPEC], theme: "custom" });
  assert.equal(await readFile(join(f.target, "tui.json"), "utf8"), legacy);
});

test("shouldMigrateOnlyOwnedLegacyModelsEntryWhenNativeConfigExists", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  const cli = join(f.target, "cli.json");
  const legacy = join(f.target, "tui.json");
  const oldSpec = "opencode-models-presets@0.3.5";
  await writeFile(cli, JSON.stringify({ plugins: [FOREIGN_SPEC] }));
  await writeFile(legacy, JSON.stringify({ plugin: ["foreign-legacy", oldSpec] }));
  await writeFile(join(f.target, ".agents-orchestrator-manifest"), `managed-array\t${legacy}\tplugin\t${oldSpec}\n`);
  // When
  succeeds(f.installer("install"));
  // Then
  assert.deepEqual(JSON.parse(await readFile(cli, "utf8")), { plugins: [FOREIGN_SPEC, MODELS_SPEC] });
  assert.deepEqual(JSON.parse(await readFile(legacy, "utf8")), { plugin: ["foreign-legacy"] });
});

test("shouldRejectInvalidNativeCliArrayBeforeMutationWhenInstallingMeta", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  await writeFile(join(f.target, "cli.json"), '{"plugins":false}');
  const before = await snapshot(f.target);
  // When
  const result = f.installer("install");
  // Then
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /not valid supported JSONC/);
  assert.deepEqual(await snapshot(f.target), before);
});

test("shouldRestoreNativeConfigWhenMetaInstallFailsAfterRegistration", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  await writeFile(join(f.target, "cli.json"), JSON.stringify({ plugins: [FOREIGN_SPEC] }));
  const before = await snapshot(f.target);
  // When
  const result = f.installer("install", "meta", [], { AGENTS_ORCHESTRATOR_TEST_FAIL_STEP: "after-managed-array" });
  // Then
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /injected installer failure/);
  assert.deepEqual(await snapshot(f.target), before);
});

test("shouldSkipCliOnlyNpmPluginWhenInstallingProjectWithoutGlobalMutation", async (t) => {
  // Given
  const f = await fixture(t);
  // When
  const result = f.projectInstall();
  succeeds(result);
  // Then
  assert.match(result.stderr, /CLI-only.*global/);
  await assert.rejects(readFile(join(f.target, "cli.json")), { code: "ENOENT" });
  await assert.rejects(readdir(join(f.home, ".config/opencode")), { code: "ENOENT" });
});

test("shouldRemoveGeneratedCliStateWhenFreshProfileIsReinstalledAndRemoved", async (t) => {
  // Given
  const f = await fixture(t);
  // When
  succeeds(f.profile("install"));
  const firstManifest = await readFile(join(f.target, ".multi-primary-profile-manifest"), "utf8");
  succeeds(f.profile("install"));
  const repeatedManifest = await readFile(join(f.target, ".multi-primary-profile-manifest"), "utf8");
  succeeds(f.profile("uninstall"));
  // Then
  await assert.rejects(readdir(f.target), { code: "ENOENT" });
  assert.equal(repeatedManifest, firstManifest);
  assert.match(firstManifest, /cli-config-existed\t0\n/);
  assert.match(firstManifest, /cli-backup-existed\t0\n/);
});

for (const existingCli of [false, true]) {
  test(`shouldPreserveOriginalCliBackupWhenProfileIsRemoved_existingCli_${existingCli}`, async (t) => {
    // Given
    const f = await fixture(t);
    await mkdir(f.target);
    const cli = join(f.target, "cli.json");
    const backup = join(f.target, "cli.json.bak");
    const original = { plugins: [FOREIGN_SPEC], theme: "custom" };
    if (existingCli) await writeFile(cli, JSON.stringify(original));
    const backupContent = "original backup\n";
    await writeFile(backup, backupContent, { mode: 0o640 });
    const alias = join(f.root, "backup-alias");
    await link(backup, alias);
    // When
    succeeds(f.profile("install"));
    succeeds(f.profile("install"));
    succeeds(f.profile("uninstall"));
    // Then
    assert.equal(await readFile(backup, "utf8"), backupContent);
    assert.equal(await readFile(alias, "utf8"), backupContent);
    assert.equal((await stat(backup)).ino, (await stat(alias)).ino);
    assert.equal((await stat(backup)).mode & 0o777, 0o640);
    if (existingCli) assert.deepEqual(JSON.parse(await readFile(cli, "utf8")), original);
    else await assert.rejects(readFile(cli), { code: "ENOENT" });
  });
}

for (const original of [{}, { plugins: [] }]) {
  test(`shouldPreserveExistingEmptyCliWhenProfileIsRemoved_${JSON.stringify(original)}`, async (t) => {
    // Given
    const f = await fixture(t);
    await mkdir(f.target);
    const cli = join(f.target, "cli.json");
    const content = JSON.stringify(original);
    await writeFile(cli, content);
    // When
    succeeds(f.profile("install"));
    succeeds(f.profile("uninstall"));
    // Then
    assert.deepEqual(JSON.parse(await readFile(cli, "utf8")), { plugins: [] });
    assert.equal(await readFile(join(f.target, "cli.json.bak"), "utf8"), content);
  });
}

test("shouldPreserveLaterForeignCliContentAndBackupWhenProfileIsReinstalledAndRemoved", async (t) => {
  // Given
  const f = await fixture(t);
  succeeds(f.profile("install"));
  const cli = join(f.target, "cli.json");
  const backup = join(f.target, "cli.json.bak");
  await f.set(cli, "theme", "custom");
  await writeFile(cli, (await readFile(cli, "utf8")) + "\n// keep foreign comment\n");
  const backupContent = "later foreign backup\n";
  await writeFile(backup, backupContent, { mode: 0o640 });
  // When
  succeeds(f.profile("install"));
  succeeds(f.profile("uninstall"));
  // Then
  assert.equal(f.value(cli, "theme"), '"custom"');
  assert.equal(f.value(cli, "plugins"), "[]");
  assert.match(await readFile(cli, "utf8"), /keep foreign comment/);
  assert.equal(await readFile(backup, "utf8"), backupContent);
  assert.equal((await stat(backup)).mode & 0o777, 0o640);
});

test("shouldPreserveCliStateWhenOldLedgerHasNoOwnershipEvidence", async (t) => {
  // Given
  const f = await fixture(t);
  succeeds(f.profile("install"));
  const manifest = join(f.target, ".multi-primary-profile-manifest");
  const oldLedger = (await readFile(manifest, "utf8")).split("\n")
    .filter((line) => !line.startsWith("cli-config-existed\t") && !line.startsWith("cli-backup-existed\t")).join("\n");
  await writeFile(manifest, oldLedger);
  // When
  succeeds(f.profile("install"));
  succeeds(f.profile("uninstall"));
  // Then
  assert.deepEqual(JSON.parse(await readFile(join(f.target, "cli.json"), "utf8")), { plugins: [] });
  assert.ok((await readFile(join(f.target, "cli.json.bak"), "utf8")).includes("subagent-statusline"));
});

test("shouldRejectSymlinkedCliBackupBeforeMutationWhenInstallingProfile", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  const outside = join(f.root, "foreign-backup");
  await writeFile(outside, "do not change\n");
  await symlink(outside, join(f.target, "cli.json.bak"));
  const before = await snapshot(f.target);
  // When
  const result = f.profile("install");
  // Then
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /symlinked CLI backup/);
  assert.deepEqual(await snapshot(f.target), before);
  assert.equal(await readFile(outside, "utf8"), "do not change\n");
});

for (const failure of ["snapshot", "uninstall"]) {
  test(`shouldPreserveForeignBackupWhenCliOperationFails_${failure}`, async (t) => {
    // Given
    const f = await fixture(t);
    await mkdir(f.target);
    const backup = join(f.target, "cli.json.bak");
    const backupContent = "foreign backup before failure\n";
    await writeFile(backup, backupContent, { mode: 0o640 });
    if (failure === "uninstall") succeeds(f.profile("install"));
    const operation = failure === "snapshot" ? "mv" : "cp";
    const realOperation = execFileSync("bash", ["-c", "command -v " + operation], { encoding: "utf8" }).trim();
    const destination = failure === "snapshot" ? "*/.multi-primary-cli-backup.*" : "*/cli.json.bak";
    await writeFile(join(f.root, operation), `#!/bin/sh
case "$3" in ${destination}) printf 'partial operation' > "$3"; exit 9 ;; esac
exec '${realOperation}' "$@"
`, { mode: 0o700 });
    // When
    const result = f.profile(failure === "snapshot" ? "install" : "uninstall", { PATH: f.root + ":" + process.env.PATH });
    // Then
    assert.notEqual(result.status, 0);
    assert.equal(await readFile(backup, "utf8"), backupContent);
    assert.equal((await stat(backup)).mode & 0o777, 0o640);
    assert.deepEqual((await readdir(f.target)).filter((name) => name.startsWith(".multi-primary-cli-backup.")), []);
  });
}

test("shouldRestoreNativeDepthAndPreserveNeighborsWhenProfileIsReinstalledAndRemoved", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  const file = join(f.target, "opencode.jsonc");
  await writeFile(file, '{"default_agent":"custom", "subagent_depth":9, "experimental":{"subagent_depth":3, // keep\n "other":true}}');
  // When
  succeeds(f.profile("install"));
  assert.equal(f.value(file, NATIVE_DEPTH), "1");
  const firstManifest = await readFile(join(f.target, ".multi-primary-profile-manifest"), "utf8");
  succeeds(f.profile("install"));
  assert.equal(await readFile(join(f.target, ".multi-primary-profile-manifest"), "utf8"), firstManifest);
  const status = f.profile("status");
  succeeds(status);
  succeeds(f.profile("uninstall"));
  // Then
  assert.match(status.stdout, /experimental\.subagent_depth: 1/);
  assert.equal(f.value(file, NATIVE_DEPTH), "3");
  assert.equal(f.value(file, "default_agent"), '"custom"');
  assert.equal(f.value(file, "subagent_depth"), "9");
  assert.equal(f.value(file, "experimental.other"), "true");
  assert.match(await readFile(file, "utf8"), /\/\/ keep/);
});

for (const experimental of [null, {}]) {
  test(`shouldRestoreParentPresenceWhenProfileCreatesDepth_${experimental === null ? "absent" : "empty"}`, async (t) => {
    // Given
    const f = await fixture(t);
    await mkdir(f.target);
    const file = join(f.target, "opencode.jsonc");
    const original = { default_agent: "custom", plugin: [FOREIGN_SPEC], ...(experimental === null ? {} : { experimental }) };
    await writeFile(file, JSON.stringify(original));
    // When
    succeeds(f.profile("install"));
    succeeds(f.profile("uninstall"));
    // Then
    assert.deepEqual(JSON.parse(await readFile(file, "utf8")), original);
  });
}

test("shouldRejectInvalidNativeParentBeforeMutationWhenInstallingProfile", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  await writeFile(join(f.target, "opencode.jsonc"), '{"experimental":false}');
  const before = await snapshot(f.target);
  // When
  const result = f.profile("install");
  // Then
  assert.notEqual(result.status, 0);
  assert.deepEqual(await snapshot(f.target), before);
});

for (const version of ["2.0.28", "1.17.15"]) {
  test(`shouldUseVersionSafeReloadWhenInstallingMarkdown_${version}`, async (t) => {
    // Given
    const f = await fixture(t, version);
    const calls = join(f.root, "reload-calls");
    await writeFile(join(f.root, "curl"), `#!/bin/sh
printf '%s\\n' "$*" >> "$RELOAD_CALL_LOG"
case "$*" in *health*) printf '{"healthy":true}' ;; *) printf true ;; esac
`, { mode: 0o700 });
    // When
    const result = f.installer("install", "docs", ["--reload"], {
      PATH: f.root + ":" + process.env.PATH,
      OPENCODE_RELOAD_URLS: "http://127.0.0.1:1",
      RELOAD_CALL_LOG: calls,
    });
    succeeds(result);
    // Then
    if (version.startsWith("2.")) {
      await assert.rejects(readFile(calls), { code: "ENOENT" });
      assert.match(result.stderr, /V2.*restart/i);
    } else {
      assert.match(await readFile(calls, "utf8"), /global\/dispose/);
      assert.match(result.stdout, /disposed instances/);
    }
  });
}

for (const version of ["2.0.28", "v2.0.28", "opencode v2.0.28", "2.0.28+build.1"]) {
  test(`shouldAcceptStableSupportedVersionWhenOutputIs_${version}`, async (t) => {
    // Given
    const f = await fixture(t);
    await writeFile(join(f.root, "opencode"), `#!/bin/sh\nprintf '%s\\n' '${version}'\n`, { mode: 0o700 });
    // When
    const result = f.installer("install", "meta", ["--dry-run"]);
    // Then
    succeeds(result);
    assert.match(result.stdout, /cli\.json\.plugins = opencode-models-presets@0\.4\.0/);
    await assert.rejects(readdir(f.target), { code: "ENOENT" });
  });
}

for (const version of ["2.0.27", "2.0.28-beta.1", "2.0.29-rc.1", "invalid"]) {
  test(`shouldRejectUnsupportedVersionBeforeMutationWhenVersionIs_${version}`, async (t) => {
    // Given
    const f = await fixture(t, version);
    // When
    const result = f.installer("install");
    // Then
    assert.notEqual(result.status, 0);
    await assert.rejects(readdir(f.target), { code: "ENOENT" });
  });
}

test("shouldRejectFutureMajorBeforeMutationWhenInstallingPinnedPlugins", async (t) => {
  // Given
  const f = await fixture(t, "3.0.0");
  // When
  const result = f.installer("install");
  // Then
  assert.notEqual(result.status, 0);
  await assert.rejects(readdir(f.target), { code: "ENOENT" });
});

test("shouldRestoreLegacyRootDepthWhenMigratingV1ProfileLedger", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  const file = join(f.target, "opencode.json");
  const original = { default_agent: "custom", plugin: [FOREIGN_SPEC], subagent_depth: 9, experimental: { subagent_depth: 3 } };
  await writeFile(file, JSON.stringify(original));
  succeeds(f.profile("install"));
  await f.set(file, "subagent_depth", 1);
  await f.set(file, NATIVE_DEPTH, 3);
  const manifest = join(f.target, ".multi-primary-profile-manifest");
  await writeFile(manifest, (await readFile(manifest, "utf8"))
    .replace("multi-primary-profile/v2", "multi-primary-profile/v1")
    .replace("previous-subagent-depth-json\t3", "previous-subagent-depth-json\t9")
    .replace(/^previous-experimental-state\t.*\n/m, ""));
  // When
  const legacyStatus = f.profile("status");
  succeeds(f.profile("install"));
  const installed = { root: f.value(file, "subagent_depth"), native: f.value(file, NATIVE_DEPTH) };
  succeeds(f.profile("uninstall"));
  // Then
  succeeds(legacyStatus);
  assert.match(legacyStatus.stdout, /migration required/);
  assert.deepEqual(installed, { root: "9", native: "1" });
  assert.deepEqual(JSON.parse(await readFile(file, "utf8")), original);
});

test("shouldRestoreBothConfigsWhenProfileMigratesToPreferredJsonc", async (t) => {
  // Given
  const f = await fixture(t);
  await mkdir(f.target);
  const oldFile = join(f.target, "opencode.json");
  const newFile = join(f.target, "opencode.jsonc");
  const oldConfig = { default_agent: "old", plugin: [FOREIGN_SPEC], experimental: { subagent_depth: 3 } };
  const newConfig = { default_agent: "new", plugin: [FOREIGN_SPEC], experimental: { subagent_depth: 6, other: true } };
  await writeFile(oldFile, JSON.stringify(oldConfig));
  succeeds(f.profile("install"));
  await writeFile(newFile, JSON.stringify(newConfig));
  // When
  succeeds(f.profile("install"));
  const installedDepth = f.value(newFile, NATIVE_DEPTH);
  succeeds(f.profile("uninstall"));
  // Then
  assert.equal(installedDepth, "1");
  assert.deepEqual(JSON.parse(await readFile(oldFile, "utf8")), oldConfig);
  assert.deepEqual(JSON.parse(await readFile(newFile, "utf8")), newConfig);
});
