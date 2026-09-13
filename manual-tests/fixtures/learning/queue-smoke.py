#!/usr/bin/env python3
"""Exercise the documented queue with five fake processes in four owned Herdr panes.

No model or coding agent is launched. This checks scheduling/archive/timeout
mechanics, not agent detection, agent-session termination, or Learning behavior.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time

POLL_SECONDS = 0.1
REVIEW_SECONDS = 2
TIMEOUT_SECONDS = 5
JOBS = [('first', 0.5, 'PASS'), ('slow', 3.5, 'PASS'), ('blocked', 3, 'BLOCKED'), ('timeout', 20, 'PASS'), ('fifth', 0.5, 'PASS')]


def command(args):
    return subprocess.check_output(args, text=True).strip()


def herdr(*args):
    output = command(['herdr', *args])
    return json.loads(output) if output.startswith('{') else output


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def worker(root, duration, status):
    save(root / 'process.json', dict(pid=os.getpid(), started=time.time()))
    start = time.monotonic()
    while time.monotonic() - start < duration:
        if root.name != 'timeout':
            (root / 'progress').write_text(str(time.time()))
        time.sleep(POLL_SECONDS)
    save(root / 'result.json', dict(status=status, layer='simulated-process', end=time.time()))


def run(root):
    if os.environ.get('HERDR_ENV') != '1':
        raise RuntimeError('Must run inside Herdr')
    root.mkdir(parents=True, exist_ok=False)
    sha = command(['git', 'rev-parse', 'HEAD'])
    repository = Path(command(['git', 'rev-parse', '--show-toplevel']))
    script = Path(__file__).resolve()
    pending = list(JOBS)
    active, panes, records = {}, [], []
    worktrees = {}
    try:
        for _ in range(4):
            result = herdr('pane', 'split', '--current', '--direction', 'down', '--cwd', str(repository), '--no-focus')
            panes.append(result['result']['pane']['pane_id'])
        while pending or active:
            for pane in panes:
                if pane in active or not pending:
                    continue
                name, duration, status = pending.pop(0)
                envroot = root / name
                envroot.mkdir()
                worktree = root / (name + '-worktree')
                command(['git', 'worktree', 'add', '--detach', str(worktree), sha])
                worktrees[name] = worktree
                for folder in ('config', 'data', 'state', 'cache'):
                    (envroot / folder).mkdir()
                env = {f'XDG_{key.upper()}_HOME': str(envroot / key) for key in ('config', 'data', 'state', 'cache')}
                env['OPENCODE_CONFIG_DIR'] = str(envroot / 'config')
                invocation = ['env', *[key + '=' + value for key, value in env.items()], sys.executable, str(script), '--worker', str(envroot), str(duration), status]
                herdr('pane', 'run', pane, 'cd ' + shlex.quote(str(worktree)) + ' && ' + shlex.join(invocation))
                started = time.monotonic()
                active[pane] = dict(name=name, root=envroot, started=started, progress=started, reviewed=False)
                records.append(dict(event='start', job=name, pane=pane, at=started, worktree=str(worktree), sha=sha))
            for pane, job in list(active.items()):
                now = time.monotonic()
                progress = job['root'] / 'progress'
                if progress.exists():
                    stamp = progress.stat().st_mtime_ns
                    if stamp != job.get('stamp'):
                        job.update(stamp=stamp, progress=now)
                if now - job['progress'] >= REVIEW_SECONDS and not job['reviewed']:
                    records.append(dict(event='review', job=job['name'], at=now))
                    job['reviewed'] = True
                result = job['root'] / 'result.json'
                timed_out = now - job['started'] >= TIMEOUT_SECONDS
                if not result.exists() and not timed_out:
                    continue
                process = json.loads((job['root'] / 'process.json').read_text())
                if timed_out and not result.exists():
                    os.kill(process['pid'], signal.SIGTERM)
                    save(result, dict(status='BLOCKED', reason='time exhausted', layer='simulated-process'))
                # A result is not proof the process has exited; wait for the owned PID.
                for _ in range(50):
                    try:
                        os.kill(process['pid'], 0)
                    except ProcessLookupError:
                        break
                    time.sleep(POLL_SECONDS)
                else:
                    raise RuntimeError('Worker did not exit: ' + job['name'])
                outcome = json.loads(result.read_text())
                archive = root / 'evidence' / job['name']
                archive.mkdir(parents=True)
                for source in job['root'].glob('*'):
                    if source.is_file():
                        target = archive / source.name
                        target.write_bytes(source.read_bytes())
                        if hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
                            raise RuntimeError('Archive mismatch')
                records.append(dict(event='finish', job=job['name'], pane=pane, at=time.monotonic(), **outcome))
                if outcome['status'] == 'PASS':
                    command(['git', 'worktree', 'remove', str(worktrees[job['name']])])
                    __import__('shutil').rmtree(job['root'])
                del active[pane]
            time.sleep(POLL_SECONDS)
        starts = {r['job']: r for r in records if r['event'] == 'start'}
        finishes = {r['job']: r for r in records if r['event'] == 'finish'}
        assert starts['fifth']['pane'] == starts['first']['pane']
        assert finishes['first']['at'] < starts['fifth']['at'] < min(finishes[name]['at'] for name in ('slow', 'blocked', 'timeout'))
        assert any(r['event'] == 'review' and r['job'] == 'timeout' for r in records)
        assert finishes['timeout']['status'] == 'BLOCKED'
        assert finishes['blocked']['status'] == 'BLOCKED'
        assert all((root / 'evidence' / name / 'result.json').is_file() for name, _, _ in JOBS)
        assert all(worktrees[name].exists() == (name in ('blocked', 'timeout')) for name, _, _ in JOBS)
        save(root / 'queue.json', dict(status='PASS', layer='simulated-process', records=records))
        print(root / 'queue.json')
    finally:
        for job in active.values():
            path = job['root'] / 'process.json'
            if path.exists():
                try:
                    os.kill(json.loads(path.read_text())['pid'], signal.SIGTERM)
                except ProcessLookupError:
                    pass
        save(root / 'events.json', records)
        for pane in panes:
            herdr('pane', 'close', pane)


if __name__ == '__main__':
    if sys.argv[1:2] == ['--worker']:
        worker(Path(sys.argv[2]), float(sys.argv[3]), sys.argv[4])
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('destination', type=Path)
        run(parser.parse_args().destination.resolve())
