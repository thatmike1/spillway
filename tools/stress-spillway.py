#!/usr/bin/env python3
"""run the input timing/aim matrix and preserve every attempt outside Git."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
SOURCES = ['spillway_player.gd', 'spillway_level.gd', 'spillway_course.gd', 'spillway_main.gd', 'spillway_driver.gd']


def source_hashes():
    return {name: hashlib.sha256((PROJECT / 'scripts' / name).read_bytes()).hexdigest() for name in SOURCES}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', str(Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')))
    args = parser.parse_args()
    root = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=PROJECT, text=True).strip())
    output = args.output.expanduser().resolve()
    if output == root or root in output.parents:
        parser.error('evidence must be outside Git')
    output.mkdir(parents=True, exist_ok=True)
    before = source_hashes()
    cases = [(f'baseline-{route}-{seed}', route, seed, []) for route in ['safe', 'fast', 'recovery', 'brake', 'safe_corner', 'fast_housing_turn'] for seed in range(5)]
    cases += [(f'{label}-fast-{seed}', 'fast', seed, [f'--jump-delay={delay}', '--aim-deg=2']) for label, delay in [('early', '-0.08'), ('late', '0.08')] for seed in range(1, 4)]
    rows = []
    for name, route, seed, extra in cases:
        folder = output / name
        folder.mkdir(exist_ok=True)
        command = [args.godot, '--headless', '--fixed-fps', '120', '--path', str(PROJECT), '--', '--bot', '--bot-quit', f'--route={route}', f'--seed={seed}', f'--evidence-dir={folder}', *extra]
        result = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (folder / 'engine.log').write_text(result.stdout)
        traces = sorted(folder.glob('route-*.jsonl'), key=lambda path: path.stat().st_mtime_ns)
        records = [json.loads(line) for line in traces[-1].read_text().splitlines()] if traces else []
        final = next((record for record in reversed(records) if record.get('event') == 'result'), {})
        errors = 'SCRIPT ERROR:' in result.stdout or 'ERROR:' in result.stdout
        row = {'case': name, 'command': command, 'exit': result.returncode, 'engine_errors': errors, 'success': result.returncode == 0 and not errors and final.get('success', False), 'result': final, 'trace': str(traces[-1]) if traces else None}
        rows.append(row)
        print(name, 'PASS' if row['success'] else 'FAIL', round(final.get('time', 0), 3), final.get('reason', 'no result'), flush=True)
        (output / 'matrix-results.json').write_text(json.dumps({'attempts': len(rows), 'successes': sum(item['success'] for item in rows), 'source_hashes': before, 'cases': rows}, indent=2) + '\n')
    if source_hashes() != before:
        raise SystemExit('runtime sources changed during the matrix; this pass is not canonical')
    passed = sum(row['success'] for row in rows)
    print(f'Spillway input matrix: {passed}/{len(rows)} finished. Execution evidence, not human enjoyment.')
    raise SystemExit(0 if passed == len(rows) else 1)


if __name__ == '__main__':
    main()
