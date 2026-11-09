#!/usr/bin/env python3
"""freeze and review the real r16 host without importing the shared project.

python3 -I tests/r16_host_review.py --out /absolute/evidence/host-review
the RAM copy and all HOME/XDG paths are private and removed even after a timeout.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    godot = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    # these are this driver's outputs; old attempts would contaminate ghost selection.
    for name in ['engine', 'copied', 'mixed']:
        if (out / name).exists():
            shutil.rmtree(out / name)
    with tempfile.TemporaryDirectory(prefix='r16-host-review-', dir='/dev/shm') as temp:
        scratch = Path(temp)
        project = scratch / 'project'
        shutil.copytree(source, project, ignore=shutil.ignore_patterns('.godot', '.git', '__pycache__'))
        hashes = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in project.rglob('*') if p.is_file()}
        (out / 'SOURCE-HASHES.json').write_text(json.dumps(hashes, indent=1))
        env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'LANG': 'C.UTF-8', 'GODOT': str(godot)}
        for name in ['HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR']:
            path = scratch / name.lower()
            path.mkdir(mode=0o700)
            env[name] = str(path)
        base = [str(godot), '--headless', '--audio-driver', 'Dummy', '--path', str(project)]
        commands = []

        def run(label, command, timeout=240):
            commands.append(command)
            done = subprocess.run(command, env=env, cwd=project, capture_output=True, text=True, timeout=timeout)
            (out / (label + '.log')).write_text(done.stdout + '\n' + done.stderr)
            print(label, done.returncode, done.stdout[-1200:], done.stderr[-1200:], flush=True)
            return done

        imported = run('import', base + ['--editor', '--import'], 240)
        size = sum(p.stat().st_size for p in scratch.rglob('*') if p.is_file())
        if size >= 300 * 1024**2 or imported.returncode:
            raise RuntimeError(f'isolated import failed or exceeded budget: {size}')
        for name in ['r16_host_review.gd.uid', 'r16_host_review_fixture.gd.uid']:
            uid = project / 'tests' / name
            if uid.is_file():
                shutil.copy2(uid, source / 'tests' / name)
        tested = run('engine', base + ['--fixed-fps', '128', '--script', 'res://tests/r16_host_review.gd', '--', '--out=' + str(out / 'engine')], 300)
        copied = out / 'copied'
        copied.mkdir(exist_ok=True)
        for path in (out / 'engine' / 'runs').rglob('*.r16run*'):
            target = copied / path.relative_to(out / 'engine' / 'runs')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        analyzed = run('analyzer', [sys.executable, '-I', str(project / 'tools/analyze-r16-runs.py'), str(copied), '--json', str(out / 'analysis.json'), '--quiet'])
        summary_path = out / 'engine' / 'summary.json'
        summary = json.loads(summary_path.read_text()) if summary_path.is_file() else {}
        analysis = json.loads((out / 'analysis.json').read_text())
        checks = []
        for row in analysis.get('runs', []):
            outcome = row.get('outcome') or {}
            if 'style' in outcome:
                checks.append({'name': row['name'] + ': analyzer style sum matches outcome',
                               'ok': row['style']['points'] == outcome['style']['score']})
        mixed = out / 'mixed'
        shutil.copytree(copied, mixed)
        (mixed / 'empty.r16run').write_bytes(b'')
        (mixed / 'notes.txt').write_text('not a recording\n')
        run('mixed-analyzer', [sys.executable, '-I', str(project / 'tools/analyze-r16-runs.py'), str(mixed), '--json', str(out / 'mixed-analysis.json'), '--quiet'])
        mixed_report = json.loads((out / 'mixed-analysis.json').read_text())
        initial = {str(Path(r['file']).relative_to(copied)): {k: v for k, v in r.items() if k != 'file'} for r in analysis['runs']}
        compared = {str(Path(r['file']).relative_to(mixed)): {k: v for k, v in r.items() if k != 'file'} for r in mixed_report['runs']}
        checks.append({'name': 'copied valid and partial neighbors analyze identically beside new malformed files',
                       'ok': all(compared.get(k) == v for k, v in initial.items())})
        routes = Path('/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/release-plan/ROUTES.json')
        tape_out = scratch / 'tapes'
        tapes = run('tapes', [sys.executable, '-I', str(project / 'tests/test_r16_loop_tapes.py'), '--project', str(project), '--out', str(tape_out), '--routes', 'breakwater-basic', '--recordings', '--routes-file', str(routes)], 300)
        tape_summary = json.loads((tape_out / 'summary.json').read_text())
        (out / 'tape-summary.json').write_text(json.dumps(tape_summary, indent=1))
        checks.append({'name': 'accepted R15 Breakwater tape stays exact plain and recorded', 'ok': tapes.returncode == 0 and tape_summary.get('failed') == 0})
        report = {'engine_exit': tested.returncode, 'analyzer_exit': analyzed.returncode,
                  'engine_checks': summary.get('checks'), 'engine_failures': summary.get('failed'),
                  'copied_files': len(analysis.get('runs', [])), 'checks': checks,
                  'scratch_bytes_after_import': size,
                  'commands': commands, 'engine_sha256': hashlib.sha256(godot.read_bytes()).hexdigest(),
                  'scratch_cleaned_on_exit': str(scratch)}
        (out / 'driver.json').write_text(json.dumps(report, indent=1))
        print(json.dumps({k: v for k, v in report.items() if k not in ['checks', 'commands']}, indent=1))
        return tested.returncode


if __name__ == '__main__':
    raise SystemExit(main())
