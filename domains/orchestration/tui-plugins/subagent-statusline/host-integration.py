"""Opt-in real CLI check: python3 host-integration.py --binary /path/to/opencode.

Requires OpenCode 2.0.28 and a POSIX PTY. Receipts are kept in a fresh private
directory, never in the checkout. No credentials or external providers are used.
"""
import argparse
import fcntl
import http.server
import json
import os
import pathlib
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
import threading
import time

WIDTH, HEIGHT = 160, 40
TIMEOUT = 45
PLUGIN_ID = "orchestration.subagent-statusline"
DRIVER = r'''
import { Plugin } from "@opencode/plugin/tui"
import { appendFileSync } from "node:fs"
export default Plugin.define({ id: "fixture.statusline-driver", async setup(ctx) {
 const log = value => appendFileSync(RECEIPT, JSON.stringify(value)+"\n")
 const stop = ctx.data.listen(event => log({kind:"event", event}))
 const create = async (title, parentID) => {
   const result = await ctx.client.session.create({title, ...(parentID ? {parentID} : {location:ctx.location})})
   log({kind:"created", title, result}); return result
 }
 let step = 0, live
 try {
   const parent = await create("fixture-parent")
   const seed = await create("fixture-hydrated", parent.id)
   await create("fixture-grandchild", seed.id)
   const foreign = await create("fixture-foreign")
   await create("fixture-foreign-child", foreign.id)
   ctx.ui.router.navigate({type:"session", sessionID:parent.id})
   ctx.keymap.layer(() => ({mode:"global", priority:100, bindings:["fixture.advance"], commands:[{id:"fixture.advance", bind:"ctrl+g", async run() {
     try {
       if (step === 0) live = await create("fixture-live", parent.id)
       if (step === 1) await ctx.client.session.prompt({sessionID:live.id, text:"LOCAL FIXTURE ONLY"})
       if (step === 2) await ctx.client.session.remove({sessionID:live.id})
       if (step === 3) await ctx.client.session.remove({sessionID:seed.id})
       log({kind:"step", step:step++})
     } catch(error) { log({kind:"error", error:String(error)}) }
   }}]}))
   log({kind:"ready", version:ctx.app.version, parentID:parent.id})
 } catch(error) { log({kind:"error", error:String(error)}) }
 return () => { stop(); log({kind:"cleanup"}) }
}})
'''
GUARD = r'''
export default {id:"fixture.local-only", async setup(ctx) {
 await ctx.session.hook("http.request", event => {
   if (!event.request.url.startsWith(BASE)) throw new Error("external_provider_blocked")
 })
 await ctx.session.hook("title", event => { event.result = "fixture-title" })
}}
'''


class LocalProvider(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        with (self.server.root / "provider.jsonl").open("a") as receipt:
            receipt.write(json.dumps({"path": self.path, "body": body}) + "\n")
        # Hold a genuine native execution long enough to assert its running UI.
        time.sleep(6)
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for delta, finish in [({"role": "assistant", "content": "LOCAL FIXTURE COMPLETE"}, None), ({}, "stop")]:
            chunk = {"id": "fixture", "object": "chat.completion.chunk", "created": 1,
                     "model": "fixture", "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}
            self.wfile.write(("data: " + json.dumps(chunk) + "\n\n").encode())
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()


class Screen:
    def __init__(self):
        self.rows = [[" "] * WIDTH for _ in range(HEIGHT)]
        self.row = self.col = 0

    def feed(self, raw):
        tokens = re.findall(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]|\x1b.|[^\x1b]", raw.decode(errors="replace"))
        for token in tokens:
            if token.startswith("\x1b["):
                try:
                    nums = [int(x) if x else 0 for x in token[2:-1].split(";")]
                except ValueError:
                    continue
                cmd = token[-1]
                if cmd in "Hf":
                    self.row = max(0, (nums[0] or 1) - 1)
                    self.col = max(0, ((nums[1] if len(nums) > 1 else 1) or 1) - 1)
                elif cmd == "J" and nums[0] in (2, 3):
                    self.rows = [[" "] * WIDTH for _ in range(HEIGHT)]
                elif cmd == "K" and self.row < HEIGHT:
                    start = 0 if nums[0] in (1, 2) else self.col
                    end = WIDTH if nums[0] in (0, 2) else self.col + 1
                    self.rows[self.row][start:end] = [" "] * (end - start)
            elif token.startswith("\x1b"):
                continue
            elif token == "\r":
                self.col = 0
            elif token == "\n":
                self.row = min(HEIGHT - 1, self.row + 1)
            elif token.isprintable():
                if self.row < HEIGHT and self.col < WIDTH:
                    self.rows[self.row][self.col] = token
                self.col += 1

    def text(self):
        return "\n".join("".join(row) for row in self.rows)


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--binary", default=shutil.which("opencode"))
    args.add_argument("--temp-root", default=tempfile.gettempdir())
    options = args.parse_args()
    if not options.binary:
        raise RuntimeError("Pass --binary for the native OpenCode 2.0.28 executable")
    root = pathlib.Path(tempfile.mkdtemp(prefix="statusline-live-", dir=options.temp_root)).resolve()
    os.chmod(root, 0o700)
    repository = pathlib.Path(__file__).resolve().parents[4]
    env = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TERM": "xterm-256color",
           "TMPDIR": str(root), "OPENCODE_CONFIG_PROJECT_DISABLE": "true",
           "OPENCODE_DISABLE_MODELS_FETCH": "true", "OPENCODE_DISABLE_AUTOUPDATE": "true",
           "OPENCODE_LOG_LEVEL": "DEBUG"}
    for key, folder in [("HOME", "home"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                        ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state"), ("XDG_RUNTIME_DIR", "runtime")]:
        (root / folder).mkdir()
        env[key] = str(root / folder)
    project = root / "project"
    project.mkdir()
    config = root / "config/opencode"
    config.mkdir()
    env["OPENCODE_CONFIG_DIR"] = str(config)
    version = subprocess.check_output([options.binary, "--version"], env=env, cwd=project, timeout=TIMEOUT).decode().strip()
    assert version in ("2.0.28", "opencode v2.0.28"), version
    subprocess.run(["/bin/bash", str(repository / "installers/opencode.sh"), "install",
                    "--domain", "orchestration", "--target", str(config), "--no-install-brew-tools"],
                   env={**env, "OPENCODE_BIN": options.binary}, cwd=project,
                   check=True, capture_output=True, timeout=TIMEOUT)
    installed_plugins = json.loads((config / "cli.json").read_text())["plugins"]
    assert installed_plugins == ["./plugins/subagent-statusline.tsx"], installed_plugins
    provider = http.server.ThreadingHTTPServer(("127.0.0.1", 0), LocalProvider)
    provider.root = root
    base = f"http://127.0.0.1:{provider.server_port}/v1"
    threading.Thread(target=provider.serve_forever, daemon=True).start()
    guard = root / "guard.ts"
    guard.write_text(GUARD.replace("BASE", json.dumps(base)))
    driver = root / "driver"
    driver.mkdir()
    (driver / "package.json").write_text(json.dumps({"name": "fixture-statusline", "type": "module", "exports": {"./tui": "./tui.ts"}}))
    receipts = root / "native.jsonl"
    (driver / "tui.ts").write_text(DRIVER.replace("RECEIPT", json.dumps(str(receipts))))
    (config / "opencode.json").write_text(json.dumps({"plugins": [str(guard)], "model": "fixture/fixture",
        "providers": {"fixture": {"package": "@opencode/ai/providers/openai-compatible", "settings": {"baseURL": base},
        "models": {"fixture": {"modelID": "fixture", "capabilities": {"tools": True, "input": ["text"], "output": ["text"]},
        "limit": {"context": 32768, "output": 8192}}}}}}))
    def configure(enabled):
        entries = [*installed_plugins, str(driver)]
        if not enabled:
            entries.append("-" + PLUGIN_ID)
        (config / "cli.json").write_text(json.dumps({"plugins": entries}))
    configure(True)
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", HEIGHT, WIDTH, 0, 0))
    process = subprocess.Popen([options.binary, "--standalone", str(project)], env=env, cwd=project,
                               stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
    os.close(slave)
    screen = Screen()
    checks = {}
    passed = False
    def pump():
        if select.select([master], [], [], .1)[0]:
            raw = os.read(master, 65536)
            with (root / "terminal.raw").open("ab") as output:
                output.write(raw)
            screen.feed(raw)
            for query, reply in [(b"\x1b[6n", b"\x1b[1;1R"), (b"\x1b[c", b"\x1b[?1;2c"),
                                 (b"\x1b[>c", b"\x1b[>0;0;0c"), (b"\x1b]11;?", b"\x1b]11;rgb:0000/0000/0000\x1b\\")]:
                if query in raw:
                    os.write(master, reply)
    def expect(name, label, settle=0):
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline:
            pump()
            text = screen.text()
            actual = re.findall(r"Subagents: \d+ \w+(?: · \d+ \w+)*", text)
            if (not actual if label is None else len(actual) == 1 and actual[0].strip() == label):
                if settle:
                    end = time.monotonic() + settle
                    while time.monotonic() < end:
                        pump()
                    settle = 0
                    continue
                (root / (name + "-screen.txt")).write_text(text)
                checks[name] = label
                return
            if receipts.exists() and '"kind":"error"' in receipts.read_text():
                raise AssertionError("Native driver failed; inspect " + str(receipts))
        raise AssertionError(f"{name}: expected {label!r}; receipts {root}; screen {screen.text()!r}")
    try:
        # Given: the real CLI cache hydrates only the selected parent's child.
        expect("hydrated", "Subagents: 1 idle")
        # When: native client writes emit into this same host, not another server.
        os.write(master, b"\x07")
        expect("created", "Subagents: 2 idle")
        os.write(master, b"\x07")
        expect("running", "Subagents: 1 running · 1 idle")
        expect("succeeded", "Subagents: 1 succeeded · 1 idle")
        configure(False)
        expect("disabled", None, settle=2)
        configure(True)
        expect("reloaded", "Subagents: 1 succeeded · 1 idle", settle=2)
        os.write(master, b"\x07")
        expect("removed-live", "Subagents: 1 idle")
        os.write(master, b"\x07")
        expect("removed-all", None, settle=2)
        # Then: no contribution remains; native events and UI agree.
        native = [json.loads(line) for line in receipts.read_text().splitlines()]
        live_id = next(item["result"]["id"] for item in native
                       if item["kind"] == "created" and item["title"] == "fixture-live")
        events = [item["event"]["details"] for item in native if item["kind"] == "event"]
        for event in ("session.created", "session.deleted", "session.execution.started", "session.execution.succeeded"):
            assert any(item["type"] == event and item["data"]["sessionID"] == live_id for item in events), event
        assert (root / "provider.jsonl").exists()
        os.write(master, b"\x03")
        deadline = time.monotonic() + 5
        while process.poll() is None and time.monotonic() < deadline:
            try:
                pump()
            except OSError:
                break
        process.wait(timeout=10)
        assert process.returncode == 0, process.returncode
        passed = True
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        os.close(master)
        provider.shutdown()
        provider.server_close()
        ps = subprocess.check_output(["/bin/ps", "-axo", "pid,ppid,command"]).decode()
        remaining = [line for line in ps.splitlines() if str(root) in line and options.binary in line]
        (root / "result.json").write_text(json.dumps({"passed": passed and not remaining,
                                                      "version": version, "checks": checks, "exit": process.returncode,
                                                      "remaining": remaining}, indent=2))
        print(root, flush=True)
        assert not remaining, remaining


if __name__ == "__main__":
    main()
