#!/usr/bin/env python3
"""Inject one documented fault into a prepared, disposable variant only."""
import argparse
import datetime
import json
from pathlib import Path
import subprocess
import sys
import uuid


def inject(variant, fault):
    variant = variant.resolve()
    manifest = json.loads((variant.parent / 'manifest.json').read_text())
    if variant.name not in manifest['variants']:
        raise ValueError('Not a prepared variant')
    if fault == 'upgrade':
        target = variant / 'config'
        manifest_path = target / '.agents-orchestrator-manifest'
        original = manifest_path.read_text()
        (variant / 'evidence/manifest-before.txt').write_text(original)
        records = []
        for relative in ('plugins/recall-calc.ts', 'skills/spaced-recall/SKILL.md'):
            path = target / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists() or path.is_symlink():
                raise ValueError('Retired path already exists')
            path.write_text('// SYNTHETIC retired managed fixture\n' if path.suffix == '.ts' else '# Synthetic retired skill\n')
            records.append('file\t' + str(path))
        manifest_path.write_text(original + '\n'.join(records) + '\n')
        return
    states = list((variant / 'project/.ai/learning').glob('*/.state.json'))
    if len(states) != 1 or states[0].is_symlink():
        raise ValueError('Expected one regular copied state')
    path = states[0]
    state = json.loads(path.read_text())
    if fault == 'pending-views':
        state['views']['status'] = 'pending'
        (path.parent / 'path.md').unlink(missing_ok=True)
    elif fault == 'bad-digest':
        state['modules'][0]['retention']['preview']['digest'] = '0' * 64
    elif fault == 'bad-disposition':
        state['modules'][0]['retention']['disposition'] = 'unknown'
    elif fault in ('dead-lock', 'live-lock', 'malformed-lock'):
        lock = path.parent / '.state.lock'
        if lock.exists():
            raise ValueError('Lock already exists')
        if fault == 'malformed-lock':
            lock.write_text('not JSON')
            return
        process = subprocess.Popen(
            [sys.executable, '-c', 'import time; time.sleep(1800)' if fault == 'live-lock' else 'pass'],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if fault == 'dead-lock':
            process.wait()
        record = dict(pid=process.pid, token=str(uuid.uuid4()), acquired_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
        lock.write_text(json.dumps(record) + '\n')
        (variant / 'evidence/lock-owner.json').write_text(json.dumps(dict(record, synthetic=True, command='case-owned Python sleeper' if fault == 'live-lock' else 'exited Python child')) + '\n')
        return
    else:
        raise ValueError('Unknown fault')
    path.write_text(json.dumps(state, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('variant', type=Path)
    parser.add_argument('fault', choices=['upgrade', 'pending-views', 'bad-digest', 'bad-disposition', 'dead-lock', 'live-lock', 'malformed-lock'])
    args = parser.parse_args()
    inject(args.variant, args.fault)
