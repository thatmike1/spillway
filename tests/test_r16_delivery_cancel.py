#!/usr/bin/env python3
"""SIGTERM the source wrapper alone during a real frozen-copy import; verify its ownership."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    project = Path(__file__).resolve().parents[1]
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    scratch = out / 'scratch'; scratch.mkdir()
    target = out / 'run'
    command = ['bash', str(project / 'tools/check-r16.sh'), '--source', 'worktree', '--components-only', '--allow-r15-default',
               '--scratch', str(scratch), '--out', str(target)]
    child = None
    try:
        with open(out / 'wrapper.log', 'wb') as log:
            child = subprocess.Popen(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            until = time.monotonic() + 30
            ready = False
            stages = []
            while child.poll() is None and time.monotonic() < until:
                stages = list(scratch.glob('r16-source-*'))
                if stages and (stages[0] / '.godot').is_dir() and (target / 'import.log').is_file():
                    ready = True
                    break
                time.sleep(0.05)
            if ready:
                os.kill(child.pid, signal.SIGTERM)
            code = child.wait(45)
        result = json.loads((target / 'RESULTS.json').read_text()) if (target / 'RESULTS.json').is_file() else {}
        leftovers = []
        for proc in Path('/proc').iterdir():
            if proc.name.isdigit():
                try:
                    cmdline = (proc / 'cmdline').read_bytes()
                    if any(str(stage).encode() in cmdline for stage in stages):
                        leftovers.append(int(proc.name))
                except (OSError, ProcessLookupError):
                    pass
        rows = [{'name': 'reached actual engine import of the external snapshot', 'ok': ready},
                {'name': 'SIGTERM wrapper alone exits 130', 'ok': code == 130},
                {'name': 'frozen source and imports removed', 'ok': not any(scratch.iterdir()) and result.get('source_removed') is True},
                {'name': 'owned engine descendants released', 'ok': not leftovers}]
        (out / 'summary.json').write_text(json.dumps({'checks': len(rows), 'failed': sum(not r['ok'] for r in rows), 'results': rows,
            'argv': command, 'exit': code, 'leftover_pids': leftovers}, indent=2) + '\n')
        print('r16 wrapper cancellation: %d checks, %d failed' % (len(rows), sum(not r['ok'] for r in rows)))
        return int(any(not r['ok'] for r in rows))
    finally:
        if child is not None and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            child.wait(45)


if __name__ == '__main__':
    sys.exit(main())
