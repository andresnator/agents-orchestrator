// Tests the object-member actions of jsonc-array.py that make-scripts/mcp.sh uses.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const script = new URL("./jsonc-array.py", import.meta.url).pathname;

function run(text, ...args) {
  const file = join(mkdtempSync(join(tmpdir(), "jsonc-member-")), "opencode.jsonc");
  if (text !== null) writeFileSync(file, text);
  const result = spawnSync("python3", [script, args[0], file, ...args.slice(1)], { encoding: "utf8" });
  return { status: result.status, out: result.stdout, err: result.stderr };
}

const strip = (text) => JSON.parse(text.replace(/\s\/\/.*$/gm, ""));
const entry = '{"type":"remote","url":"https://example.test/mcp"}';

test("set-member creates the object and keeps comments", () => {
  const { status, out } = run('{\n  // keep me\n  "theme": "x" // tail\n}\n', "set-member", "mcp", "ctx", entry);
  assert.equal(status, 0);
  assert.match(out, /\/\/ keep me/);
  assert.match(out, /"theme": "x", \/\/ tail/);
  assert.deepEqual(strip(out).mcp.ctx, JSON.parse(entry));
});

test("a missing or empty file counts as an empty object", () => {
  for (const text of [null, "", "  \n"]) {
    const { status, out } = run(text, "set-member", "mcp", "ctx", entry);
    assert.equal(status, 0);
    assert.deepEqual(JSON.parse(out), { mcp: { ctx: JSON.parse(entry) } });
  }
  assert.equal(run("", "get-member", "mcp", "ctx").status, 1);
});

test("set-member adds next to other servers and is idempotent", () => {
  const text = '{\n  "mcp": {\n    "other": { "type": "local", "command": ["x"] } // theirs\n  }\n}\n';
  const first = run(text, "set-member", "mcp", "ctx", entry);
  assert.equal(first.status, 0);
  assert.match(first.out, /\/\/ theirs/);
  assert.deepEqual(Object.keys(strip(first.out).mcp), ["other", "ctx"]);
  const again = run(first.out, "set-member", "mcp", "ctx", entry);
  assert.equal(again.status, 3);
  assert.equal(again.out, first.out);
});

test("set-member writes at a dotted path", () => {
  const text = '{\n  "mcp": {\n    "servers": {\n      "keep": 1\n    }\n  }\n}\n';
  const { status, out } = run(text, "set-member", "mcp.servers", "ctx", entry);
  assert.equal(status, 0);
  assert.deepEqual(JSON.parse(out).mcp.servers, { keep: 1, ctx: JSON.parse(entry) });
  assert.match(out, /\n {6}"ctx": \{\n {8}"type"/);
  assert.equal(run(out, "get-member", "mcp.servers", "ctx").status, 0);
  assert.equal(run(out, "get-member", "mcp", "ctx").status, 1);
});

test("set-member follows the file's indentation", () => {
  const four = run('{\n    "a": 1\n}\n', "set-member", "mcp", "ctx", '{"x":1}');
  assert.equal(four.out, '{\n    "a": 1,\n    "mcp": {\n        "ctx": {\n            "x": 1\n        }\n    }\n}\n');
  const tabs = run('{\n\t"mcp": {\n\t\t"a": 1\n\t}\n}\n', "set-member", "mcp", "ctx", '{"x":1}');
  assert.equal(tabs.out, '{\n\t"mcp": {\n\t\t"a": 1,\n\t\t"ctx": {\n\t\t\t"x": 1\n\t\t}\n\t}\n}\n');
});

test("set-member replaces a different value in place", () => {
  const { status, out } = run('{"mcp": {"ctx": {"type": "local"}}}', "set-member", "mcp", "ctx", entry);
  assert.equal(status, 0);
  assert.deepEqual(JSON.parse(out).mcp.ctx, JSON.parse(entry));
});

test("get-member prints canonical JSON or exits 1 when absent", () => {
  const got = run('{"mcp": {"ctx": {"url": "u", "type": "remote"}}}', "get-member", "mcp", "ctx");
  assert.equal(got.status, 0);
  assert.equal(got.out.trim(), '{"type":"remote","url":"u"}');
  assert.equal(run('{"mcp": {}}', "get-member", "mcp", "ctx").status, 1);
  assert.equal(run("{}", "get-member", "mcp.servers", "ctx").status, 1);
});

test("a parse error or a non-object path exits 2", () => {
  assert.equal(run('{"mcp": {', "get-member", "mcp", "ctx").status, 2);
  assert.equal(run('{"mcp": {', "remove-member", "mcp", "ctx").status, 2);
  const { status, err } = run('{"mcp": []}', "set-member", "mcp", "ctx", entry);
  assert.equal(status, 2);
  assert.match(err, /must be an object/);
});

test("remove-member removes only that member and leaves no blank line", () => {
  const text = '{\n  "mcp": {\n    // note\n    "a": { "type": "local" },\n    "b": 1\n  }\n}\n';
  const first = run(text, "remove-member", "mcp", "b");
  assert.equal(first.status, 0);
  assert.equal(first.out, '{\n  "mcp": {\n    // note\n    "a": { "type": "local" }\n  }\n}\n');
  assert.equal(run(text, "remove-member", "mcp", "zzz").status, 3);
});

test("remove-member drops the objects it empties, unless a comment is inside", () => {
  const nested = run('{\n  "a": 1,\n  "mcp": {\n    "servers": {\n      "b": 2\n    }\n  }\n}\n', "remove-member", "mcp.servers", "b");
  assert.equal(nested.out, '{\n  "a": 1\n}\n');
  const kept = run('{\n  "mcp": {\n    // mine\n    "b": 2\n  }\n}\n', "remove-member", "mcp", "b");
  assert.equal(kept.out, '{\n  "mcp": {\n    // mine\n  }\n}\n');
});
