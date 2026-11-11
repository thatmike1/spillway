#!/usr/bin/env python3
"""run the Saltglass component gates sequentially in one bounded external source snapshot."""
from __future__ import annotations

import argparse
import gzip
import fcntl
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


def task_size(out):
    roots = list(Path('/tmp').glob('r21-surf*'))
    if not any(out == root or root in out.parents for root in roots):
        roots.append(out)
    return sum(size(root) if root.is_dir() else root.stat().st_size for root in roots if root.exists())


def preserved(source, out, seam_path=None, seam_sha256=None):
    baseline = 'e6baa995da84d380abc8b8d6a3769b33e771945e'
    paths = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', baseline, '--',
        'projects/foldrunner/scripts', 'projects/foldrunner/scenes', 'projects/foldrunner/assets',
        'projects/foldrunner/data', 'projects/foldrunner/project.godot'], cwd=PROJECT.parents[1]).decode().splitlines()
    if not paths:
        raise RuntimeError('empty baseline runtime inventory refused')
    allowed = {'project.godot', 'scripts/r19_ghost_share.gd'}
    rows = {}
    for full in paths:
        relative = full.removeprefix('projects/foldrunner/')
        before = hashlib.sha256(subprocess.check_output(['git', 'show', baseline + ':' + full], cwd=PROJECT)).hexdigest()
        after = digest(source / relative) if (source / relative).is_file() else 'missing'
        rows[relative] = {'before': before, 'executed': after, 'same': before == after, 'parent_exception': relative in allowed}
    if seam_path is not None:
        if not re.fullmatch('[0-9a-f]{64}', seam_sha256 or '') or digest(seam_path) != seam_sha256:
            raise RuntimeError('explicit parent seam hash mismatch')
    else:
        if seam_sha256 is not None:
            raise RuntimeError('parent seam hash without a file')
        seam_path = PROJECT.parents[2] / 'evidence/r21-salt-parent-seam.json'
    seam = json.loads(seam_path.read_text())
    required = {'scripts/r21_main.gd', 'scripts/r21_map_catalog.gd', 'scenes/r21.tscn',
                'project.godot', 'scripts/r19_ghost_share.gd'}
    if not isinstance(seam, dict) or not isinstance(seam.get('files'), dict) or not required <= set(seam['files']):
        raise RuntimeError('parent seam must bind all five integration files')
    if not all(isinstance(name, str) and not Path(name).is_absolute() and '\\' not in name
               and all(part not in ('', '.', '..') for part in name.split('/'))
               and isinstance(sha, str) and re.fullmatch('[0-9a-f]{64}', sha)
               for name, sha in seam['files'].items()):
        raise RuntimeError('invalid parent seam path/hash')
    seam_ok = all(digest(source / name) == sha for name, sha in seam['files'].items())
    result = {'ok': seam_ok and all(row['same'] or row['parent_exception'] for row in rows.values()),
        'baseline': baseline, 'parent_seam_exact': seam_ok, 'files': rows,
        'parent_seam_path': str(seam_path), 'parent_seam_sha256': digest(seam_path)}
    (out / 'PRESERVATION.json').write_text(json.dumps(result, indent=2) + '\n')
    if not result['ok']:
        raise RuntimeError('original runtime or frozen parent seam changed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True, help='new output directory outside source')
    parser.add_argument('--source', type=Path, help='existing frozen component snapshot; otherwise make one under output')
    parser.add_argument('--budget-root', type=Path, help='compatibility argument; all owned /tmp/r21-surf* scratch is always counted')
    parser.add_argument('--fixture', choices=['skill', 'exit', 'ghost'], help='bounded fixture development only')
    parser.add_argument('--old-ghost', type=Path, default=PROJECT.parents[3] / 'playtest-r20/userdata-spillway/r16_runs/saltglass_server128_20261111-104057_050_d1951cf9.r16run')
    parser.add_argument('--new-ghost', type=Path, help='completed new run for a ghost-only recheck')
    parser.add_argument('--develop', action='store_true', help='import and run only; retain snapshot for bounded iteration')
    parser.add_argument('--keep-source', action='store_true', help='parent inspection only; default removes a source made by this command')
    parser.add_argument('--parent-seam', type=Path, help='explicit reviewed final integration hashes; historical frozen Saltglass seam by default')
    parser.add_argument('--parent-seam-sha256', help='required external digest when --parent-seam is supplied')
    args = parser.parse_args()
    if bool(args.parent_seam) != bool(args.parent_seam_sha256):
        parser.error('--parent-seam and --parent-seam-sha256 must be supplied together')
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
    peak_scratch = task_size(out)
    low_home = shutil.disk_usage('/home').free
    low_tmp = shutil.disk_usage('/tmp').free
    low_mem = int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:'))) * 1024
    if peak_scratch > CAP:
        raise RuntimeError('initial task scratch exceeds 350 MiB')

    def command(name, argv, engine=False, errors=True):
        nonlocal peak_scratch, low_home, low_tmp, low_mem
        if shutil.disk_usage('/home').free < FLOOR or task_size(out) > CAP or shutil.disk_usage('/tmp').free < 1_000_000_000 or int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:'))) * 1024 < 3_000_000_000:
            raise RuntimeError('resource floor/cap before ' + name)
        env = os.environ.copy()
        env['HOME'] = str(out / '_profiles' / name / 'home')
        Path(env['HOME']).mkdir(parents=True, exist_ok=True)
        profile = out / '_profiles' / name
        for var, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
            env[var] = str(profile / folder)
        start = time.monotonic()
        with (out / (name + '.log')).open('w') as log:
            process = subprocess.Popen([str(a) for a in argv], cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT)
            # one engine at a time; terminate a script error rather than leaving a failed assertion running.
            while process.poll() is None:
                peak_scratch = max(peak_scratch, task_size(out))
                low_home = min(low_home, shutil.disk_usage('/home').free)
                low_tmp = min(low_tmp, shutil.disk_usage('/tmp').free)
                low_mem = min(low_mem, int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:'))) * 1024)
                if peak_scratch > CAP or low_home < FLOOR or low_tmp < 1_000_000_000 or low_mem < 3_000_000_000:
                    process.terminate()
                    process.wait(timeout=10)
                    break
                if ERRORS.search((out / (name + '.log')).read_text()) and errors:
                    process.terminate()
                    process.wait(timeout=10)
                    break
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
        (out / 'RUNNING.json').write_text(json.dumps({'checks': checks, 'peak_scratch_bytes': peak_scratch, 'lowest_home_free_bytes': low_home, 'lowest_tmp_free_bytes': low_tmp, 'lowest_mem_available_bytes': low_mem}, indent=2) + '\n')
        if not ok:
            raise RuntimeError(name + ': ' + str(out / (name + '.log')))

    def godot(name, script, extra=(), errors=True):
        command(name, [ENGINE, '--headless', '--fixed-fps', '128', '--path', source, '--script', 'res://tests/' + script, '--', '--out=' + str(out / name), *extra], engine=True, errors=errors)

    preserved(source, out, args.parent_seam, args.parent_seam_sha256)
    lock = open('/tmp/spillway-r21-engine.lock', 'a')
    fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        command('import', [ENGINE, '--headless', '--path', source, '--editor', '--import', '--quit'], engine=True)
        source_hashes = {str(p.relative_to(source)): digest(p) for p in source.rglob('*') if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}
        (out / 'SOURCE.json').write_text(json.dumps({'source': str(source), 'sha256': source_hashes, 'engine': str(ENGINE), 'engine_sha256': digest(ENGINE), 'scope': 'exact current source including frozen parent overlays; captured after import, before gameplay'}, indent=2) + '\n')
        uid_dir = out / 'owned-uids'
        uid_dir.mkdir()
        for uid in list(source.glob('scripts/r21_surf_*.gd.uid')) + list(source.glob('tests/r21_surf_*.gd.uid')):
            shutil.copy2(uid, uid_dir / uid.name)
        if args.fixture == 'ghost':
            if not args.new_ghost:
                raise ValueError('--new-ghost required with --fixture=ghost')
            godot('ghost', 'r21_surf_ghost.gd', ['--old-ghost=' + str(args.old_ghost), '--new-ghost=' + str(args.new_ghost)])
            passed = True
            return 0
        if args.fixture == 'skill':
            for mode in ['safe', 'outside', 'late']:
                godot('skill-' + mode, 'r21_surf_skill.gd', ['--skill=' + mode])
            passed = True
            return 0
        if args.fixture == 'exit':
            for fin in ['west', 'east']:
                for geometry, target in [('r20', '10.0'), ('r21', '10.0'), ('r21', '5.3'), ('r20', '5.3')]:
                    godot(fin + '-' + geometry + '-' + target, 'r21_surf_exit.gd', ['--fin=' + fin, '--exit-geometry=' + geometry, '--exit-target=' + target])
            passed = True
            return 0
        if args.develop:
            godot('run', 'r21_surf_route.gd')
            passed = True
            return 0
        godot('integration', 'r21_surf_integration.gd')
        godot('geometry-negative', 'r21_surf_geometry_negative.gd')
        godot('run', 'r21_surf_route.gd')
        tape = '--tape=' + str(out / 'run/events.tape.json')
        godot('replay', 'r21_surf_route.gd', [tape])
        godot('old-look', 'r21_surf_route.gd', [tape, '--old-look=1'])
        for name, probe in [('west-bail', 'west_bail'), ('east-bail', 'east_bail'), ('turnaround', 'turnaround'), ('turnaround-diagonal', 'turnaround_diagonal')]:
            godot(name, 'r21_surf_probes.gd', ['--probe=' + probe])
        for mode in ['safe', 'outside', 'late']:
            godot('skill-' + mode, 'r21_surf_skill.gd', ['--skill=' + mode])
        for fin in ['west', 'east']:
            for geometry, target in [('r20', '10.0'), ('r21', '10.0'), ('r21', '5.3'), ('r20', '5.3')]:
                godot(fin + '-' + geometry + '-' + target, 'r21_surf_exit.gd', ['--fin=' + fin, '--exit-geometry=' + geometry, '--exit-target=' + target])
        run_summary = json.loads((out / 'run/summary.json').read_text())
        godot('ghost', 'r21_surf_ghost.gd', ['--old-ghost=' + str(args.old_ghost), '--new-ghost=' + run_summary['recordings'][0]['path']])
        command('audit', [sys.executable, '-I', source / 'tests/r21_surf_audit.py', '--base', out, '--out', out / 'AUDIT.json'])
        command('matches', [sys.executable, '-I', source / 'tests/r21_surf_matches.py', '--base', out, '--out', out / 'MATCHES.json'])
        # existing relevant component suites, in the same snapshot and sequential engine budget.
        godot('r15-crouch', 'test_r15_crouch.gd')
        godot('r16-style', 'test_r16_style.gd')
        godot('r16-record', 'test_r16_record.gd', errors=False)
        command('r16-record-format', [sys.executable, '-I', source / 'tests/test_r16_record_format.py', '--run', out / 'r16-record', '--out', out / 'r16-record-format.json', '--log', out / 'r16-record.log', '--godot', ENGINE, '--project', source])
        command('r21-preservation-unit', [sys.executable, '-I', source / 'tests/test_r21_preservation.py'])
        changed = [name for name, sha in source_hashes.items() if not (source / name).is_file() or digest(source / name) != sha]
        if changed:
            raise RuntimeError('frozen source changed: ' + str(changed))
        if peak_scratch > CAP or low_home < FLOOR:
            raise RuntimeError('resource acceptance failed')
        passed = True
    finally:
        final_changed = [name for name, sha in source_hashes.items() if not (source / name).is_file() or digest(source / name) != sha]
        removed = False
        if made_source and not args.keep_source:
            shutil.rmtree(source)
            removed = True
        profiles = out / '_profiles'
        if profiles.exists():
            shutil.rmtree(profiles)
        expected_checks = 4 if args.fixture == 'skill' else 9 if args.fixture == 'exit' else 2 if args.fixture == 'ghost' or args.develop else 29
        changed = final_changed
        result = {'ok': passed and not changed and bool(checks) and all(c['ok'] for c in checks) and len(checks) == expected_checks, 'checks': checks,
                  'peak_scratch_bytes': peak_scratch, 'cap_bytes': CAP, 'lowest_home_free_bytes': low_home, 'floor_bytes': FLOOR, 'lowest_tmp_free_bytes': low_tmp, 'lowest_mem_available_bytes': low_mem, 'source_changed': changed,
                  'maximum_child_rss_kib': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss, 'source_removed': removed,
                  'scope': 'headless component/source acceptance only; parent owns native display, export and release'}
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()
        (out / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
