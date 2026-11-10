#!/usr/bin/env python3
"""sequential production Tether acceptance with bounded snapshots and retained failures."""
import argparse
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'
CAP = 350 * 2**20
FLOOR = 15_000_000_000


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_reader(source):
    spec = importlib.util.spec_from_file_location('tether_original_reader', source / 'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = reader
    spec.loader.exec_module(reader)
    return reader


def read(path):
    return json.loads(Path(path).read_text())


def equivalent(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(equivalent(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(equivalent(x, y) for x, y in zip(a, b))
    if type(a) in (int, float) and type(b) in (int, float):
        return math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-13)
    return a == b


def trace(path):
    return [json.loads(line) for line in gzip.decompress(Path(path).read_bytes()).splitlines()]


def run_suite(out, only):
    source = out / 'source'
    out.mkdir(parents=True, exist_ok=True)
    assert shutil.disk_usage('/home').free >= FLOOR
    if not source.exists():
        shutil.copytree(PROJECT, source, ignore=shutil.ignore_patterns('.godot', '__pycache__', '*.pyc'))
        shutil.copytree(PROJECT / '.godot', source / '.godot')
    else:
        for path in [*PROJECT.glob('scripts/r20*.gd'), *PROJECT.glob('tests/r20_tether*')]:
            shutil.copy2(path, source / path.relative_to(PROJECT))
    baseline = out / 'r19_tether_player.gd'
    baseline.write_bytes(subprocess.check_output(['git', 'show', BASE + ':projects/foldrunner/scripts/r19_tether_player.gd'], cwd=PROJECT))
    files = {str(p.relative_to(source)): sha(p) for p in source.rglob('*') if p.is_file() and '.godot' not in p.parts}
    (out / 'SOURCE.json').write_text(json.dumps({'sha256': files, 'baseline_commit': BASE, 'baseline_sha256': sha(baseline), 'engine_sha256': sha(ENGINE)}, indent=2))
    env = os.environ.copy()
    for key in ['DATA', 'CONFIG', 'CACHE']:
        env['XDG_' + key + '_HOME'] = str(out / 'profiles' / key.lower())
    attempts = read(out / 'RUNNING.json') if (out / 'RUNNING.json').exists() else []
    peak = 0
    minimum = shutil.disk_usage('/home').free

    def run(label, script, args=(), python_command=None):
        nonlocal peak, minimum
        target = out / label
        assert not target.exists(), 'proof output already exists: ' + str(target)
        argv = python_command or [ENGINE, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', source, '--script', 'res://tests/' + script, '--', '--out=' + str(target), *args]
        start = time.monotonic()
        with (out / (label + '.log')).open('x') as log:
            process = subprocess.Popen(list(map(str, argv)), cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT)
            failure = ''
            while process.poll() is None:
                size = sum(p.stat().st_size for p in out.rglob('*') if p.is_file())
                free = shutil.disk_usage('/home').free
                peak = max(peak, size)
                minimum = min(minimum, free)
                if size > CAP or free < FLOOR or time.monotonic() - start > 180:
                    failure = 'resource cap or timeout'
                    process.terminate()
                    process.wait(timeout=10)
                    break
                time.sleep(.25)
        text = (out / (label + '.log')).read_text()
        errors = [line for line in text.splitlines() if line.startswith('ERROR:')]
        expected_errors = script == 'test_r16_record.gd' and len(errors) == 5 and all(any(marker in line for marker in [
            'header metadata is 70362 bytes, above the 65536 byte bound',
            'test hook: write refused after 3000 bytes',
            "Could not create directory:", 'cannot create recording directory', 'cannot open '
        ]) for line in errors) and read(target / 'summary.json')['failed'] == 0
        passed = process.returncode == 0 and not failure and not re.search(r'SCRIPT ERROR:|ObjectDB instances leaked', text) and (not errors or expected_errors)
        attempts.append({'label': label, 'ok': passed, 'exit': process.returncode, 'failure': failure, 'seconds': time.monotonic() - start, 'argv': list(map(str, argv))})
        (out / 'RUNNING.json').write_text(json.dumps(attempts, indent=2))
        print(label, passed, flush=True)
        if not passed:
            print(text[-8000:], flush=True)
            raise RuntimeError(label)
        return target

    reader = load_reader(source)
    selected = only.split(',')
    if 'record_format' in selected:
        run('record_format_recheck', 'test_r16_record.gd')
    if 'component' in selected:
        run('component', 'r20_tether_component.gd')
        run('component_old_e', 'r20_tether_component.gd', ['--old-e', '--baseline=' + str(baseline)])
    models = ['classic', 'pendulum', 'elastic'] if 'routes' in selected else []
    for model in models:
        route = run(model, 'r20_tether_route.gd', ['--model=' + model])
        summary = read(route / 'summary.json')
        assert summary['pass'] and summary['finished'] and summary['respawns'] == 0
        sealed = next(row for row in summary['recordings'] if row['clean_finish'].get('ok'))
        rec = reader.read(Path(sealed['path']))
        assert rec.ok, rec.errors
        # replay exactly the saved binary input columns, in their recorded order. Action rows
        # are derived from raw edges by the unchanged host and must compare equal afterward.
        events = []
        assert set(rec.inputs['kind']) <= {1, 2, 3, 4}
        for i, kind in enumerate(rec.inputs['kind']):
            if kind in {1, 2, 3}:
                row = {k: v[i] for k, v in rec.inputs.items()}
                assert row['tick'] >= 33
                events.append({'tick': row['tick'] - 33, 'raw': row})
        tape = out / (model + '-recorded.tape.json')
        tape.write_text(json.dumps({'version': 2, 'physics_hz': 128, 'duration_ticks': len(rec.columns['tick']) - 33, 'events': events}))
        replay = run(model + '_saved_replay', 'r20_tether_route.gd', ['--model=' + model, '--tape=' + str(tape)])
        replay_summary = read(replay / 'summary.json')
        replay_sealed = next(row for row in replay_summary['recordings'] if row['clean_finish'].get('ok'))
        replay_rec = reader.read(Path(replay_sealed['path']))
        assert rec.columns == replay_rec.columns, model + ' actual saved-input replay columns differ'
        assert rec.inputs == replay_rec.inputs, model + ' complete ordered mouse/key/motion/action input columns differ'
        if model == 'classic':
            original_tape = read(route / 'events.tape.json')
            old_events = []
            for event in original_tape['events']:
                if 'button' in event:
                    if event['button'] == 1:
                        old_events.append({'tick': event['tick'], 'key': 'e', 'edge': event['edge']})
                else:
                    old_events.append(event)
            original_tape['events'] = old_events
            old_tape = out / 'old-e.tape.json'
            old_tape.write_text(json.dumps(original_tape))
            run('old_e', 'r20_tether_route.gd', ['--old-e=1', '--baseline=' + str(baseline), '--tape=' + str(old_tape)])
            run('automatic', 'r20_tether_route.gd', ['--auto=1'])
    if set(selected) >= {'component', 'routes'}:
        run('boundaries', 'r20_tether_boundaries.gd')
        run('record_format', 'test_r16_record.gd')
        env['R16_SCRATCH'] = str(out / 'format-python')
        run('format-python', 'python_record_format', python_command=[sys.executable, '-I', source / 'tests/test_r16_record_format.py', '--run', out / 'record_format', '--out', out / 'format-python/summary.json', '--log', out / 'record_format.log', '--godot', ENGINE, '--project', source])
        assert read(out / 'format-python/summary.json')['failed'] == 0
        run('readers', 'r20_tether_readers.gd', ['--root=' + str(out)])
    (out / 'RESOURCES.json').write_text(json.dumps({'peak_scratch_bytes': peak, 'minimum_home_bytes': minimum, 'cap_bytes': CAP, 'floor_bytes': FLOOR}, indent=2))
    if set(selected) >= {'component', 'routes'}:
        audit(source, out, PROJECT)
    return source


def audit(source, out, repo):
    reader = load_reader(source)
    results = []
    recordings = []
    global READER_WIRES
    READER_WIRES = {row['path']: row for row in read(out / 'readers/index.json')}
    for label in ['component', 'component_old_e', 'boundaries']:
        summary = read(out / label / 'summary.json')
        assert summary['ok']
        results += summary['checks']
        for path in sorted((out / label).glob('*.json.gz')):
            episode = json.loads(gzip.decompress(path.read_bytes()))
            for wire in episode['recordings']:
                cross_reader(reader, wire, recordings)
    for label in ['classic', 'classic_saved_replay', 'pendulum', 'pendulum_saved_replay', 'elastic', 'elastic_saved_replay', 'old_e', 'automatic']:
        summary = read(out / label / 'summary.json')
        assert summary['pass']
        assert summary['geometry_hash'] == read(out / 'classic/summary.json')['geometry_hash']
        for wire in summary['recordings']:
            cross_reader(reader, wire, recordings)
        results.append({'ok': True, 'check': label + ' earned clean route', 'elapsed': summary['elapsed'], 'ticks': summary['ticks'], 'attached': summary['attached_ticks'], 'pull': summary['pull_ticks'], 'radial': summary['rope_ticks']})
    for label in ['classic', 'pendulum', 'elastic']:
        a = trace(out / label / 'trace.jsonl.gz')
        b = trace(out / (label + '_saved_replay') / 'trace.jsonl.gz')
        assert len(a) == len(b)
        # driver held dictionaries are observational conveniences; input truth is the full binary table.
        for i, (x, y) in enumerate(zip(a, b)):
            for k in ['p', 'reference_p', 'v', 'yaw', 'pitch', 'grounded', 'motion', 'checkpoint', 'elapsed', 'respawns', 'style']:
                assert x[k] == y[k], (label, i, k)
        if label == 'pendulum':
            assert all(row['motion']['experiment']['impulses_u'].get('grapple_pull', [0, 0, 0]) == [0, 0, 0] for row in a)
        if label == 'elastic':
            assert all(row['motion']['experiment']['impulses_u'].get('grapple_rope', [0, 0, 0]) == [0, 0, 0] for row in a)
            assert all(math.sqrt(sum(v*v for v in row['motion']['experiment']['impulses_u'].get('grapple_pull', [0, 0, 0]))) <= 1800/128 + 0.0001 for row in a)
        results.append({'ok': True, 'check': label + ' every physical/motion/style observation exactly replays recorded inputs', 'rows': len(a)})
    classic = trace(out / 'classic/trace.jsonl.gz')
    for label in ['old_e', 'automatic']:
        other = trace(out / label / 'trace.jsonl.gz')
        assert len(classic) == len(other)
        for i, (a, b) in enumerate(zip(classic, other)):
            for key in ['p', 'reference_p', 'v', 'yaw', 'pitch', 'grounded', 'checkpoint', 'elapsed', 'respawns']:
                assert a[key] == b[key], (label, i, key)
            for key in ['grapple', 'events', 'counts', 'impulses_u', 'impulse_totals_u']:
                assert a['motion']['experiment'][key] == b['motion']['experiment'][key], (label, i, key)
        results.append({'ok': True, 'check': 'classic exact physical pairing with ' + label, 'rows': len(classic)})
    for label in ['immediate_fresh', 'ground_timeout', 'minimum', 'obstructed', 'range']:
        a = json.loads(gzip.decompress((out / 'component' / (label + '.json.gz')).read_bytes()))['observations']
        b = json.loads(gzip.decompress((out / 'component_old_e' / (label + '.json.gz')).read_bytes()))['observations']
        assert len(a) == len(b)
        for i, (x, y) in enumerate(zip(a, b)):
            for key in ['p', 'v', 'yaw', 'pitch', 'grounded']:
                assert x[key] == y[key], ('frozen classic fixture', label, i, key)
            for key in ['grapple', 'events', 'counts', 'impulses_u', 'impulse_totals_u']:
                assert x['motion']['experiment'][key] == y['motion']['experiment'][key], ('frozen classic fixture', label, i, key)
        results.append({'ok': True, 'check': 'independent old-E physical fixture pairing ' + label, 'rows': len(a)})
    frozen = {}
    for pattern in ['r14_*.gd', 'r15_*.gd', 'r16_run_*.gd', 'r16_ghost.gd', 'r16_experiment_player.gd', 'r19_tether*.gd']:
        for path in (source / 'scripts').glob(pattern):
            old = subprocess.check_output(['git', 'show', BASE + ':projects/foldrunner/scripts/' + path.name], cwd=repo)
            assert hashlib.sha256(old).hexdigest() == sha(path), path.name
            frozen['scripts/' + path.name] = sha(path)
    result = {'ok': True, 'checks': results, 'recordings': recordings, 'frozen_sources': frozen, 'baseline': BASE, 'baseline_sha256': sha(out / 'r19_tether_player.gd'), 'limits': ['headless scene and Dummy activation only; parent owns native appearance/listening/feel', 'range is an explicitly labelled collision-free extreme initial tangential-velocity fixture', 'routes prove one earned input line per model, not discoverability or enjoyment']}
    (out / 'AUDIT.json').write_text(json.dumps(result, indent=2))
    print('AUDIT', len(results), 'checks,', len(recordings), 'recordings', flush=True)
    return result


def cross_reader(reader, wire, recordings):
    rec = reader.read(Path(wire['path']))
    assert rec.ok and wire['ok'], rec.errors
    reread = json.loads(gzip.decompress(Path(READER_WIRES[wire['path']]['wire']).read_bytes()))
    assert READER_WIRES[wire['path']]['sha256'] == sha(wire['path']) and reread['ok']
    for key in ['header', 'seal', 'events', 'inputs']:
        assert equivalent(getattr(rec, key), reread[key]), ('cross-reader', wire['path'], key)
    columns = {k: v for k, v in rec.columns.items() if not any(k.startswith(base + '_') for base in ['p', 'reference_p', 'v', 'actual_v'])}
    for base in ['p', 'reference_p', 'v', 'actual_v']:
        columns[base] = [list(row) for row in zip(*(rec.columns[base + '_' + axis] for axis in 'xyz'))]
    assert equivalent(columns, reread['columns']), ('cross-reader', wire['path'], 'all motion columns')
    assert [row['q'] for row in rec.events] == list(range(len(rec.events)))
    recordings.append({'path': wire['path'], 'sha256': sha(wire['path']), 'ticks': len(rec.columns['tick']), 'input_rows': len(rec.inputs['tick']), 'events': len(rec.events)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--only', default='component,routes')
    parser.add_argument('--keep-source', action='store_true')
    parser.add_argument('--audit-only', action='store_true')
    args = parser.parse_args()
    out = args.out.resolve()
    if args.audit_only:
        audit(out / 'source', out, PROJECT)
        return
    source = run_suite(out, args.only)
    if not args.keep_source:
        shutil.rmtree(source)
        shutil.rmtree(out / 'profiles', ignore_errors=True)


if __name__ == '__main__':
    main()
