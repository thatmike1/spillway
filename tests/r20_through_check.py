#!/usr/bin/env python3
"""bounded sequential production Through Line proof, strict saved-input replay and compact contract."""
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
OWNED = ['scripts/r20_main.gd', 'scripts/r20_map_catalog.gd', 'scripts/r20_hud.gd']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n')


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    sys.modules[name] = result
    spec.loader.exec_module(result)
    return result


def trace(path):
    with gzip.open(path, 'rt') as stream:
        return [json.loads(line) for line in stream]


def same(a, b):
    # godot JSON's decimal spelling loses at most a final double digit. Binary replay
    # comparisons below use exact column equality, with no numerical tolerance.
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if type(a) in (int, float) and type(b) in (int, float):
        return math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-13)
    return a == b


class Proof:
    def __init__(self, out, scratch):
        self.out, self.scratch = out, scratch
        self.source = scratch / 'source'
        assert not out.exists(), 'use a fresh output directory; failed evidence is retained'
        out.mkdir(parents=True)
        assert shutil.disk_usage('/home').free >= FLOOR
        self.link = {'target': os.readlink(PROJECT / '.godot'), 'inode': (PROJECT / '.godot').stat().st_ino}
        if not self.source.exists():
            shutil.copytree(PROJECT, self.source, ignore=lambda folder, names: [n for n in names if n in {'.godot', '__pycache__'} or n.endswith('.pyc')])
            shutil.copytree(PROJECT / '.godot', self.source / '.godot')
        else:
            for path in [*PROJECT.glob('scripts/r20*.gd'), *PROJECT.glob('tests/r20_through*')]:
                shutil.copy2(path, self.source / path.relative_to(PROJECT))
        documentation = PROJECT / "docs/r20/THROUGH-LINE.md"
        if documentation.exists():
            shutil.copy2(documentation, self.source / "docs/r20/THROUGH-LINE.md")
        if not (self.source / 'look').exists():
            shutil.copytree(PROJECT / 'look', self.source / 'look')
        self.env = os.environ.copy()
        for key in ['DATA', 'CONFIG', 'CACHE']:
            self.env['XDG_' + key + '_HOME'] = str(scratch / 'profiles-final' / key.lower())
        self.attempts = []
        self.peak = 0
        self.minimum = shutil.disk_usage('/home').free
        self.reader = load('through_original_reader', self.source / 'tools/analyze-r16-runs.py')
        self.checks = []
        self.resources()
        self.sources = {str(p.relative_to(self.source)): sha(p) for p in self.source.rglob('*') if p.is_file() and '.godot' not in p.parts}
        write(out / 'SOURCE.json', {'sha256': self.sources, 'engine': str(ENGINE), 'engine_sha256': sha(ENGINE), 'parent': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip()})

    def resources(self):
        self.peak = max(self.peak, sum(p.stat().st_size for p in self.scratch.rglob('*') if p.is_file()))
        self.minimum = min(self.minimum, shutil.disk_usage('/home').free)
        assert self.peak <= CAP and self.minimum >= FLOOR, 'resource budget reached before further work'

    def run(self, label, script, args=(), *, python=None, allow_record_errors=False):
        target = self.out / label
        argv = python or [ENGINE, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', self.source, '--script', 'res://tests/' + script, '--', '--out=' + str(target), *args]
        argv = list(map(str, argv))
        self.resources()
        start = time.monotonic()
        with (self.out / (label + '.log')).open('x') as log:
            proc = subprocess.Popen(argv, cwd=self.source, env=self.env, stdout=log, stderr=subprocess.STDOUT)
            while proc.poll() is None:
                try:
                    self.resources()
                    assert time.monotonic() - start < 180, 'engine deadline reached'
                except BaseException:
                    proc.terminate()
                    proc.wait(timeout=10)
                    raise
                time.sleep(.25)
        log = (self.out / (label + '.log')).read_text()
        errors = [line for line in log.splitlines() if line.startswith('ERROR:')]
        expected = allow_record_errors and len(errors) == 5 and all(any(text in line for text in [
            'header metadata is 70362 bytes, above the 65536 byte bound', 'test hook: write refused after 3000 bytes',
            'Could not create directory:', 'cannot create recording directory', 'cannot open '
        ]) for line in errors) and read(target / 'summary.json')['failed'] == 0
        ok = proc.returncode == 0 and not re.search(r'SCRIPT ERROR:|ObjectDB instances leaked', log) and (not errors or expected)
        self.attempts.append({'label': label, 'ok': ok, 'exit': proc.returncode, 'argv': argv, 'seconds': time.monotonic() - start, 'expected_recorder_errors': expected})
        write(self.out / 'ATTEMPTS.json', self.attempts)
        print(label, 'PASS' if ok else 'FAIL', flush=True)
        if not ok:
            print(log[-8000:], flush=True)
            raise AssertionError(label)
        return target

    def check(self, condition, label, **data):
        self.checks.append({'ok': bool(condition), 'check': label, **data})
        assert condition, label

    def route(self, label, speed):
        target = self.run(label, 'r20_through_route.gd', ['--speed=' + str(speed)])
        result = read(target / 'summary.json')
        self.check(result['pass'] and result['clean'] and result['respawns'] == 0, label + ' input-earned whole route')
        rec = self.reader.read(Path(result['recordings'][0]['path']))
        self.check(rec.ok and rec.seal['outcome']['kind'] == 'finish', label + ' original Python reader accepts clean recording')
        events = []
        assert set(rec.inputs['kind']) <= {1, 2, 3, 4}
        for i, kind in enumerate(rec.inputs['kind']):
            if kind in {1, 2, 3}:
                row = {k: v[i] for k, v in rec.inputs.items()}
                assert row['tick'] >= 33
                events.append({'tick': row['tick'] - 33, 'raw': row})
        tape = self.out / (label + '-recorded.tape.json')
        write(tape, {'version': 2, 'physics_hz': 128, 'duration_ticks': len(rec.columns['tick']) - 33, 'events': events})
        replay = self.run(label + '-saved-replay', 'r20_through_route.gd', ['--tape=' + str(tape)])
        other = read(replay / 'summary.json')
        replay_rec = self.reader.read(Path(other['recordings'][0]['path']))
        self.check(other['pass'] and rec.columns == replay_rec.columns, label + ' every saved physical column replays exactly', rows=len(rec.columns['tick']))
        self.check(rec.inputs == replay_rec.inputs, label + ' complete ordered key/button/action/mouse columns replay exactly', rows=len(rec.inputs['tick']))
        a, b = trace(target / 'trace.jsonl.gz'), trace(replay / 'trace.jsonl.gz')
        self.check(a == b, label + ' every full precision motion/style/clock/progress observation replays exactly', rows=len(a))
        diagnostic = [e for e in rec.events if e['k'] == 'through']
        self.check([e['d']['kind'] for e in diagnostic] == ['launch', 'apex', 'landing', 'continued'], label + ' exactly one ordered non-scored transition')
        # the frozen event() channel timestamps the last captured tick. motor_tick
        # identifies the next post-step sample explicitly; no format change is needed.
        launch = diagnostic[0]['d']
        land = diagnostic[2]['d']
        apex = diagnostic[1]['d']
        self.check(launch['before_mps'][0::2] == launch['after_mps'][0::2], label + ' exact observed horizontal vector equality')
        self.check(launch['cue']['playing'] and launch['cue']['samples'] == 8379, label + ' actual generated cue activated')
        lo, hi = result['launch']['route_tick'], result['landing']['route_tick']
        flight = a[lo:hi + 1]
        self.check(len(flight) == hi - lo + 1 and all(y['session_tick'] == x['session_tick'] + 1 and y['motion']['tick'] == x['motion']['tick'] + 1 and y['elapsed'] > x['elapsed'] for x, y in zip(flight, flight[1:])), label + ' no runner or clock reset during complete flight')
        self.check(all(x['respawns'] == 0 and x['attempts'] == a[0]['attempts'] for x in a), label + ' zero lifecycle resets through whole route')
        self.check(all(x['v'][0::2] == launch['after_mps'][0::2] for x in flight), label + ' flight preserves incoming horizontal vector until landing')
        self.check(not any(e['k'] == 'lifecycle' and e['d'].get('kind') in ['respawn', 'restart', 'practice', 'map', 'preset'] for e in rec.events), label + ' no intervening lifecycle boundary')
        self.check(a[hi]['grounded'] and land['support']['body'].startswith('second_start_') and land['support']['normal'][1] == 1 and apex['p'][1] > land['p'][1], label + ' actual physical raised second-segment landing after flight')
        return {'elapsed': result['elapsed'], 'ticks': len(a), 'speed_u': launch['speed_u'], 'launch': launch, 'apex': apex, 'landing': land,
                'rise_m': apex['p'][1] - launch['p'][1], 'distance_m': math.dist(land['reference_p'][0::2], launch['reference_p'][0::2]),
                'recording': str(rec.path), 'recording_sha256': sha(rec.path), 'input_rows': len(rec.inputs['tick']), 'identity': result['identity']}

    def cross_read(self):
        index = read(self.out / 'readers/index.json')
        results = []
        for wire in index:
            rec = self.reader.read(Path(wire['path']))
            other = json.loads(gzip.decompress(Path(wire['wire']).read_bytes()))
            assert rec.ok and wire['ok'] and other['ok'] and sha(wire['path']) == wire['sha256']
            for key in ['header', 'seal', 'events', 'inputs']:
                assert same(getattr(rec, key), other[key]), (wire['path'], key)
            columns = {k: v for k, v in rec.columns.items() if not any(k.startswith(base + '_') for base in ['p', 'reference_p', 'v', 'actual_v'])}
            for base in ['p', 'reference_p', 'v', 'actual_v']:
                columns[base] = [list(v) for v in zip(*(rec.columns[base + '_' + axis] for axis in 'xyz'))]
            assert same(columns, other['columns']), wire['path']
            assert [e['q'] for e in rec.events] == list(range(len(rec.events)))
            results.append({'path': wire['path'], 'sha256': wire['sha256'], 'ticks': len(rec.columns['tick']), 'inputs': len(rec.inputs['tick']), 'events': len(rec.events)})
        self.check(len(results) >= 40, 'both original strict readers agree on every gameplay/fixture record and all columns', recordings=len(results))
        write(self.out / 'READERS.json', results)

    def preservation(self):
        helper = load('through_preservation', PROJECT / 'tools/check-r20-preservation.py')
        old = helper.archive_manifest(PROJECT.parents[1], BASE)
        parent = helper.archive_manifest(PROJECT.parents[1], read(self.out / 'SOURCE.json')['parent'])
        intentional = {name: parent[name] for name in helper.ALLOWED if name in old and parent[name] != old[name]}
        result = helper.compare(old, self.sources, intentional)
        write(self.out / 'PRESERVATION.json', result)
        self.check(result['ok'], 'all delivered R19 paths preserved with exactly prior accepted exceptions', old_paths=len(old), accepted=intentional)
        live = helper.compare(old, {name: sha(PROJECT / name) for name in old if (PROJECT / name).is_file()}, intentional)
        write(self.out / 'LIVE-PRESERVATION.json', live)
        self.check(live['ok'], 'live checkout also preserves all delivered R19 paths')
        files = OWNED + [str(p.relative_to(PROJECT)) for p in PROJECT.glob('scripts/r20_through*')] + [str(p.relative_to(PROJECT)) for p in PROJECT.glob('tests/r20_through*')]
        self.check(all(self.sources.get(p) == sha(PROJECT / p) for p in files), 'executed owned source equals final checkout')
        self.check(os.readlink(PROJECT / '.godot') == self.link['target'] and (PROJECT / '.godot').stat().st_ino == self.link['inode'], 'live import symlink and target inode preserved')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--scratch', type=Path, required=True)
    parser.add_argument('--keep-source', action='store_true')
    args = parser.parse_args()
    out, scratch = args.out.resolve(), args.scratch.resolve()
    assert out != scratch and scratch in out.parents and not PROJECT in out.parents
    proof = Proof(out, scratch)
    proof.run('component', 'r20_through_component.gd')
    proof.run('ordinary', 'r20_through_ordinary.gd')
    proof.run('quit', 'r20_through_quit.gd')
    slow = proof.route('slow', 0)
    fast = proof.route('fast', 500)
    proof.check(fast['speed_u'] > slow['speed_u'] and fast['rise_m'] > slow['rise_m'] and fast['distance_m'] > slow['distance_m'], 'faster physically earned entry produces more height and distance')
    look = proof.run('moving-look', 'r20_through_route.gd', ['--speed=500', '--look=1'])
    proof.check(trace(look / 'trace.jsonl.gz') == trace(out / 'fast/trace.jsonl.gz'), 'complete route with actual moving L exactly preserves every physical/motion/style observation')
    native = proof.run('native-seam-headless', 'r20_through_native.gd', ['--tape=' + str(out / 'fast-recorded.tape.json')])
    proof.check(trace(native / 'trace.jsonl.gz') == trace(out / 'fast/trace.jsonl.gz'), 'native observational seam parses and replays identical telemetry headlessly; no rendered claim')
    for label, script in [('source-motion', 'test_r14_source_motion.gd'), ('source-player', 'test_r14_source_player.gd'), ('crouch', 'test_r15_crouch.gd')]:
        proof.run(label, script)
    proof.run('ghosts', 'r20_through_ghosts.gd')
    proof.run('record-format', 'test_r16_record.gd', allow_record_errors=True)
    proof.env['R16_SCRATCH'] = str(out / 'format-python')
    proof.run('format-python', '', python=[sys.executable, '-I', proof.source / 'tests/test_r16_record_format.py', '--run', out / 'record-format', '--out', out / 'format-python/summary.json', '--log', out / 'record-format.log', '--godot', ENGINE, '--project', proof.source])
    for name in ['test_r20_preservation.py']:
        proof.run(name, '', python=[sys.executable, '-B', proof.source / 'tests' / name])
    proof.run('readers', 'r20_through_readers.gd', ['--root=' + str(out)])
    proof.cross_read()
    proof.preservation()
    for label in ['component', 'ordinary', 'quit', 'ghosts']:
        summary = read(out / label / 'summary.json')
        proof.check(summary['ok'], label + ' all component assertions pass', assertions=len(summary['checks']))
    proof.resources()
    write(out / 'RESOURCES.json', {'peak_own_scratch_bytes': proof.peak, 'minimum_home_bytes': proof.minimum, 'cap': CAP, 'floor': FLOOR, 'live_import': proof.link})
    write(out / 'ROUTES.json', {'slow': slow, 'fast': fast})
    write(out / 'AUDIT.json', {'ok': True, 'checks': proof.checks})
    print('Through Line accepted:', len(proof.checks), 'audit checks;', len(read(out / 'READERS.json')), 'recordings', flush=True)
    if not args.keep_source:
        shutil.rmtree(proof.source)
        shutil.rmtree(scratch / 'profiles-final', ignore_errors=True)


if __name__ == '__main__':
    main()
