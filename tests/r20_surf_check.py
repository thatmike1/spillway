#!/usr/bin/env python3
"""run the Saltglass component gates sequentially in one bounded external source snapshot."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
ERRORS = re.compile(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:|Failed to load script', re.M)
CAP = 350 * 2**20
FLOOR = 15_000_000_000


def size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True, help='new output directory outside source')
    parser.add_argument('--source', type=Path, help='existing frozen component snapshot; otherwise make one under output')
    parser.add_argument('--budget-root', type=Path, help='include earlier task scratch in the 350 MiB accounting')
    parser.add_argument('--keep-source', action='store_true', help='parent inspection only; default removes a source made by this command')
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists() or PROJECT == out or PROJECT in out.parents:
        parser.error('--out must be new and outside source')
    if shutil.disk_usage('/home').free < FLOOR:
        parser.error('HOME below 15,000,000,000 bytes')
    out.mkdir(parents=True)
    source = args.source.resolve() if args.source else out / 'source'
    made_source = not args.source
    if made_source:
        shutil.copytree(PROJECT, source, ignore=shutil.ignore_patterns('.godot', '__pycache__'))
        if (PROJECT / '.godot').is_dir():
            shutil.copytree(PROJECT / '.godot', source / '.godot')
    budget_root = args.budget_root.resolve() if args.budget_root else out
    source_hashes = {str(p.relative_to(source)): digest(p) for p in source.rglob('*') if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}
    (out / 'SOURCE.json').write_text(json.dumps({'source': str(source), 'sha256': source_hashes, 'engine': str(ENGINE), 'engine_sha256': digest(ENGINE)}, indent=2) + '\n')
    checks = []
    passed = False
    peak_scratch = size(budget_root)
    low_home = shutil.disk_usage('/home').free
    if peak_scratch > CAP:
        raise RuntimeError('initial task scratch exceeds 350 MiB')

    def command(name, argv, engine=False, errors=True):
        nonlocal peak_scratch, low_home
        if shutil.disk_usage('/home').free < FLOOR or size(budget_root) > CAP:
            raise RuntimeError('resource floor/cap before ' + name)
        env = os.environ.copy()
        profile = out / '_profiles' / name
        for var, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
            env[var] = str(profile / folder)
        start = time.monotonic()
        with (out / (name + '.log')).open('w') as log:
            process = subprocess.Popen([str(a) for a in argv], cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT)
            # observation never times out or stops a live engine. one task process at a time.
            while process.poll() is None:
                peak_scratch = max(peak_scratch, size(budget_root))
                low_home = min(low_home, shutil.disk_usage('/home').free)
                time.sleep(.5)
        text = (out / (name + '.log')).read_text()
        ok = process.returncode == 0 and (not errors or not ERRORS.search(text))
        check = {'name': name, 'ok': ok, 'exit': process.returncode, 'elapsed_wall_s': time.monotonic() - start, 'engine': engine, 'scan_errors': errors,
                 'maximum_child_rss_kib_so_far': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}
        checks.append(check)
        print(('PASS ' if ok else 'FAIL ') + name, flush=True)
        for trace in (out / name).glob('trace.jsonl'):
            with trace.open('rb') as src, gzip.open(str(trace) + '.gz', 'wb') as dst:
                shutil.copyfileobj(src, dst)
            trace.unlink()
        (out / 'RUNNING.json').write_text(json.dumps({'checks': checks, 'peak_scratch_bytes': peak_scratch, 'lowest_home_free_bytes': low_home}, indent=2) + '\n')
        if not ok:
            raise RuntimeError(name + ': ' + str(out / (name + '.log')))

    def godot(name, script, extra=(), errors=True):
        command(name, [ENGINE, '--headless', '--fixed-fps', '128', '--path', source, '--script', 'res://tests/' + script, '--', '--out=' + str(out / name), *extra], engine=True, errors=errors)

    try:
        command('import', [ENGINE, '--headless', '--path', source, '--editor', '--import', '--quit'], engine=True)
        godot('integration', 'r20_surf_integration.gd')
        godot('geometry-negative', 'r20_surf_geometry_negative.gd')
        godot('run', 'r20_surf_route.gd')
        tape = '--tape=' + str(out / 'run/events.tape.json')
        godot('replay', 'r20_surf_route.gd', [tape])
        godot('old-look', 'r20_surf_route.gd', [tape, '--old-look=1'])
        for name, probe in [('west-bail', 'west_bail'), ('east-bail', 'east_bail'), ('turnaround', 'turnaround'), ('turnaround-diagonal', 'turnaround_diagonal')]:
            godot(name, 'r20_surf_probes.gd', ['--probe=' + probe])
        command('audit', [sys.executable, '-I', source / 'tests/r20_surf_audit.py', '--base', out, '--out', out / 'AUDIT.json'])
        # existing relevant component suites, in the same snapshot and sequential engine budget.
        godot('r15-crouch', 'test_r15_crouch.gd')
        godot('r16-style', 'test_r16_style.gd')
        godot('r16-record', 'test_r16_record.gd', errors=False)
        command('r16-record-format', [sys.executable, '-I', source / 'tests/test_r16_record_format.py', '--run', out / 'r16-record', '--out', out / 'r16-record-format.json', '--log', out / 'r16-record.log', '--godot', ENGINE, '--project', source])
        command('r20-preservation-unit', [sys.executable, '-I', source / 'tests/test_r20_preservation.py'])
        changed = [name for name, sha in source_hashes.items() if not (source / name).is_file() or digest(source / name) != sha]
        if changed:
            raise RuntimeError('frozen source changed: ' + str(changed))
        if peak_scratch > CAP or low_home < FLOOR:
            raise RuntimeError('resource acceptance failed')
        passed = True
    finally:
        removed = False
        if made_source and not args.keep_source:
            shutil.rmtree(source)
            removed = True
        profiles = out / '_profiles'
        if profiles.exists():
            shutil.rmtree(profiles)
        result = {'ok': passed and bool(checks) and all(c['ok'] for c in checks) and len(checks) == 16, 'checks': checks,
                  'peak_scratch_bytes': peak_scratch, 'cap_bytes': CAP, 'lowest_home_free_bytes': low_home, 'floor_bytes': FLOOR,
                  'maximum_child_rss_kib': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss, 'source_removed': removed,
                  'scope': 'headless component/source acceptance only; parent owns native display, export and release'}
        (out / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
