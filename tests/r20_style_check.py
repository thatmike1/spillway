#!/usr/bin/env python3
"""run directional style proof sequentially in an isolated bounded snapshot."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'
CAP = 350 * 2**20
FLOOR = 15_000_000_000


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--keep-source', action='store_true')
    parser.add_argument('--only', default='stack')
    parser.add_argument('--cases', default='')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert shutil.disk_usage('/home').free >= FLOOR
    source = out / 'source'
    if not source.exists():
        shutil.copytree(PROJECT, source, ignore=shutil.ignore_patterns('.godot', '__pycache__', '*.pyc'))
        shutil.copytree(PROJECT / '.godot', source / '.godot')
    else:
        for name in ['scripts/r16_style.gd', 'scripts/r16_style_panel.gd', 'scripts/r18_style_panel.gd', 'scripts/r20_main.gd']:
            shutil.copy2(PROJECT / name, source / name)
        for path in (PROJECT / 'tests').glob('r20_style*'):
            shutil.copy2(path, source / 'tests' / path.name)
    baseline = out / 'r19_style.gd'
    baseline.write_bytes(subprocess.check_output(['git', 'show', BASE + ':projects/foldrunner/scripts/r16_style.gd'], cwd=PROJECT))
    files = {str(p.relative_to(source)): sha(p) for p in source.rglob('*') if p.is_file() and '.godot' not in p.parts}
    (out / 'SOURCE.json').write_text(json.dumps({'sha256': files, 'baseline_commit': BASE, 'baseline_sha256': sha(baseline), 'engine_sha256': sha(ENGINE)}, indent=2))
    env = os.environ.copy()
    for key in ['DATA', 'CONFIG', 'CACHE']:
        env['XDG_' + key + '_HOME'] = str(out / 'profiles' / key.lower())
    checks = []
    peak = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    lowest = shutil.disk_usage("/home").free
    def run(label, argv, scan=True):
        nonlocal peak, lowest
        assert shutil.disk_usage('/home').free >= FLOOR
        assert sum(p.stat().st_size for p in out.rglob('*') if p.is_file()) <= CAP
        start = time.monotonic()
        with (out / (label + '.log')).open('w') as log:
            proc = subprocess.Popen(list(map(str, argv)), cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT)
            while proc.poll() is None:
                peak = max(peak, sum(p.stat().st_size for p in out.rglob('*') if p.is_file()))
                lowest = min(lowest, shutil.disk_usage('/home').free)
                time.sleep(.5)
        text = (out / (label + '.log')).read_text()
        ok = proc.returncode == 0 and (not scan or not re.search(r'SCRIPT ERROR:|ERROR:|Parse Error:', text))
        checks.append({'name': label, 'ok': ok, 'exit': proc.returncode, 'seconds': time.monotonic() - start})
        (out / 'RUNNING.json').write_text(json.dumps(checks, indent=2))
        print(label, ok, flush=True)
        if not ok:
            print(text[-12000:], flush=True)
            raise RuntimeError(label)
    run('import', [ENGINE, '--headless', '--path', source, '--editor', '--import', '--quit'])
    for name in args.only.split(','):
        script = 'r20_style_stack.gd' if name in ['stack', 'observer'] else ('r20_style_ui.gd' if name.startswith('ui') else 'test_r16_style.gd')
        extra = ['--baseline=' + str(baseline)] if name in ['stack', 'observer'] else []
        if name == 'observer':
            extra += ['--observer']
        if name == 'stack' and args.cases:
            extra += ['--cases=' + args.cases]
        if name.startswith('ui'):
            extra += ['--size=' + ('1920x1080' if name == 'ui1080' else '1280x720')]
        run(name, [ENGINE, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', source, '--script', 'res://tests/' + script, '--', '--out=' + str(out / name), *extra])
    if 'stack' in args.only.split(','):
        module_spec = importlib.util.spec_from_file_location('r20_reader', source / 'tools/analyze-r16-runs.py')
        reader = importlib.util.module_from_spec(module_spec)
        sys.modules[module_spec.name] = reader
        module_spec.loader.exec_module(reader)
        recordings = []
        for path in sorted((out / 'stack/recordings').rglob('*.r16run')):
            rec = reader.read(path)
            assert rec.ok, rec.errors
            recordings.append({'path': str(path), 'sha256': sha(path), 'ticks': len(rec.columns['tick']), 'events': len(rec.events)})
        assert recordings
        run('audit', [sys.executable, '-I', source / 'tests/r20_style_audit.py', '--run', out, '--source', source, '--repo', PROJECT])
        (out / 'READERS.json').write_text(json.dumps({'ok': True, 'recordings': recordings}, indent=2))
    (out / 'RESULTS.json').write_text(json.dumps({'ok': True, 'checks': checks, 'home_free_bytes': shutil.disk_usage('/home').free, 'lowest_home_free_bytes': lowest, 'peak_scratch_bytes': peak, 'cap_bytes': CAP, 'floor_bytes': FLOOR, 'cases': args.cases, 'scope': 'headless component only', 'scratch_bytes': sum(p.stat().st_size for p in out.rglob('*') if p.is_file())}, indent=2))
    assert peak <= CAP and lowest >= FLOOR
    assert all(sha(source / name) == expected for name, expected in files.items()), 'verification source changed'
    if not args.keep_source:
        shutil.rmtree(source)
        shutil.rmtree(out / 'profiles', ignore_errors=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
