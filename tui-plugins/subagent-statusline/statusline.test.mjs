import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { childStatusLabel, statuslineDefinition } from "./statusline.mjs";

const PARENT = "ses_parent";
const FOREIGN = "ses_foreign";
const child = (id, parentID = PARENT, outcome) => ({ id, parentID, outcome });

function fixture(initial = []) {
  let sessions = initial;
  const states = new Map();
  const effects = new Set();
  const syncs = [];
  const slots = new Set();
  const data = {
    list: () => sessions,
    status: (id) => states.get(id) ?? "idle",
    sync: async (...args) => { syncs.push(args); },
  };
  const definition = statuslineDefinition({
    createEffect(effect) { effects.add(effect); effect(); },
    untrack: (callback) => callback(),
    renderStatus: (_context, label) => ({ text: label }),
  });
  const context = {
    data: { session: data },
    ui: { slot(slot) {
      slots.add(slot);
      return () => { slots.delete(slot); effects.clear(); };
    } },
  };
  return {
    data, states, effects, syncs, slots, definition, context,
    replace: (value) => { sessions = value; },
    flush: () => { for (const effect of effects) effect(); },
  };
}

test("shouldExposeCliOnlyNativeEntrypointWhenLoadedFromDirectory", async () => {
  // Given
  const directory = new URL("./", import.meta.url);
  // When
  const pkg = JSON.parse(await readFile(new URL("package.json", directory), "utf8"));
  const source = await readFile(new URL(pkg.exports["./tui"], directory), "utf8");
  // Then
  assert.deepEqual(pkg.exports, { "./tui": "./tui.tsx" });
  assert.equal(pkg.dependencies, undefined);
  assert.equal(pkg.peerDependencies, undefined);
  assert.match(source, /import \{ Plugin \} from "@opencode\/plugin\/tui"/);
  assert.match(source, /export default Plugin.define\(statuslineDefinition/);
  assert.match(source, /<Show when=\{label\(\)\}>/);
});

test("shouldCountOnlyDirectChildrenWhenOtherBranchesAndCyclesExist", () => {
  // Given
  const f = fixture([
    child(PARENT, PARENT), child("a"), child("b", "a"),
    child("c", FOREIGN), child("d", "missing"), { id: "e" },
  ]);
  // When
  const label = childStatusLabel(f.data, PARENT);
  // Then
  assert.equal(label, "Subagents: 1 idle");
  assert.equal(childStatusLabel(f.data, undefined), "");
  assert.equal(childStatusLabel(f.data, "empty"), "");
});

test("shouldReadHostStatesAndOutcomesWhenChildrenChange", () => {
  // Given
  const f = fixture([
    child("a", PARENT, "succeeded"), child("b", PARENT, "failed"),
    child("c", PARENT, "interrupted"), child("d"), child("e"),
    child("f", PARENT, "succeeded"),
  ]);
  f.states.set("a", "running");
  f.states.set("e", "unavailable");
  // When
  const running = childStatusLabel(f.data, PARENT);
  f.states.set("a", "idle");
  const idle = childStatusLabel(f.data, PARENT);
  // Then
  assert.deepEqual({ running, idle }, {
    running: "Subagents: 1 running · 1 succeeded · 1 failed · 1 interrupted · 1 idle · 1 unknown",
    idle: "Subagents: 2 succeeded · 1 failed · 1 interrupted · 1 idle · 1 unknown",
  });
});

test("shouldHydrateAndRenderCurrentSessionWhenNativeSlotMountsAndSwitches", async () => {
  // Given
  const f = fixture([child("a"), child("b", FOREIGN, "failed")]);
  const cleanup = f.definition.setup(f.context);
  const slot = [...f.slots][0];
  const props = { sessionID: PARENT };
  // When
  const view = slot.render(props);
  const before = view.text();
  f.states.set("a", "running");
  const running = view.text();
  props.sessionID = FOREIGN;
  f.flush();
  const foreign = view.text();
  f.replace([child("a")]);
  const deleted = view.text();
  cleanup();
  // Then
  assert.equal(f.definition.id, "orchestration.subagent-statusline");
  assert.equal(slot.append, "prompt.footer.status");
  assert.deepEqual(Object.keys(slot).sort(), ["append", "render"]);
  assert.deepEqual({ before, running, foreign, deleted }, {
    before: "Subagents: 1 idle", running: "Subagents: 1 running",
    foreign: "Subagents: 1 failed", deleted: "",
  });
  assert.deepEqual(f.syncs, [[PARENT, { children: true }], [FOREIGN, { children: true }]]);
});

test("shouldDisposeExactlyOnceWhenReloadedWithOutstandingHydration", async () => {
  // Given
  const f = fixture([child("a")]);
  let reject;
  f.data.sync = () => new Promise((_resolve, fail) => { reject = fail; });
  const firstCleanup = f.definition.setup(f.context);
  [...f.slots][0].render({ sessionID: PARENT });
  // When
  firstCleanup();
  firstCleanup();
  reject(new Error("fixture unavailable"));
  await new Promise((resolve) => setImmediate(resolve));
  const secondCleanup = f.definition.setup(f.context);
  const reloaded = { slots: f.slots.size, effects: f.effects.size };
  [...f.slots][0].render({ sessionID: undefined });
  secondCleanup();
  // Then
  assert.deepEqual(reloaded, { slots: 1, effects: 0 });
  assert.deepEqual({ slots: f.slots.size, effects: f.effects.size }, { slots: 0, effects: 0 });
});

test("shouldUseFreshCachedHierarchyWhenSessionIsReopened", async () => {
  // Given
  const f = fixture();
  f.data.sync = async (...args) => {
    f.syncs.push(args);
    f.replace([child("hydrated", PARENT, "succeeded"), child("foreign", FOREIGN)]);
  };
  const cleanup = f.definition.setup(f.context);
  // When
  const view = [...f.slots][0].render({ sessionID: PARENT });
  await Promise.resolve();
  const label = view.text();
  cleanup();
  // Then
  assert.equal(label, "Subagents: 1 succeeded");
  assert.deepEqual(f.syncs, [[PARENT, { children: true }]]);
});

test("shouldNeverShowPreviousChildrenWhenHydrationFinishesAfterSessionSwitch", async () => {
  // Given
  const f = fixture();
  let finish;
  f.data.sync = () => new Promise((resolve) => { finish = resolve; });
  const cleanup = f.definition.setup(f.context);
  const props = { sessionID: PARENT };
  const view = [...f.slots][0].render(props);
  // When
  props.sessionID = FOREIGN;
  f.replace([child("late", PARENT, "succeeded")]);
  finish();
  await Promise.resolve();
  const label = view.text();
  cleanup();
  // Then
  assert.equal(label, "");
});
