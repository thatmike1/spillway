#!/usr/bin/env python3
"""sequential pinned-engine export acceptance; private input bytes are read only and cleaned."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import resource as posix_limits
import signal
import shutil
import subprocess
import sys
import time
import zipfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
CAP = 350 * 2**20
FLOOR = 15_000_000_000
PINS = {"scripts/r16_run_recorder.gd": "", "scripts/r16_run_reader.gd": "", "tools/analyze-r16-runs.py": ""}


def sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def write(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')


def inventory(root):
    return {str(p.relative_to(root)): {'size': p.stat().st_size, 'sha256': sha(p)} for p in root.rglob('*') if p.is_file()}


def same_json(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same_json(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same_json(x, y) for x, y in zip(a, b))
    if type(a) in (int, float) and type(b) in (int, float):
        return math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-13)
    return a == b


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--private-source', type=Path)
    a = p.parse_args()
    out = a.out.resolve()
    assert not out.exists(), 'fresh external directory required; failed evidence stays labelled'
    assert PROJECT not in out.parents
    out.mkdir(parents=True)
    source = out / 'source'
    checks, commands = [], []
    resources = {'peak_owned_bytes': 0, 'minimum_home_free': shutil.disk_usage('/home').free}
    live_link = (os.readlink(PROJECT / '.godot'), (PROJECT / '.godot').stat().st_ino)
    def resource():
        size = sum(f.stat().st_size for f in out.rglob('*') if f.is_file())
        resources['peak_owned_bytes'] = max(size, resources['peak_owned_bytes'])
        resources['minimum_home_free'] = min(resources['minimum_home_free'], shutil.disk_usage('/home').free)
        assert size < CAP and resources['minimum_home_free'] >= FLOOR, 'owned resource bounds exceeded'
    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})
        assert ok, label
    resource()
    shutil.copytree(PROJECT, source, ignore=lambda folder, names: [n for n in names if n in {'.godot', '__pycache__'} or n.endswith('.pyc')])
    shutil.copytree(PROJECT / '.godot', source / '.godot')
    source_hashes = inventory(source)
    write(out / 'SOURCE.json', {'engine': str(ENGINE), 'engine_sha256': sha(ENGINE), 'files': source_hashes})
    env = os.environ.copy()
    for key in ['DATA', 'CONFIG', 'CACHE']:
        env['XDG_' + key + '_HOME'] = str(out / 'profiles' / key.lower())
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    def run(label, command, timeout=180, allow_errors=False, preexec_fn=None):
        resource()
        log = out / (label + '.log')
        with log.open('w') as f:
            proc = subprocess.Popen([str(c) for c in command], stdout=f, stderr=subprocess.STDOUT, cwd=source, env=env, preexec_fn=preexec_fn)
            try:
                result = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=10)
                raise
        text = log.read_text()
        commands.append({'label': label, 'command': [str(c) for c in command], 'exit': result, 'log_sha256': sha(log)})
        check(result == 0 and (allow_errors or not re.search(r'SCRIPT ERROR|^ERROR:', text, re.M)), label)
        print('PASS', label, flush=True)
        resource()
    def engine(label, script, args=(), timeout=180, allow_errors=False):
        run(label, [ENGINE, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', source, '--script', 'res://' + script, '--', '--out=' + str(out / label), *args], timeout, allow_errors=allow_errors)
    for path in PINS:
        baseline = subprocess.check_output(['git', 'show', 'dbd245ed7bb732e995a79362baced2187aab7b2c:projects/foldrunner/' + path], cwd=PROJECT)
        check(hashlib.sha256(baseline).hexdigest() == sha(source / path), 'exact frozen source pin ' + path)
        PINS[path] = sha(source / path)
    for script in sorted((source / 'tests').glob('r20_run_export*.gd')):
        run('parse-' + script.stem, [ENGINE, '--headless', '--path', source, '--script', script, '--check-only'])
    engine('route', 'tests/r20_run_export_route.gd', ['--speed=500'])
    route = json.loads((out / 'route/summary.json').read_text())
    click = json.loads((out / 'route/export-checks.json').read_text())
    check(route['pass'] and click['ok'] and route['finished'] and route['respawns'] == 0, 'export then continued earned clean finish')
    engine('baseline', 'tests/r20_through_route.gd', ['--speed=500'])
    def traces(folder):
        with gzip.open(out / folder / 'trace.jsonl.gz', 'rt') as f:
            return [json.loads(line) for line in f]
    actual, baseline = traces('route'), traces('baseline')
    # motion includes diagnostic/audio state; compare all body, view, timer, style and progress columns.
    fields = ['tick', 'p', 'reference_p', 'v', 'yaw', 'pitch', 'grounded', 'checkpoint', 'elapsed', 'respawns', 'style', 'session_tick', 'attempts']
    # the deliberate restart fixture increments attempts once; normalize only this known counter.
    def gameplay(rows):
        result = []
        for row in rows:
            sample = {k: row[k] for k in fields if k not in ('attempts', 'style')}
            style = json.loads(json.dumps(row['style']))
            # fixture restart identity and observational pause/resume diagnostics are expected differences.
            style.pop('context')
            style['diag'].pop('discontinuities')
            sample['style'] = style
            result.append(sample)
        return result
    compare, expected = gameplay(actual), gameplay(baseline)
    check(compare == expected, 'every route physical/view/scoring/clock/progress sample exactly equals no-export route; fixture context and pause diagnostics labelled separately')
    check(all(r['attempts'] == s['attempts'] + 1 for r, s in zip(actual, baseline)), 'only attempt counter difference is explicit pre-route restart fixture')
    run('transport', [sys.executable, '-I', source / 'tests/test_r20_run_export.py', '--fixture', out / 'route', '--out', out / 'transport'])
    engine('direction', 'tests/r20_run_export_direction.gd')
    check(json.loads((out / 'direction/export-direction.json').read_text())['ok'] and json.loads((out / 'direction/summary.json').read_text())['ok'], 'earned pending stack preserved then banked')
    engine('errors', 'tests/r20_run_export_errors.gd', allow_errors=True)
    check(json.loads((out / 'errors/summary.json').read_text())['ok'], 'writer failure/race/bounds controls')
    disk = out / 'disk-io'
    (disk / 'runs').mkdir(parents=True)
    (disk / 'runs/random.r16run').write_bytes(os.urandom(256 * 1024))
    def file_limit():
        signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
        posix_limits.setrlimit(posix_limits.RLIMIT_FSIZE, (65536, 65536))
    run('disk-io', [ENGINE, '--headless', '--audio-driver', 'Dummy', '--path', source, '--script', 'res://tests/r20_run_export_disk.gd', '--', '--out=' + str(disk)], allow_errors=True, preexec_fn=file_limit)
    check(json.loads((disk / 'summary.json').read_text())['ok'], 'actual OS ZIP write failure cleans output and preserves sources')
    engine('godot-readers', 'tests/r20_run_export_readers.gd', ['--root=' + str(out / 'route/recordings')])
    sys.path.insert(0, str(source / 'tools'))
    import r20_run_bundle as bundle
    reader, reader_hash = bundle.load_reader()
    for path in (out / 'route/recordings').glob('*.r16run'):
        if path.name in ('malformed.r16run', 'unsupported.r16run', 'damaged-seal.r16run'):
            continue
        rec = reader.read(path)
        check(rec.ok, 'original Python strict reader accepts continued sealed ' + path.name)
    # a saved-input replay of the exported-then-finished recording uses the original reader.
    complete = [reader.read(p) for p in (out / 'route/recordings').glob('*.r16run') if p.name not in ('malformed.r16run', 'unsupported.r16run', 'damaged-seal.r16run')]
    final = next(r for r in complete if (r.seal.get('outcome') or {}).get('kind') == 'finish')
    hz = 128
    inputs = []
    for i in range(len(final.inputs['tick'])):
        row = {name: final.inputs[name][i] for name in final.inputs}
        if row['kind'] in (1, 2, 3):
            inputs.append({'tick': row['tick'] - 33, 'raw': row})
    tape_path = out / 'recorded-input.tape.json'
    write(tape_path, {'version': 2, 'physics_hz': 128, 'duration_ticks': len(final.columns['tick']) - 33, 'events': inputs})
    engine('replay', 'tests/r20_through_route.gd', ['--speed=500', '--tape=' + str(tape_path)])
    replay = traces('replay')
    check(gameplay(replay) == compare, 'continued finish remains exactly input-replayable')
    replay_summary = json.loads((out / 'replay/summary.json').read_text())
    replay_rec = reader.read(Path(replay_summary['recordings'][0]['path']))
    check(final.columns == replay_rec.columns, 'every binary physical/input-state column replays exactly after export')
    check(final.inputs == replay_rec.inputs, 'complete ordered binary input columns replay exactly after export')
    for row in json.loads((out / 'godot-readers/index.json').read_text()):
        godot = json.loads(gzip.decompress(Path(row['wire']).read_bytes()))
        python = reader.read(Path(row['path']))
        check(godot['status'] == python.status and godot['ok'] == python.ok, 'original readers agree on status including empty ' + Path(row['path']).name)
        if python.ok:
            columns = {k: v for k, v in python.columns.items() if not any(k.startswith(base + '_') for base in ('p', 'reference_p', 'v', 'actual_v'))}
            for base in ('p', 'reference_p', 'v', 'actual_v'):
                columns[base] = [list(v) for v in zip(*(python.columns[base + '_' + axis] for axis in 'xyz'))]
            check(same_json(columns, godot['columns']) and same_json(python.inputs, godot['inputs']), 'original readers agree on all physical columns and ordered inputs ' + Path(row['path']).name)
            check(same_json(godot['header'], python.header) and same_json(godot['seal'], python.seal) and same_json(godot['events'], python.events), 'original readers agree on header/seal/events (JSON spelling tolerance 1e-13) ' + Path(row['path']).name)
    engine('native-seam-headless', 'tests/r20_run_export_native.gd', ['--speed=500'])
    check(json.loads((out / 'native-seam-headless/export-checks.json').read_text())['ok'], 'cross-platform native observational seam exercises actual button headlessly')
    style_baseline = out / 'r19_style.gd'
    style_baseline.write_bytes(subprocess.check_output(['git', 'show', '065f7b27993df7ae2511eb34eb665d271dded13c:projects/foldrunner/scripts/r16_style.gd'], cwd=PROJECT))
    for label, script in [('source-motion', 'test_r14_source_motion.gd'), ('source-player', 'test_r14_source_player.gd'), ('crouch', 'test_r15_crouch.gd'), ('directional-laws', 'r20_style_stack.gd'), ('tether-laws', 'r20_tether_component.gd'), ('shelved', 'r20_shelved.gd')]:
        args = ['--baseline=' + str(style_baseline), '--cases=pause,pause_invalid,settings'] if label == 'directional-laws' else []
        engine(label, 'tests/' + script, args)
    engine('record-format', 'tests/test_r16_record.gd', allow_errors=True)
    env['R16_SCRATCH'] = str(out / 'format-python')
    run('format-python', [sys.executable, '-I', source / 'tests/test_r16_record_format.py', '--run', out / 'record-format', '--out', out / 'format-python/summary.json', '--log', out / 'record-format.log', '--godot', ENGINE, '--project', source])
    run('preservation-controls', [sys.executable, '-B', source / 'tests/test_r20_preservation.py'])
    # empty attempts are preserved; malformed neighbours intentionally do not enter strict-complete scan.
    private_receipt = None
    if a.private_source:
        private = a.private_source.resolve()
        before = inventory(private)
        private_out = out / 'private'
        imports = out / 'private-import'
        try:
            engine('private', 'tests/r20_run_export_private.gd', ['--source=' + str(private)])
            exported = json.loads((private_out / 'result.json').read_text())
            check(exported['ok'], 'private read-only service export')
            result = bundle.ingest(Path(exported['path']), imports, 'Private completeness proof')
            target = Path(result['path'])
            report = json.loads((target / 'analysis.json').read_text())
            with zipfile.ZipFile(exported['path']) as z:
                recordings = [e for e in exported['manifest']['entries'] if e['path'].startswith('recordings/')]
                settings = [e for e in exported['manifest']['entries'] if e['path'].startswith('settings/') and e['path'] != 'settings/effective-settings.json']
                check(len(recordings) == 90 and len(settings) == 5, 'all 90 private recordings and all five settings files')
                for entry in recordings + settings:
                    rel = entry['path'].removeprefix('recordings/') if entry in recordings else entry['path'].removeprefix('settings/')
                    src = private / 'r16_runs' / rel if entry in recordings else private / rel
                    data = z.read(entry['path'])
                    check(hashlib.sha256(data).hexdigest() == sha(src) == sha(target / entry['path']) and len(data) == src.stat().st_size, 'private exact exported/imported bytes ' + entry['path'])
            after = inventory(private)
            check(before == after, 'every private input/settings/cache hash unchanged')
            private_receipt = {'source': str(private), 'before': before, 'after_equal': before == after, 'recordings': len(recordings), 'settings': len(settings), 'bundle_sha256': sha(exported['path']), 'import_sha256': json.loads((target / 'import.json').read_text())['import_sha256'], 'classifications': [{'path': r['file'], 'sha256': r['sha256'], 'classification': r['classification'], 'sample_count': r['sample_count'], 'outcome_kind': (r.get('outcome') or {}).get('kind')} for r in report['attempts']], 'effective_settings_seam': 'empty dictionary: no private game instantiated; all five actual persisted settings files retained byte-exactly', 'private_duplicates_removed': [str(private_out), str(imports)]}
        finally:
            if private_out.exists():
                shutil.rmtree(private_out)
            if imports.exists():
                shutil.rmtree(imports)
            check(before == inventory(private), 'private inputs unchanged after duplicate cleanup')
    check(all(sha(PROJECT / name) == value['sha256'] for name, value in source_hashes.items() if name.startswith(('scripts/r20_run_export', 'tests/r20_run_export', 'tests/test_r20_run_export', 'tools/r20_run_bundle', 'tools/ingest-r20-runs')) or name in ('scripts/r20_main.gd', 'scripts/r20_hud.gd')), 'executed owned files equal current checkout')
    check(live_link == (os.readlink(PROJECT / '.godot'), (PROJECT / '.godot').stat().st_ino), 'live .godot symlink and target inode unchanged')
    resource()
    write(out / 'PRIVATE-RECEIPT.json', private_receipt)
    write(out / 'COMMANDS.json', commands)
    write(out / 'RESOURCES.json', resources)
    write(out / 'CONTRACT.json', {'ok': True, 'checks': checks, 'pins': PINS, 'click_checks': len(click['checks']), 'transport_checks': len(json.loads((out / 'transport/summary.json').read_text())['checks']), 'route_samples': len(actual), 'elapsed': route['elapsed'], 'active_ticks': click['active_ticks'], 'buffered_tail': click['buffered_tail'], 'resources': resources, 'private': None if private_receipt is None else {'recordings': 90, 'settings': 5, 'hashes_unchanged': True, 'duplicates_removed': True}, 'native': 'parent-owned native/Wine proof; tests/r20_run_export_native.gd is the observational seam; no display/file manager/clipboard/speaker used', 'limits': {'files': bundle.MAX_FILES, 'file_bytes': bundle.MAX_FILE, 'total_data_bytes': bundle.MAX_TOTAL, 'stream_chunk': bundle.CHUNK, 'manifest_bytes': bundle.MAX_MANIFEST, 'home_floor': FLOOR}})
    shutil.rmtree(source)
    shutil.rmtree(out / 'profiles')
    print('ACCEPTED', out / 'CONTRACT.json', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
