#!/usr/bin/env python3
"""final R21 delivery adapters. Execution is owned by package-r21's explicit gate.

Component fixtures are re-earned on the complete frozen source. Packed acceptance
reads the pinned external probe's actual all-map controls and strict replay audits.
No component receipt, synthetic route or historical seam can confer acceptance.
"""
import copy
import gzip
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import subprocess
import sys

sys.dont_write_bytecode = True
MODELS = ('classic', 'pendulum', 'elastic', 'elastic-soft', 'elastic-firm', 'elastic-arc')
COMMON = ('tools/package-r21.py', 'tools/r21-pack-probe.gd',
          'tools/r21-delivery-components.py', 'tests/test_r21_delivery_components.py',
          'scripts/r21_main.gd', 'scripts/r21_map_catalog.gd', 'scripts/r21_hud.gd', 'scenes/r21.tscn')
SALT = ('scripts/r21_surf_level.gd', 'tests/r21_surf_route.gd', 'tests/r21_surf_geometry.gd',
        'tests/r21_surf_geometry_negative.gd', 'tests/r21_surf_integration.gd',
        'tests/r21_surf_probes.gd', 'tests/r21_surf_skill.gd', 'tests/r21_surf_exit.gd',
        'tests/r21_surf_ghost.gd', 'tests/r21_surf_audit.py', 'tests/r21_surf_matches.py',
        'tests/r21_surf_check.py')
TETHER = ('scripts/r21_tether_player.gd', 'scripts/r21_tether_level.gd',
          'tests/r21_tether_route.gd', 'tests/r21_tether_component.gd',
          'tests/r21_tether_boundaries.gd', 'tests/r21_tether_geometry.gd',
          'tests/r21_tether_reload.gd', 'tests/r21_tether_readers.gd',
          'tests/r21_tether_audit.py', 'tests/r21_tether_adapter.gd',
          'tests/r20_tether_check.py', 'tests/r20_tether_readers.gd',
          'tests/r20_tether_component.gd')
PARITY = ('tools/check-r21-parity.py', 'tools/r21_parity_core.py',
          'tests/r21_parity.gd', 'tests/r21_parity_audit.py',
          'tests/test_r21_parity.py', 'docs/r21/PARITY.md')
PATHS = {name: tuple(dict.fromkeys(COMMON + paths)) for name, paths in
         [('saltglass', SALT), ('tether', TETHER), ('parity', PARITY)]}
PARITY_ROOT = Path('/tmp/r21-candidate-parity')
PARITY_BASELINE = Path('/tmp/r21-r20-baseline')
TRACE_FIELDS = ('tick', 'p', 'v', 'yaw', 'pitch', 'grounded', 'checkpoint', 'elapsed', 'respawns')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=1, ensure_ascii=False) + '\n')


def passed(d, value, label, minimum=1):
    checks = value.get('checks')
    d.require(value.get('ok') is True and isinstance(checks, list) and len(checks) >= minimum
              and all(isinstance(c, dict) and c.get('ok') is True
                      and isinstance(c.get('check', c.get('name')), str)
                      and c.get('check', c.get('name')) for c in checks), label + ': failed/empty actual checks')
    return [{'name': c.get('check', c.get('name')), 'ok': True} for c in checks]


def source_guard(d, source, freeze):
    """hash every committed byte; permit only the existing UID/import sidecar policy."""
    manifest = d.r20.committed_manifest(freeze['source_commit'], d.PREFIX, d.PROJECT)
    found = {}
    for path in Path(source).rglob('*'):
        name = path.relative_to(source).as_posix()
        d.require(not path.is_symlink() and (path.is_dir() or path.is_file()), 'source symlink/special entry: ' + name)
        if '.godot' in path.relative_to(source).parts or not path.is_file():
            continue
        found[name] = d.r16.digest(path)
    d.require(all(found.get(p) == digest for p, digest in manifest.items()), 'complete frozen source inventory differs')
    # use the original sidecar validator, including pairing, byte size and UID syntax.
    generated = {p: h for p, h in found.items() if p not in manifest}
    d.snapshot_guard(source, {'manifest': manifest}, generated)
    d.component_bindings(freeze, manifest)
    cache = Path(source) / '.godot'
    cache_state = {}
    if cache.exists():
        guard = module('r21_delivery_existing_cache_guard', d.PROJECT / 'tools/check-r21-parity.py')
        cache_state = guard.cache_state(cache)
    return {'source_commit': freeze['source_commit'], 'committed': manifest, 'cache': cache_state,
            'generated': generated, 'helpers': {p: manifest[p] for p in d.HELPERS},
            'runtime': {p: h for p, h in manifest.items() if p.startswith(('scripts/', 'scenes/')) or p == 'project.godot'}}



def source_postflight(d, source, out, freeze, before):
    after = source_guard(d, source, freeze)
    write(out / 'SOURCE-after.json', after)
    # the existing cache guard allows data to change; committed code and sidecars do not.
    d.require({k: v for k, v in after.items() if k != 'cache'}
              == {k: v for k, v in before.items() if k != 'cache'}, 'component source changed during acceptance')

def envelope(d, name, stage, root, freeze, checks, **extra):
    d.require(checks and all(c.get('ok') is True for c in checks), 'cannot seal failed component evidence')
    proof = {}
    for path in sorted(Path(root).rglob('*')):
        d.require(not path.is_symlink() and (path.is_dir() or path.is_file()), 'component evidence special entry')
        if path.is_file():
            proof[path.relative_to(root).as_posix()] = d.r16.digest(path)
    d.require(proof, 'empty component proof')
    return {'binding': d.evidence_binding(name, stage, freeze), 'checks': checks, 'proof': proof, **extra}


def engine(d, source, root, label, script, extra=()):
    out = root / label
    d.require(not out.exists(), 'component output already exists: ' + str(out))
    out.mkdir(parents=True)
    command = [d.r16.EDITOR, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128',
               '--path', source, '--script', 'res://tests/' + script, '--', '--out=' + str(out), *extra]
    d.r16.checked(command, source, d.r16.engine_env(out / 'engine-profile'), root / (label + '.log'), 240)
    trace = out / 'trace.jsonl'
    if trace.is_file():
        # retain every byte, checking the compressed representation before reclaiming transport.
        digest = d.r16.digest(trace)
        target = Path(str(trace) + '.gz')
        with trace.open('rb') as incoming, gzip.open(target, 'wb') as outgoing:
            __import__('shutil').copyfileobj(incoming, outgoing)
        with gzip.open(target, 'rb') as incoming:
            d.require(hashlib.file_digest(incoming, 'sha256').hexdigest() == digest, 'lossy component trace compression')
        write(out / 'TRACE.json', {'raw_sha256': digest, 'raw_bytes': trace.stat().st_size,
                                  'gzip_sha256': d.r16.digest(target)})
        trace.unlink()
    return out


def salt_summary(d, summary, identity, freeze):
    d.require(summary.get('pass') is True and summary.get('finished') is True
              and summary.get('finish_kind') == 'clean' and summary.get('respawns') == 0
              and summary.get('configured_main') == freeze['runtime']['main_script']
              and summary.get('configured_scene') == freeze['runtime']['main_scene']
              and summary.get('runner') == 'res://scripts/r15_source_player.gd'
              and summary.get('physics_hz') == summary.get('engine_hz') == 128
              and 40 <= summary.get('elapsed', -1) <= 70
              and summary.get('actual_v_mismatches') == summary.get('rate_mismatch_ticks') == 0
              and summary.get('geometry_hash') == identity['maps']['saltglass']['geometry']
              and len(summary.get('contact_pieces', {})) == 16
              and summary.get('grounded_steep_ticks') == 0,
              'Saltglass did not earn the final normal-spawn production contract')


def salt_source(d, source, out, identity, freeze):
    before = source_guard(d, source, freeze)
    write(out / 'SOURCE.json', before)
    # final complete source, rather than the historical Saltglass-only integration seam.
    seam = {'files': {p: before['committed'][p] for p in (*COMMON[4:], 'project.godot', 'scripts/r19_ghost_share.gd')}}
    write(out / 'PARENT-SEAM.json', seam)
    checker = module('r21_delivery_surf_checker', source / 'tests/r21_surf_check.py')
    checker.PROJECT = d.PROJECT
    checker.preserved(source, out, out / 'PARENT-SEAM.json', d.r16.digest(out / 'PARENT-SEAM.json'))
    preservation = d.read_json(out / 'PRESERVATION.json')
    d.require(preservation['files'] and len(preservation['files']) >= 528, 'empty/truncated Saltglass preservation query')
    checks = [{'name': 'complete final source and nonempty inherited preservation inventory', 'ok': True}]
    engine(d, source, out, 'integration', 'r21_surf_integration.gd')
    engine(d, source, out, 'geometry-negative', 'r21_surf_geometry_negative.gd')
    generated = engine(d, source, out, 'run', 'r21_surf_route.gd')
    summary = d.read_json(generated / 'summary.json')
    salt_summary(d, summary, identity, freeze)
    tape = '--tape=' + str(generated / 'events.tape.json')
    engine(d, source, out, 'replay', 'r21_surf_route.gd', [tape])
    engine(d, source, out, 'old-look', 'r21_surf_route.gd', [tape, '--old-look=1'])
    for label, probe in [('west-bail', 'west_bail'), ('east-bail', 'east_bail'),
                         ('turnaround', 'turnaround'), ('turnaround-diagonal', 'turnaround_diagonal')]:
        engine(d, source, out, label, 'r21_surf_probes.gd', ['--probe=' + probe])
    for skill in ('safe', 'outside', 'late'):
        engine(d, source, out, 'skill-' + skill, 'r21_surf_skill.gd', ['--skill=' + skill])
    for fin in ('west', 'east'):
        for geometry, target in [('r20', '10.0'), ('r21', '10.0'), ('r21', '5.3'), ('r20', '5.3')]:
            engine(d, source, out, fin + '-' + geometry + '-' + target, 'r21_surf_exit.gd',
                   ['--fin=' + fin, '--exit-geometry=' + geometry, '--exit-target=' + target])
    old = d.OUTER / 'playtest-r20/userdata-spillway/r16_runs/saltglass_server128_20261111-104057_050_d1951cf9.r16run'
    engine(d, source, out, 'ghost', 'r21_surf_ghost.gd',
           ['--old-ghost=' + str(old), '--new-ghost=' + summary['recordings'][0]['path']])
    for script, target in [('r21_surf_audit.py', 'AUDIT.json'), ('r21_surf_matches.py', 'MATCHES.json')]:
        auditor = module('r21_delivery_' + target.split('.')[0], source / 'tests' / script)
        result = auditor.audit(out)
        checks.extend(passed(d, result, script))
        write(out / target, result)
    raw = d.read_json(generated / 'events.tape.json')
    plan = d.r20.include_cleanup_tick(raw)
    release = generated / 'release.tape.json'
    write(release, plan)
    route = d.r16.parse_route('map=saltglass,preset=server128,tape=' + str(release)
                             + ',warmup=33,sensitivity=2.5,name=r21-saltglass')
    frozen = d.r16.source_route(route, source, out, identity)
    frozen['generated_route'] = {'script': 'tests/r21_surf_route.gd',
        'script_sha256': before['committed']['tests/r21_surf_route.gd'],
        'summary_sha256': d.r16.digest(generated / 'summary.json'), 'normal_spawn_input_only': True,
        'cleanup_tick_added': plan['duration_ticks'] != raw['duration_ticks'],
        'all_original_edges_retained': plan['events'] == raw['events'],
        'local_skill_fixtures_are_normal_spawn': False}
    source_postflight(d, source, out, freeze, before)
    checks.append({'name': 'complete earned tape through unchanged source-route/input/cleanup pipeline', 'ok': True})
    write(out / 'ROUTE.json', frozen)
    return envelope(d, 'saltglass', 'source', out, freeze, checks, routes=[frozen])


def tether_summary(d, value, model, assist, identity):
    options = value.get('options', {})
    d.require(value.get('scope') == 'actual production host/UI' and value.get('pass') is True
              and value.get('finished') is True and value.get('finish_kind') == 'clean'
              and value.get('respawns') == value.get('actual_v_mismatches') == value.get('rate_mismatch_ticks') == 0
              and value.get('runner') == 'res://scripts/r21_tether_player.gd'
              and value.get('physics_hz') == 128 and set(value.get('anchors', {})) == {'Transfer 1', 'Transfer 2', 'Transfer 3'}
              and value.get('geometry_hash') == identity['maps']['tether-yard']['geometry']
              and options.get('production') == '1' and options.get('model') == model
              and ('assist-off' not in options) == assist and 'auto' not in options
              and not any(k in options for k in ('human', 'old-e', 'frozen-r20', 'original-geometry', 'isolate-dispatch')),
              'Tether route is not the exact model/assist production finish: ' + model)


def clean_record(d, reader, summary):
    rows = [r for r in summary.get('recordings', []) if r.get('clean_finish', {}).get('ok') is True]
    d.require(len(rows) == 1 and rows[0].get('ok') is True, 'one clean strict engine recording required')
    rec = reader.read(Path(rows[0]['path']))
    d.require(rec.ok and rec.seal.get('outcome', {}).get('kind') == 'finish', 'strict independent clean recording refused')
    return rec


def reader_tape(d, rec, warmup=33):
    columns, inputs = rec.columns, rec.inputs
    count = len(columns['tick'])
    d.require(count > warmup and columns['tick'] == list(range(count))
              and set(columns['physics_hz']) == {128} and set(columns['dt']) == {1 / 128}
              and set(inputs['kind']) <= {1, 2, 3, 4}, 'incomplete recording or unexpected input kind')
    events = []
    for i, kind in enumerate(inputs['kind']):
        if kind in (1, 2, 3):
            row = {key: values[i] for key, values in inputs.items()}
            d.require(type(row['tick']) is int and warmup <= row['tick'] < count, 'raw input outside armed complete recording')
            events.append({'tick': row['tick'] - warmup, 'raw': row})
    d.require(events, 'empty raw-reader-derived tape')
    return {'version': 2, 'physics_hz': 128, 'duration_ticks': count - warmup, 'events': events}


def rows(path):
    with gzip.open(path, 'rt') as stream:
        for line in stream:
            yield json.loads(line)


def binary_columns(d, columns, inputs=False):
    reader = module('r21_delivery_binary_layout', d.PROJECT / 'tools/analyze-r16-runs.py')
    layout = {name: code for name, code, _ in reader.INPUT_LAYOUT} if inputs else {
        **{name: code for name, code, _ in reader.TICK_LAYOUT if name not in reader.VECTORS},
        **{group + '_' + axis: 'f' for group in reader.VECTORS for axis in 'xyz'}}
    d.require(columns.keys() == layout.keys(), 'complete original binary column layout required')
    return {name: struct.pack('<' + str(len(values)) + layout[name], *values) for name, values in columns.items()}


def exact_value(first, second):
    if type(first) is not type(second):
        return False
    if type(first) is float:
        return math.isfinite(first) and math.isfinite(second) and struct.pack('<d', first) == struct.pack('<d', second)
    if type(first) is dict:
        return first.keys() == second.keys() and all(exact_value(first[key], second[key]) for key in first)
    if type(first) is list:
        return len(first) == len(second) and all(exact_value(a, b) for a, b in zip(first, second))
    return type(first) in (str, int, bool, type(None)) and first == second


def exact_replay(d, first, second, rec, replay):
    d.require(binary_columns(d, rec.columns) == binary_columns(d, replay.columns)
              and binary_columns(d, rec.inputs, True) == binary_columns(d, replay.inputs, True),
              'Tether binary physics/raw/action replay columns differ')
    import itertools
    count = 0
    for a, b in itertools.zip_longest(rows(first / 'trace.jsonl.gz'), rows(second / 'trace.jsonl.gz')):
        d.require(a is not None and b is not None and a.get('tick') == b.get('tick') == count,
                  'missing/unordered replay trace row')
        for key in (*TRACE_FIELDS, 'reference_p', 'style', 'motion', 'rope_length_u'):
            d.require(exact_value(a[key], b[key]), 'Tether full source replay differs: ' + key)
        count += 1
    d.require(count > 0, 'empty replay trace')
    return count


def tether_route_arguments(model, assist):
    extra = ['--production=1', '--model=' + model] + ([] if assist else ['--assist-off=1'])
    if model == 'pendulum':
        # this input finder lands before the finish volume instead of crossing it airborne.
        extra += ['--land-z=-80', '--final-release-before=3']
    return extra


def tether_source(d, source, out, identity, freeze):
    before = source_guard(d, source, freeze)
    write(out / 'SOURCE.json', before)
    d.require(tuple([*freeze['models']['original'], *(v['id'] for v in freeze['models']['elastic_variants'])]) == MODELS,
              'final Tether adapter requires the actual ordered six-model interface')
    reader = module('r21_delivery_strict_reader', source / 'tools/analyze-r16-runs.py')
    component = engine(d, source, out, 'component', 'r21_tether_component.gd')
    comp = d.read_json(component / 'summary.json')
    checks = passed(d, comp, 'Tether component', 75)
    expected_laws = {**freeze['models']['original'],
                     **{v['id']: v['rules_sha256'] for v in freeze['models']['elastic_variants']}}
    for model in MODELS:
        law = comp['identities'][model]
        projection = {'classic': law['classic'], 'alternative': law['alternative'],
                      'controls': law['controls'], 'effective_reel_ups': law['reel_ups']}
        d.require(hashlib.sha256(d.canonical(projection)).hexdigest() == expected_laws[model],
                  'applied component model law differs from final freeze: ' + model)
    d.require(len(comp.get('applied_arc_probes', [])) >= 12, 'applied Arc force/reel probes missing')
    geometry = engine(d, source, out, 'geometry', 'r21_tether_geometry.gd')
    geo = d.read_json(geometry / 'summary.json')
    checks.extend(passed(d, geo, 'Tether geometry', 6))
    d.require(geo.get('heights') == [4.0, 3.0, 4.0, 2.25] and geo.get('level_version') == 2
              and geo.get('level_id') == 'r21-tether-yard'
              and geo.get('geometry_hash') == identity['maps']['tether-yard']['geometry'], 'final Tether geometry/version mismatch')
    tapes, off, references, routes = {}, {}, {}, {}
    for model in MODELS:
        for assist in ([True] if model in MODELS[:2] else [True, False]):
            label = model if assist else model + '-assist-off'
            extra = tether_route_arguments(model, assist)
            generated = engine(d, source, out, label, 'r21_tether_route.gd', extra)
            summary = d.read_json(generated / 'summary.json')
            tether_summary(d, summary, model, assist, identity)
            rec = clean_record(d, reader, summary)
            tether_record(d, rec, summary, model, assist, freeze)
            tape = generated / 'recorded.tape.json'
            write(tape, reader_tape(d, rec))
            replayed = engine(d, source, out, label + '-replay', 'r21_tether_route.gd', extra + ['--tape=' + str(tape)])
            replay_summary = d.read_json(replayed / 'summary.json')
            tether_summary(d, replay_summary, model, assist, identity)
            other = clean_record(d, reader, replay_summary)
            tether_record(d, other, replay_summary, model, assist, freeze)
            count = exact_replay(d, generated, replayed, rec, other)
            (tapes if assist else off)[model] = str(tape)
            reference = [{key: row[key] for key in TRACE_FIELDS} for row in rows(generated / 'trace.jsonl.gz')]
            reference_path = generated / 'packed-reference.json'
            write(reference_path, reference)
            references[label] = {'model': model, 'assist': assist, 'tape': str(tape),
                'tape_sha256': d.r16.digest(tape), 'trace': str(reference_path),
                'trace_sha256': d.r16.digest(reference_path), 'recording': str(rec.path),
                'recording_sha256': d.r16.digest(rec.path), 'ticks': count,
                'identity': rec.header['identity']}
            if assist:
                routes[model], routes[model + '_replay'] = str(generated), str(replayed)
            checks.append({'name': label + ': production finish and every source replay binary/raw/action/trace column', 'ok': True})
    write(out / 'production-routes.json', routes)
    boundaries = engine(d, source, out, 'boundaries', 'r21_tether_boundaries.gd',
                        ['--routes=' + str(out / 'production-routes.json')])
    boundary = d.read_json(boundaries / 'summary.json')
    checks.extend(passed(d, boundary, 'actual production boundaries', 253))
    reload_out = engine(d, source, out, 'reload', 'r21_tether_reload.gd',
                        ['--profile=' + str(boundaries / 'reload-path.json')])
    reloaded = d.read_json(reload_out / 'summary.json')
    d.require(reloaded.get('ok') is True and reloaded.get('profile_unchanged') is True,
              'separate production settings reload failed/rewrote profile')
    # run both original readers over every generated attempt, including lifecycle failures.
    wires = engine(d, source, out, 'readers', 'r21_tether_readers.gd', ['--root=' + str(out)])
    cross = module('r21_delivery_cross_reader', source / 'tests/r20_tether_check.py')
    index = d.read_json(wires / 'index.json')
    cross.READER_WIRES = {r['path']: r for r in index}
    d.require(index and len(cross.READER_WIRES) == len(index), 'missing/duplicate reader wire inventory')
    comparisons = []
    for wire in index:
        cross.cross_reader(reader, wire, comparisons)
    write(out / 'READERS.json', {'ok': True, 'comparisons': comparisons})
    checks.append({'name': 'all production/lifecycle recordings pass both unchanged strict readers', 'ok': True})
    source_postflight(d, source, out, freeze, before)
    features = {'tether': tapes, 'r21_tether_off': off, 'r21_tether_reference': references}
    write(out / 'FEATURES.json', features)
    return envelope(d, 'tether', 'source', out, freeze, checks, feature_tapes=features)


def parity_arguments(d, args, freeze, identity):
    d.require(args is not None and getattr(args, 'parity_contract', None)
              and getattr(args, 'parity_contract_sha256', None) and getattr(args, 'parity_identity', None),
              'explicit parent-reviewed --parity-contract/--parity-contract-sha256/--parity-identity required')
    d.require(d.read_json(args.freeze) == freeze and d.read_json(args.parity_identity) == identity,
              'parity file/whole identity differs from delivery freeze')
    d.require(d.r16.digest(args.parity_contract) == args.parity_contract_sha256,
              'parent parity contract SHA256 differs')
    return ['--candidate', freeze['source_commit'], '--baseline-dir', str(PARITY_BASELINE),
            '--freeze', str(args.freeze), '--freeze-sha256', d.r16.digest(args.freeze),
            '--identity', str(args.parity_identity), '--contract', str(args.parity_contract),
            '--contract-sha256', args.parity_contract_sha256, '--out', str(PARITY_ROOT)]


def parity_receipt(d, root, freeze, identity, expected_inputs=None):
    """Rehash the raw inventory as well as the separate auditor, never just ok:true."""
    d.require(root == PARITY_ROOT and root.is_dir() and not root.is_symlink(), 'exact final parity proof required')
    report = d.read_json(root / 'REPORT.json')
    audit = d.read_json(root / 'audit/AUDIT.json')
    inputs = report['inputs']
    if expected_inputs is not None:
        d.require(inputs == expected_inputs, 'parity inputs changed after source adapter audit')
    auditor = module('r21_delivery_final_raw_auditor', d.PROJECT / 'tests/r21_parity_audit.py')
    auditor.raw_guard(root, inputs if expected_inputs is None else expected_inputs)
    d.require(audit.get('ok') is True and audit.get('r21_final_gate') == 'passed'
              and audit.get('candidate_commit') == inputs.get('candidate_commit') == freeze['source_commit']
              and inputs['contract']['identity'] == identity
              and inputs['contract']['candidate_commit'] == freeze['source_commit']
              and audit.get('raw_manifest_sha256') == d.r16.digest(root / 'RAW-MANIFEST.json')
              and report.get('ok') is False and report.get('capture_complete') is True
              and report.get('r21_final_gate') == 'pending', 'stale/incomplete/relabeled final parity receipt')
    manifest = d.read_json(root / 'RAW-MANIFEST.json')
    d.require(isinstance(manifest, dict) and bool(manifest), 'empty parity raw manifest')
    for name, digest in manifest.items():
        path = d.owned_path(root / name, root)
        d.require(path.is_file() and d.r16.digest(path) == digest, 'changed parity raw proof: ' + name)
    transport = d.read_json(root / 'TRANSPORT.json')
    d.require(len(transport.get('receipts', [])) == 144 and len(report.get('routes', [])) == 16
              and len(audit.get('routes', [])) == 16
              and audit.get('original_controls', {}).get('checks') == 56
              and audit.get('candidate_controls', {}).get('ok') is True,
              'full 48-play/16-route/144-stream/negative parity proof missing')
    return {'audit_sha256': d.r16.digest(root / 'audit/AUDIT.json'),
            'raw_manifest_sha256': d.r16.digest(root / 'RAW-MANIFEST.json'),
            'report_sha256': d.r16.digest(root / 'REPORT.json'),
            'transport_sha256': d.r16.digest(root / 'TRANSPORT.json')}



def review_inputs(d, args, freeze):
    identity_path = getattr(args, 'parity_identity', None)
    d.require(identity_path, 'parent reviewed parity identity required before runtime execution')
    identity = d.read_json(identity_path)
    parity_arguments(d, args, freeze, identity)
    d.require(hashlib.sha256(d.canonical(identity)).hexdigest() == freeze['identity_sha256'],
              'reviewed parity identity digest differs from shared freeze')
    contract = d.read_json(args.parity_contract)
    d.require(contract.get('status') == 'REVIEWED' and contract.get('kind') == 'r21-exact-r20-parity'
              and contract.get('candidate_commit') == freeze['source_commit']
              and contract.get('freeze_sha256') == d.r16.digest(args.freeze)
              and contract.get('identity') == identity, 'wrong/incomplete parent final parity review')
    receipt = parity_receipt(d, PARITY_ROOT, freeze, identity)
    inputs = d.read_json(PARITY_ROOT / 'REPORT.json')['inputs']
    d.require(inputs['contract'] == contract and inputs['freeze_sha256'] == d.r16.digest(args.freeze)
              and inputs['contract_sha256'] == args.parity_contract_sha256,
              'completed parity proof is not bound to this exact complete shared review')
    return receipt

def parity_source(d, source, out, identity, freeze, args):
    source_state = source_guard(d, source, freeze)
    argv = parity_arguments(d, args, freeze, identity)
    # parity preflight is tied to the repository HEAD, so invoke its committed,
    # byte-checked repository helper. It reads the exact Git tree and raw proof.
    for name in d.HELPERS:
        d.require(d.committed_bytes(freeze['source_commit'], name) == (d.PROJECT / name).read_bytes(),
                  'loose helper differs from final committed helper: ' + name)
    command = [sys.executable, '-B', str(d.PROJECT / 'tools/check-r21-parity.py'), '--audit', *argv]
    d.r16.checked(command, d.PROJECT, __import__('os').environ.copy(), out / 'reaudit.log', 600)
    receipt = parity_receipt(d, PARITY_ROOT, freeze, identity)
    inputs = d.read_json(PARITY_ROOT / 'REPORT.json')['inputs']
    d.require(inputs['freeze_sha256'] == d.r16.digest(args.freeze)
              and inputs['contract_sha256'] == args.parity_contract_sha256
              and inputs['contract']['freeze_sha256'] == inputs['freeze_sha256']
              and {p: v['sha256'] for p, v in inputs['source']['files'].items()} == source_state['committed']
              and inputs['helpers'] == inputs['contract']['verification_helpers']
              and all(source_state['committed'].get(p) == h for p, h in inputs['helpers'].items()), 'final shared freeze/helper/source mismatch')
    write(out / 'SOURCE.json', source_state)
    write(out / 'PARITY.json', {'binding': d.evidence_binding('parity', 'source', freeze),
                               'argv': [str(v) for v in command], 'receipts': receipt,
                               'inputs': inputs, 'scope': 'headless source parity; no native Windows claim'})
    return envelope(d, 'parity', 'source', out, freeze,
                    [{'name': 'unchanged independent final auditor reran all raw 48 plays/144 streams and negatives', 'ok': True}])



SETTING_TYPES = {'source_sensitivity': (int, float), 'source_fov': (int, float),
                 'r13_sensitivity': (int, float), 'r13_fov': (int, float),
                 'volume': (int, float), 'show_ms': (bool,), 'ghost': (bool,),
                 'tether_model': (str,), 'tether_auto_reel': (bool,), 'tether_anchor_assist': (bool,)}


def settings_contract(d, settings):
    d.require(type(settings) is dict and set(settings) == set(SETTING_TYPES), 'unknown/missing effective setting')
    for key, kinds in SETTING_TYPES.items():
        d.require(type(settings[key]) in kinds, 'mistyped effective setting: ' + key)
        if key == 'tether_model':
            d.require(settings[key] in MODELS, 'unknown effective Tether model')
        elif kinds == (int, float):
            d.require(__import__('math').isfinite(settings[key]), 'nonfinite effective setting')


def recording_preferences(d, rec):
    for event in rec.events:
        if event.get('k') == 'settings':
            data = event.get('d', {})
            key = data.get('key')
            d.require(key in SETTING_TYPES and not key.startswith('tether_')
                      and type(data.get('value')) in SETTING_TYPES[key],
                      'unknown/mistyped settings lifecycle event')
        if event.get('k') != 'loadout' or 'key' not in event.get('d', {}):
            continue
        data = event['d']
        key = data['key']
        d.require(key in ('tether_model', 'tether_auto_reel', 'tether_anchor_assist')
                  and rec.header['metadata']['map'] == 'tether-yard'
                  and event.get('s') == 'event' and type(event.get('t')) is int
                  and -1 <= event['t'] < len(rec.columns['tick'])
                  and all(type(data.get(k)) in SETTING_TYPES[key] for k in ('from', 'to'))
                  and data['from'] != data['to'], 'unknown/mistyped Tether loadout boundary')
        if key == 'tether_model':
            d.require(data['from'] in MODELS and data['to'] in MODELS, 'unregistered Tether model boundary')


def tether_record(d, rec, summary, model, assist, freeze):
    metadata = rec.header['metadata']
    law = metadata['physics']['mechanics'][-1]
    d.require(metadata['map'] == 'tether-yard' and metadata['build'] == freeze['runtime']['build']
              and rec.header['identity'] == summary['identity']
              and law['model'] == model and law['automatic_reel'] is False
              and law['acquisition']['law'] == ('r21-anchor-assist-1' if assist and model not in MODELS[:2] else 'r20-original-aim'),
              'recording law/assist/whole identity differs from exercised route')
    recording_preferences(d, rec)

def native_result(d, evidence, build):
    controls = d.read_json(evidence / 'controls/delivery-result.json')
    probe = d.read_json(evidence / 'controls/probe.json')
    d.require(controls.get('ok') is True and controls.get('exit') == 0
              and controls.get('failures') == probe.get('failures') == 0
              and probe.get('checks') and all(c.get('ok') is True for c in probe['checks'])
              and [v['map'] for v in controls.get('r20_maps', [])] == build['freeze']['required_maps']
              and controls.get('recordings', {}).get('ok') is True,
              'complete all-map native packed controls/strict reader audit missing')
    settings_contract(d, probe['control_profile']['settings'])
    if probe.get('run_export'):
        settings_contract(d, probe['run_export']['settings'])
    reader = module('r21_packed_boundary_reader', d.PROJECT / 'tools/analyze-r16-runs.py')
    for attempt in probe['recordings']['attempts']:
        rec = reader.read(Path(attempt['path']))
        d.require(rec.ok, 'packed recording refused by independent reader')
        recording_preferences(d, rec)
    return controls, probe



def packed_tether_routes(d, feature, references):
    reader = module('r21_source_packed_binary_reader', d.PROJECT / 'tools/analyze-r16-runs.py')
    expected = {m for m in MODELS} | {m + '-assist-off' for m in MODELS[2:]}
    d.require(set(feature.get('routes', {})) == expected, 'all six models/four effective off packed routes required')
    d.require(set(references) == expected, 'complete source model/assist reference set required')
    for label in sorted(expected):
        ref = references[label]
        d.require(d.r16.digest(ref['tape']) == ref['tape_sha256']
                  and d.r16.digest(ref['trace']) == ref['trace_sha256']
                  and d.r16.digest(ref['recording']) == ref['recording_sha256'], 'source Tether proof changed: ' + label)
        observed = feature['routes'][label]
        d.require(observed['model'] == ref['model'] and observed['assist'] == ref['assist']
                  and exact_value(observed['trace'], d.read_json(ref['trace']))
                  and exact_value(observed['identity'], ref['identity'])
                  and observed['tape_sha256'] == ref['tape_sha256'], 'packed/source Tether route differs: ' + label)
        original, current = reader.read(Path(ref['recording'])), reader.read(Path(observed['recording']))
        d.require(original.ok and current.ok and binary_columns(d, original.columns) == binary_columns(d, current.columns)
                  and exact_value(current.header['identity'], ref['identity']),
                  'packed/source Tether complete binary physical columns differ: ' + label)

def packed(d, name, folder, build, args, evidence, out, routes):
    freeze = build['freeze']
    d.require(d.r16.digest(folder / (d.NAME + '.pck')) == build['pack_sha256'], 'component packed PCK differs')
    controls, probe = native_result(d, evidence, build)
    checks = [{'name': 'exact PCK and complete actual native eleven-map controls and reader audits', 'ok': True}]
    raw = {'controls': d.r16.digest(evidence / 'controls/delivery-result.json'),
           'probe': d.r16.digest(evidence / 'controls/probe.json')}
    source = routes[0]['feature_tapes']['r21_source_components'][name]
    d.validate_evidence(source['receipt'], name + ' bound source', Path(source['root']),
                        d.evidence_binding(name, 'source', freeze))
    raw['source_adapter'] = hashlib.sha256(d.canonical(source['receipt'])).hexdigest()
    if name == 'saltglass':
        selected = [r for r in routes if r['route']['map'] == 'saltglass']
        d.require(len(selected) == 1, 'exact Saltglass source route required')
        route = selected[0]
        play = evidence / (route['route']['name'] + '-play')
        result = d.read_json(play / 'delivery-result.json')
        d.require(result.get('ok') is True and result.get('exact_source_trace', {}).get('ok') is True
                  and result.get('input_order', {}).get('ok') is True
                  and result.get('recordings', {}).get('ok') is True,
                  'Saltglass packed/source trace/input/both-reader replay failed')
        raw['saltglass_play'] = d.r16.digest(play / 'delivery-result.json')
        passed(d, probe['r21_saltglass_controls'], 'packed Saltglass controls')
        checks.append({'name': 'revised normal-spawn Saltglass exact packed/source and physical geometry checks', 'ok': True})
    elif name == 'tether':
        feature = probe['r21_tether_controls']
        checks.extend(passed(d, feature, 'packed Tether controls'))
        packed_tether_routes(d, feature, routes[0]['feature_tapes']['r21_tether_reference'])
        checks.append({'name': 'all six laws and four assist-off tapes exactly replayed in packed production', 'ok': True})
    else:
        parity_arguments(d, args, freeze, build['identity'])
        source_inputs = d.read_json(Path(source['root']) / 'PARITY.json')['inputs']
        receipt = parity_receipt(d, PARITY_ROOT, freeze, build['identity'], source_inputs)
        inputs = d.read_json(PARITY_ROOT / 'REPORT.json')['inputs']
        d.require(inputs['freeze_sha256'] == d.r16.digest(args.freeze)
                  and inputs['contract_sha256'] == args.parity_contract_sha256, 'packed parity shared review inputs drift')
        # source parity plus actual packed trace/input/reload and native tours, never an OS equivalence claim.
        for route in routes:
            for mode in ('play', 'reload'):
                path = evidence / (route['route']['name'] + '-' + mode) / 'delivery-result.json'
                result = d.read_json(path)
                d.require(result.get('ok') is True and result.get('recordings', {}).get('ok') is True
                          and (result.get('exact_source_trace', {}).get('ok') is True if mode == 'play'
                               else result.get('config_not_rewritten') is True), 'packed parity replay/reload missing')
                raw[route['route']['name'] + '-' + mode] = d.r16.digest(path)
        raw.update(receipt)
        checks.append({'name': 'final source parity bound to exact PCK/runtime and earned native packed replay/reload', 'ok': True})
    write(out / 'PACKED.json', {'binding': d.evidence_binding(name, 'packed', freeze),
        'source_commit': build['source_commit'], 'identity': build['identity'],
        'pack_sha256': build['pack_sha256'], 'helpers': build['helpers_sha256'],
        'source_manifest_sha256': build['source_manifest_sha256'],
        'runtime': build['runtime'],
        'evidence': raw, 'scope': 'exact Linux packed checks; native Windows unverified'})
    return envelope(d, name, 'packed', out, freeze, checks)


def install(d):
    return {name: d.ComponentGate(PATHS[name],
        (lambda source, out, identity, freeze, n=name: (
            salt_source(d, source, out, identity, freeze) if n == 'saltglass' else
            tether_source(d, source, out, identity, freeze) if n == 'tether' else
            parity_source(d, source, out, identity, freeze, getattr(d, '_delivery_args', None)))),
        (lambda folder, build, args, evidence, out, routes, n=name:
            packed(d, n, folder, build, args, evidence, out, routes))) for name in PATHS}
