#!/usr/bin/env python3
"""bounded isolated R15-host geometry/parity/physical proofs for the R16 overlay."""
import argparse
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
OUTER = PROJECT.parents[2]
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
ENGINE_SHA = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
CAP = 300 * 1024 * 1024


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    spec = importlib.util.spec_from_file_location('opportunities_owner_' + path.stem.replace('-', '_'), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())


def physics(rows):
    """exclude only draw observations and wall time; preserve every physics/input field."""
    def clean(value):
        if isinstance(value, dict):
            return {key: clean(v) for key, v in value.items() if key != 'wall_us'}
        if isinstance(value, list):
            return [clean(v) for v in value]
        return value
    result = []
    for row in rows:
        sample = clean({key: row[key] for key in ['phase', 'tick', 'step', 'pre', 'keys', 'mouse', 'rate', 'hull_origin', 'game_pre', 'post', 'game'] if key in row})
        sample.get('post', {}).pop('camera', None)
        result.append(sample)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--mode', choices=['geometry', 'parity', 'extended', 'trials', 'native', 'all'], default='all')
    parser.add_argument('--case', default='')
    parser.add_argument('--preset', default='server128')
    parser.add_argument('--keep-scratch', action='store_true', help='development only; final evidence must remove it')
    args = parser.parse_args()
    out = args.out.resolve()
    assert not out.is_relative_to(PROJECT)
    out.mkdir(parents=True, exist_ok=True)
    assert sha(ENGINE) == ENGINE_SHA
    owner = load(PROJECT / 'tools/package-r15.py')
    work = Path(tempfile.mkdtemp(prefix='r16-opportunities-', dir='/dev/shm'))
    source = work / 'source'
    source.mkdir()
    tracked = [Path(os.fsdecode(p)) for p in subprocess.check_output(['git', 'ls-files', '-z', '--', '.'], cwd=PROJECT).split(b'\0') if p]
    extra = [p.relative_to(PROJECT) for pattern in ['scripts/r16_style_opportunities.gd*', 'tests/r16_opportunities*', 'tests/test_r16_opportunities*', 'scripts/r16_style.gd', 'scripts/r16_style_panel.gd', 'tests/r16_style_probe.gd'] for p in PROJECT.glob(pattern) if p.is_file()]
    files = sorted(set(tracked + extra))
    before = {str(p): sha(PROJECT / p) for p in files}
    result = {'label': 'new R15-host wrapper, overlay appended after old build; not actual R16 acceptance', 'engine_sha256': ENGINE_SHA, 'source_sha256': before, 'runs': [], 'scratch': str(work)}
    try:
        for rel in files:
            dest = source / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(PROJECT / rel, dest)
        env = owner.engine_env(work / 'profile')

        def run(name, script, options=(), fixed=True, budget=150, extra_engine=(), native_env=None, watch=None):
            argv = [str(ENGINE), *([] if native_env else ['--headless']), '--audio-driver', 'Dummy']
            if fixed:
                argv += ['--fixed-fps', '128']
            argv += ['--path', str(source), *extra_engine]
            if script:
                argv += ['--script', script, '--', *options]
            code, text = owner.run_engine(argv, source, native_env or env, out / (name + '.log'), budget, watch)
            result['peak_checked_scratch_bytes'] = max(result.get('peak_checked_scratch_bytes', 0), size(work))
            assert size(work) <= CAP, ('RAM cap', size(work))
            assert code == 0 and not owner.ERRORS.search(text), (name, code, text[-5000:])
            return text

        run('import', '', fixed=False, extra_engine=['--editor', '--import', '--quit'])
        for rel in extra:
            if rel.suffix == '.gd' and (source / (str(rel) + '.uid')).exists() and not (PROJECT / (str(rel) + '.uid')).exists():
                # only this task's files may acquire uids in the shared checkout.
                if rel.name.startswith(('r16_opportunities', 'test_r16_opportunities', 'r16_style_opportunities')):
                    shutil.copy2(source / (str(rel) + '.uid'), PROJECT / (str(rel) + '.uid'))
        if args.mode in ['geometry', 'all']:
            run('geometry', 'res://tests/test_r16_opportunities.gd', ['--out=' + str(out / 'geometry.json')])
            result['geometry'] = json.loads((out / 'geometry.json').read_text())
        if args.mode in ['parity', 'extended', 'all']:
            manifest = OUTER / 'checkpoints/spillway/r15/release-plan/ROUTES.json'
            result['route_manifest_sha256'] = sha(manifest)
            routes = json.loads(manifest.read_text())
            if args.mode == 'extended':
                routes = []
                release = OUTER / 'checkpoints/spillway/r15'
                for name in ['server128-earned', 'server128-alley_recovery', 'server128-harbour_recovery', 'server128_aa1000-ordinary']:
                    folder = release / 'breakwater-r15-host/final-port' / name / 'executor/evaluator'
                    routes.append({'name': 'extra-breakwater-' + name, 'map': 'breakwater', 'preset': name.split('-', 1)[0], 'folder': folder})
                for name in ['earned', 'f5-earned', 'f5-ordinary', 'basin_recovery', 'cloud_recovery']:
                    folder = release / 'whiteout-integration/replays' / name / 'evaluator'
                    routes.append({'name': 'extra-whiteout-' + name, 'map': 'whiteout-relay', 'preset': 'server128_aa1000' if name.startswith('f5') else 'server128', 'folder': folder})
                for route in routes:
                    tape = route.pop('folder') / 'plan.json'
                    reference = tape.with_name('trace.jsonl.gz')
                    route['spec'] = f"map={route['map']},preset={route['preset']},tape={tape},warmup=33"
                    route['reference'] = str(reference)
                    route['tape_sha256'] = sha(tape)
                    route['reference_sha256'] = sha(reference)
            for route in routes:
                values = dict(pair.split('=', 1) for pair in route['spec'].split(','))
                if values['map'] not in ['breakwater', 'whiteout-relay']:
                    continue
                if args.case and args.case not in route['name']:
                    continue
                dest = out / route['name']
                dest.mkdir(exist_ok=True)
                runtime_output = work / 'trace-output' / route['name']
                assert sha(Path(values['tape'])) == route['tape_sha256']
                assert sha(Path(route['reference'])) == route['reference_sha256']
                options = ['--out=' + str(runtime_output), '--game-script=res://tests/r16_opportunities_host.gd', '--game-class=', '--motor=' + values['preset'], '--r15-map=' + values['map'], '--tape=' + values['tape'], '--warmup=' + values.get('warmup', '33'), '--physics-hz=128', '--frames=none', '--wall-budget-s=130']
                run(route['name'], 'res://tools/momentum-tape.gd', options)
                raw = runtime_output / 'evaluator/trace.jsonl'
                actual = [json.loads(line) for line in raw.read_text().splitlines() if line.strip()]
                expected = [json.loads(line) for line in gzip.open(route['reference'], 'rt') if line.strip()]
                # discard drawing/wall-clock counters, compare all actual movement, hull, keys,
                # contacts, progress and clock samples at the original host's tape boundaries.
                a, b = physics(actual), physics(expected)
                mismatch = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), None)
                exact_trace = len(a) == len(b) and mismatch is None
                contact_differences = []
                for index, (x, y) in enumerate(zip(a, b)):
                    ca = x.get('post', {}).get('motion_state', {}).pop('contacts', [])
                    cb = y.get('post', {}).get('motion_state', {}).pop('contacts', [])
                    if ca != cb:
                        contact_differences.append({'row': index, 'tick': x['tick'], 'p': x['post']['p'], 'actual': ca, 'reference': cb})
                movement_mismatch = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), None)
                exact_movement = len(a) == len(b) and movement_mismatch is None
                (dest / 'CONTACT-DIFFERENCES.json').write_text(json.dumps(contact_differences, indent=2))
                receipt = {'name': route['name'], 'ticks_including_warmup': len(a), 'reference_ticks': len(b), 'exact_physics_parity': exact_trace, 'first_mismatch_row': mismatch,
                           'exact_movement_parity': exact_movement, 'movement_first_mismatch_row': movement_mismatch, 'contact_difference_rows': len(contact_differences),
                           'contact_differences_are_only_walkable_original_support': all(c['normal'][1] >= 0.999 and c['body'].startswith('s') for d in contact_differences for c in d['actual'] + d['reference']),
                           'tape_sha256': route['tape_sha256'], 'reference_sha256': route['reference_sha256']}
                if mismatch is not None:
                    (dest / 'mismatch.json').write_text(json.dumps({'actual': a[mismatch], 'reference': b[mismatch]}, indent=2))
                with gzip.open(dest / 'trace.jsonl.gz', 'wb') as zipped:
                    zipped.write(raw.read_bytes())
                raw.unlink()
                for path in ['end.json', 'evaluator/engine.json']:
                    if (runtime_output / path).exists():
                        shutil.copy2(runtime_output / path, dest / Path(path).name)
                shutil.rmtree(runtime_output)
                (dest / 'PARITY.json').write_text(json.dumps(receipt, indent=2))
                result['runs'].append(receipt)
                print(json.dumps(receipt), flush=True)
        if args.mode in ['trials', 'all']:
            cases = ['breakwater-crouch', 'breakwater-stand', 'whiteout-crouch', 'whiteout-stand', 'breakwater-thread', 'breakwater-normal', 'whiteout-normal']
            if args.case:
                cases = args.case.split(',')
            for case in cases:
                dest = out / case
                dest.mkdir(exist_ok=True)
                text = run(case, 'res://tests/r16_opportunities_driver.gd', ['--out=' + str(dest), '--case=' + case, '--preset=' + args.preset])
                result['runs'].append(json.loads((dest / 'opportunity.json').read_text()))
                print(text[-1300:], flush=True)
        if args.mode == 'native':
            assert shutil.disk_usage(Path.home()).free >= 15 * 1024**3, 'HOME below 15 GiB native floor'
            native = load(PROJECT / 'tools/r14_native_display.py')
            cases = args.case.split(',') if args.case else ['breakwater-crouch', 'whiteout-crouch', 'breakwater-thread', 'breakwater-normal']
            with native.NativeDisplay(out / 'display', displays=(198,)) as display:
                for case in cases:
                    dest = out / case
                    dest.mkdir(exist_ok=True)
                    watch = native.GpuWatch()
                    text = run(case, 'res://tests/r16_opportunities_driver.gd', ['--out=' + str(dest), '--case=' + case, '--capture=yes'], native_env=display.child_env(env), watch=watch, extra_engine=['--rendering-method', 'gl_compatibility', '--display-driver', 'x11', '--resolution', '1280x720', '--windowed'])
                    watch.require()
                    native.require_amd_log(text)
                    result['runs'].append(json.loads((dest / 'opportunity.json').read_text()))
        # full contact trace differences remain explicit, even when movement is bit identical.
        result['ok'] = all(r.get('exact_movement_parity', True) and r.get('contact_differences_are_only_walkable_original_support', True) for r in result['runs'])
    finally:
        result['owned_source_unchanged_during_run'] = all(sha(PROJECT / p) == digest for p, digest in before.items() if p.startswith(('tests/r16_opportunities', 'tests/test_r16_opportunities', 'scripts/r16_style_opportunities')))
        result['base_source_unchanged_during_run'] = all(sha(PROJECT / str(p)) == before[str(p)] for p in tracked)
        result['style_sha256_at_end'] = sha(PROJECT / 'scripts/r16_style.gd')
        if not args.keep_scratch:
            shutil.rmtree(work)
        result['scratch_removed'] = not work.exists()
        result['evidence_bytes'] = size(out)
        (out / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    assert result['ok']
    assert result['evidence_bytes'] <= 50 * 1024 * 1024


if __name__ == '__main__':
    main()
