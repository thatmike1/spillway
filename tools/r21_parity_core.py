#!/usr/bin/env python3
"""Strict R20-to-R21 preparation contracts and exact observational comparisons.

No engine entry point lives in this module. Historical comparators which separate
R19/R20 scoring are deliberately not used for R21 equality.
"""
import array
import copy
import gzip
import hashlib
import itertools
import json
from pathlib import Path
import re
import shutil
import stat
import struct
import subprocess
import sys
import types

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import r20_candidate_core as R20
K = R20
B, C = K.B, K.C
module, need, keys, sha, load, canonical = K.module, K.need, K.keys, K.sha, K.load, K.canonical
Refused = K.Refused
META_KEYS, IDENTITY_KEYS = K.META_KEYS, K.IDENTITY_KEYS
lab_guard = K.lab_guard
O = module('r21_frozen_observations', PROJECT / 'tests/r20_candidate_observations.py')
D = module('r21_delivery_contract', PROJECT / 'tools/package-r21.py')
A = module('r21_strict_recording_reader', PROJECT / 'tools/analyze-r16-runs.py')
G = module('r21_frozen_guard', PROJECT / 'tools/check-r20-candidate-parity.py')
T = module('r21_frozen_tape', PROJECT / 'tools/momentum-tape.py')
BASE = 'e6baa995da84d380abc8b8d6a3769b33e771945e'
CAPTURE = '7f8fb41b741c01455682ae0c6ee612d5d6fd1fc4'
BASELINE = Path('/tmp/r21-r20-baseline')
OUTER = B.OUTER / 'look'
RESTORE_SHA = 'c1850922d2c99f5effc8bcdd2fa3ca5a8a849f5b51236f1ba312345e7e660200'
ARCHIVE_SHA = '88e94c14cd80fac2c0e2e797b7445d71050c277bc1ceebb767330b2db0857137'
ARCHIVE_FILES_SHA = '0021085e5cc90ca7f5cd4f21a954da15d815edcce2e1dfca9e2eaa849f295abf'
EQUIVALENCE_SHA = '9833868168bbf4ac0d576bd178f0173fce978985a9c62da9ce6b9637fa2309f8'
R20_BUILD_SHA = '61389e07d5173fc6498e9af9639689e20676b752153685b40c9150dff504ae75'
VARIANTS = ('old', 'new', 'toggle')
SCENE = 'res://scenes/r21.tscn'
SCRIPT = 'res://scripts/r21_main.gd'
PREP = Path('/tmp/r21-parity-preparation')
FINAL = Path('/tmp/r21-candidate-parity')
LOCK = Path('/tmp/spillway-r21-engine.lock')
PREP_CAP = 60 * 2**20
OWN = ('tools/check-r21-parity.py', 'tools/r21_parity_core.py',
       'tests/r21_parity.gd', 'tests/r21_parity_audit.py',
       'tests/test_r21_parity.py', 'docs/r21/PARITY.md')


def unique_recording_object(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError('duplicate recording JSON key: '+name)
        result[name] = value
    return result


# extend a private reader instance only; the frozen reader file and other gates stay exact.
A.json = types.SimpleNamespace(loads=lambda data, **kwargs: json.loads(
    data, object_pairs_hook=unique_recording_object, **kwargs))


def freeze_schema(freeze, commit):
    keys(freeze, {'schema','runtime_frozen','source_commit','identity_sha256','intentional_changes',
                 'required_maps','experimental_maps','reached_items','runtime','map_versions','models',
                 'delivery_components'}, 'R21 freeze')
    D.validate_freeze(freeze, commit)
    declared = freeze['delivery_components']
    keys(declared, {'saltglass','tether','parity'}, 'delivery component bindings')
    for name, pins in declared.items():
        need(type(pins) is dict and bool(pins), 'empty delivery component: '+name)
        for path, digest in pins.items():
            need(type(path) is str and path and not Path(path).is_absolute() and '\\' not in path
                 and all(part not in ('', '.', '..') for part in path.split('/'))
                 and D.hex_value(digest, 64), 'invalid delivery component pin: '+name)
    return freeze


def cache_inventory_guard(value):
    need(type(value) is dict, 'private cache inventory missing')
    for name, entry in value.items():
        path = Path(name)
        need(type(name) is str and name and not path.is_absolute()
             and all(p not in ('', '.', '..') for p in name.split('/'))
             and '\\' not in name and path.suffix.lower() not in ('.gd','.gdshader','.py'),
             'unexpected source or unsafe path in private import cache')
        keys(entry, {'sha256','bytes','mode'}, 'private cache file')
        need(D.hex_value(entry['sha256'], 64) and type(entry['bytes']) is int and entry['bytes'] >= 0
             and type(entry['mode']) is int and 0 <= entry['mode'] <= 0o777,
             'invalid private cache file receipt')
    return value


def differences(a, b, path='$'):
    # float bits matter, including signed zero; no tolerance and no four-error cap.
    if type(a) is not type(b):
        yield {'path':path, 'old':repr(a), 'new':repr(b)}
    elif isinstance(a, dict):
        for name in sorted(a.keys() | b.keys()):
            if name not in a or name not in b:
                yield {'path':path+'.'+name, 'old_present':name in a, 'new_present':name in b}
            else:
                yield from differences(a[name], b[name], path+'.'+name)
    elif isinstance(a, (list, tuple)):
        for i, (x, y) in enumerate(itertools.zip_longest(a, b, fillvalue=MISSING)):
            yield from differences(x, y, path+'['+str(i)+']')
    elif isinstance(a, array.array):
        if a.typecode != b.typecode or a.tobytes() != b.tobytes():
            yield {'path':path, 'old_sha256':hashlib.sha256(a.tobytes()).hexdigest(),
                   'new_sha256':hashlib.sha256(b.tobytes()).hexdigest()}
    elif isinstance(a, float):
        if struct.pack('<d', a) != struct.pack('<d', b):
            yield {'path':path, 'old':a, 'new':b, 'old_bits':struct.pack('<d',a).hex(),
                   'new_bits':struct.pack('<d',b).hex()}
    elif a != b:
        yield {'path':path, 'old':repr(a), 'new':repr(b)}


MISSING = object()


def exact(a, b, reason):
    found = next(differences(a, b), None)
    need(found is None, reason+': '+repr(found))


def compare_rows(before, after, emit):
    rows = mismatches = 0
    for rows, (a, b) in enumerate(itertools.zip_longest(before, after, fillvalue=MISSING), 1):
        for found in differences(a, b):
            emit({'row':rows-1, **found})
            mismatches += 1
    return {'ok':mismatches == 0, 'rows':rows, 'differences':mismatches}


def checked(path, digest):
    return K.checked_json(Path(path), digest)


def baseline_guard():
    receipt = checked(BASELINE/'R21-RESTORE.json', RESTORE_SHA)
    exact(checked(OUTER/'evidence/r21-parity-baseline/RESTORE.json', RESTORE_SHA), receipt,
          'restoration receipt')
    inventory = checked(OUTER/'evidence/r20-final-parity-archive/FILES.json', ARCHIVE_FILES_SHA)
    equivalent = checked(OUTER/'evidence/r20-windows-gate-repair/SOURCE-EQUIVALENCE.json', EQUIVALENCE_SHA)
    need(receipt['ok'] is True and receipt['archive_sha256'] == ARCHIVE_SHA
         and receipt['all_archive_files_verified'] == 1602 and receipt['restored_files'] == 410
         and receipt['restored_bytes'] == 115983321 and receipt['selected_root'] == str(BASELINE)
         and receipt['frozen_capture_commit'] == CAPTURE and receipt['promoted_R20_commit'] == BASE,
         'restoration provenance changed')
    need(equivalent['ok'] is True and equivalent['artifact_source_commit'] == CAPTURE
         and equivalent['verification_commit'] == BASE and equivalent['all_runtime_files_identical'] == 564
         and equivalent['all_executed_parity_helpers_identical'] == 26, 'source equivalence changed')
    found = set()
    for path in BASELINE.rglob('*'):
        need(not path.is_symlink(), 'baseline symlink')
        if path.is_dir():
            continue
        name = path.relative_to(BASELINE).as_posix()
        need(path.is_file() and stat.S_IMODE(path.stat().st_mode) == 0o444, 'baseline mode/type: '+name)
        found.add(name)
    exact(sorted(found), sorted([*receipt['files'], 'R21-RESTORE.json']), 'baseline membership')
    manifest = load(BASELINE/'MANIFEST.json')
    for name, record in receipt['files'].items():
        need(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe baseline member')
        path = BASELINE/name
        exact(record, inventory['r20-candidate-parity/'+name], 'selected/archive member '+name)
        need(path.stat().st_size == record['bytes'] and sha(path) == record['sha256'], 'baseline bytes: '+name)
        if name != 'MANIFEST.json':
            need(manifest[name] == record['sha256'], 'original full R20 manifest binding: '+name)
    report = load(BASELINE/'REPORT.json')
    need(report['ok'] is True and report['capture_complete'] is True and report['candidate_commit'] == CAPTURE
         and report['r20_final_gate'] == 'passed', 'original R20 acceptance receipt')
    source = load(BASELINE/'source-candidate.json')
    need(source['commit'] == source['archive']['commit'] == CAPTURE, 'capture source attribution')
    expected_helpers = report['inputs']['helpers']
    for name, digest in expected_helpers.items():
        need(sha(PROJECT/name) == digest, 'executed frozen R20 helper drift: '+name)
        for commit in (BASE, CAPTURE):
            need(hashlib.sha256(D.committed_bytes(commit, name)).hexdigest() == digest,
                 'source-equivalence helper binding: '+name)
    runtime = K.runtime_files(source['archive_files'])
    need(len(runtime) == 564, 'complete delivered runtime inventory')
    for name, digest in runtime.items():
        need(hashlib.sha256(D.committed_bytes(BASE, name)).hexdigest() == digest,
             'promoted R20 runtime differs from delivered capture: '+name)
    return {'restore_sha256':RESTORE_SHA, 'archive_sha256':ARCHIVE_SHA,
            'archive_inventory_sha256':ARCHIVE_FILES_SHA, 'source_equivalence_sha256':EQUIVALENCE_SHA,
            'capture_commit':CAPTURE, 'preservation_commit':BASE, 'selected_files':410,
            'selected_bytes':115983321, 'reference':'only old-look original-map plays',
            'root_reports_scope':'original full accepted R20 48-play matrix; never R21'}


def r20_identity():
    return checked(B.OUTER/'delivery/spillway-r20/BUILD.json', R20_BUILD_SHA)['identity']


def routes():
    retained = K.routes()
    exact([(r['name'], r['map'], r['preset']) for r in retained],
          [(r['name'], r['map'], r['preset']) for r in load(BASELINE/'REPORT.json')['routes']],
          'exact ordered original sixteen routes')
    need(len(retained) == 16 and len({r['map'] for r in retained}) == 8, 'original route count/maps')
    return retained


def route_plan(route):
    # the selected restore lacks expanded tapes/results; the full original archive pins exact expanded bytes.
    inventory = checked(OUTER/'evidence/r20-final-parity-archive/FILES.json', ARCHIVE_FILES_SHA)
    plan = T.expand(load(route['tape']))
    encoded = (json.dumps(plan, indent=1)+'\n').encode()
    wanted = inventory['r20-candidate-parity/'+route['name']+'/expanded.json']['sha256']
    need(hashlib.sha256(encoded).hexdigest() == wanted, 'original expanded tape bytes changed')
    need(plan['submitted_sha256'] == T.sha256_bytes(T.canonical(load(route['tape'])).encode()),
         'submitted original tape binding')
    return plan, encoded


def fixture_binding(route):
    plan, encoded = route_plan(route)
    return {'route':route, 'tape_sha256':sha(Path(route['tape'])),
            'submitted_sha256':plan['submitted_sha256'], 'expanded_sha256':hashlib.sha256(encoded).hexdigest(),
            'golden_sha256':sha(BASELINE/route['name']/'old/runs/golden.r16run')}


def identity_policy():
    identities = {}
    headers = {}
    for route in routes():
        for row in load(BASELINE/route['name']/'old/readers.json'):
            rec = A.read(BASELINE/route['name']/'old/runs'/row['file'])
            need(rec.ok, 'baseline strict reader')
            h = rec.header
            keys(h, K.HEADER_KEYS, 'R20 header')
            keys(h['metadata'], K.META_KEYS, 'R20 metadata')
            keys(h['identity'], K.IDENTITY_KEYS, 'R20 motion identity')
            at = h['identity']['map']+'/'+h['identity']['preset']
            if at in identities:
                exact(identities[at], h['identity'], 'inconsistent R20 identity')
            identities[at] = h['identity']
            headers[at] = {k:h['metadata'][k] for k in ('build','build_label','scoring')}
    need(len(identities) == 16, 'all sixteen actual original map/preset identities required')
    return {'header_fields':sorted(K.HEADER_KEYS), 'metadata_fields':sorted(K.META_KEYS),
            'motion_fields':sorted(K.IDENTITY_KEYS), 'identities':identities, 'metadata':headers,
            'delivered_identity':r20_identity()}


def helpers():
    paths = set(K.helpers()) | set(OWN) | {'tools/package-r21.py', 'tools/check-r21-preservation.py'}
    pending, seen = [K, O, D, G, T], set()
    while pending:
        obj = pending.pop()
        if id(obj) in seen:
            continue
        seen.add(id(obj))
        path = getattr(obj, '__file__', None)
        if path and Path(path).resolve().is_relative_to(PROJECT):
            paths.add(Path(path).resolve().relative_to(PROJECT).as_posix())
            pending.extend(v for v in vars(obj).values() if isinstance(v, types.ModuleType))
    return {p:sha(PROJECT/p) for p in sorted(paths)}


def original_identity_guard(identity):
    baseline = r20_identity()
    keys(identity, set(baseline), 'complete runtime identity')
    for field in ('registry','start','stats_script','audio_script','project_name'):
        exact(identity[field], baseline[field], 'typed exact original '+field)
    for name in (*D.ORIGINAL_MAPS, 'through-line'):
        for field in ('maps','keys'):
            exact(identity[field][name], baseline[field][name], 'typed full original '+field+'/'+name)
    return True


def validate_contract(freeze, contract, commit, identity, files, freeze_sha):
    freeze_schema(freeze, commit)
    exact(freeze['reached_items'], [1,2,3,4], 'complete priority freeze required')
    exact(freeze['runtime']['main_scene'], SCENE, 'actual configured R21 scene')
    exact(freeze['runtime']['main_script'], SCRIPT, 'actual configured R21 script')
    expected = {'schema','kind','status','reviewed_by','candidate_commit','freeze_sha256',
                'baseline_restore_sha256','identity_policy','runtime_sources','verification_helpers',
                'identity','new_metadata','window_titles','menu_registry','ghost_revision_notes','fixtures'}
    keys(contract, expected, 'reviewed R21 parity contract')
    need(type(contract['schema']) is int and contract['schema'] == 1
         and contract['kind'] == 'r21-exact-r20-parity' and contract['status'] == 'REVIEWED'
         and type(contract['reviewed_by']) is str and bool(contract['reviewed_by'].strip()), 'parent review required')
    exact(contract['fixtures'], {r['name']:fixture_binding(r) for r in routes()}, 'reviewed complete original fixture bindings')
    exact(contract['candidate_commit'], commit, 'review for another candidate')
    exact(contract['freeze_sha256'], freeze_sha, 'reviewed freeze binding')
    exact(contract['baseline_restore_sha256'], RESTORE_SHA, 'reviewed baseline binding')
    exact(contract['identity_policy'], identity_policy(), 'complete delivered R20 identity policy')
    exact(contract['runtime_sources'], K.runtime_files(files), 'reviewed whole runtime inventory')
    exact(contract['verification_helpers'], helpers(), 'reviewed whole helper inventory')
    for name, digest in helpers().items():
        need(files.get(name) == digest, 'helper not committed on exact candidate: '+name)
    exact(contract['identity'], identity, 'full reviewed actual identity')
    baseline_identity = r20_identity()
    keys(identity, set(baseline_identity), 'complete runtime identity')
    D.identity_boundary(identity, freeze, baseline_identity)
    original_identity_guard(identity)
    keys(contract['new_metadata'], {'build','build_label'}, 'presentation-only metadata changes')
    exact(contract['new_metadata'], {'build':freeze['runtime']['build'], 'build_label':'Spillway R21'},
          'explicit R21 presentation labels')
    keys(contract['ghost_revision_notes'], {'saltglass','tether-yard'}, 'new map ghost revision notes')
    for note in contract['ghost_revision_notes'].values():
        keys(note, {'source','text'}, 'reviewed revision note source')
        need(note['source'] in files and note['source'].startswith('scripts/')
             and type(note['text']) is str and bool(note['text'].strip())
             and note['text'] in D.committed_bytes(commit, note['source']).decode(), 'unbound ghost revision explanation')
    keys(contract['window_titles'], {r['name'] for r in routes()}, 'route-end window titles')
    need(all(type(v) is str and v.startswith('Spillway R21 · ') for v in contract['window_titles'].values()),
         'exact R21 window titles required')
    menu = contract['menu_registry']
    need(type(menu) is dict and type(menu.get('catalog')) is dict, 'whole actual menu registry required')
    exact(menu.get('order'), list(D.REQUIRED_MAPS), 'reviewed menu order')
    for name in D.REQUIRED_MAPS:
        need(menu['catalog'][name]['script'] == identity['maps'][name]['level_script'], 'menu map source: '+name)
    # the existing preservation owner alone decides changed-old-path permissions and F2 pins.
    D.component_bindings(freeze, files)
    preservation = D.preservation(commit, freeze['intentional_changes'])
    need(len(preservation['F2_pins']) == 6, 'all six F2 source pins')
    settings = D.committed_bytes(commit, 'project.godot').decode()
    need('run/main_scene="'+SCENE+'"' in settings, 'project does not configure actual R21 scene')
    return preservation


def coverage(rows, records):
    expected = {r.header['run_id']:len(r.columns['tick']) for r in records}
    need(len(expected) == len(records), 'duplicate recording run identity')
    seen, closed, current, count = {k:0 for k in expected}, set(), None, 0
    for row in rows:
        run_id, tick = row['run_id'], row['sample']['tick']
        need(run_id in expected and type(tick) is int and tick == seen[run_id]
             and tick < expected[run_id], 'duplicate/reordered/nontyped/unbound observation tick')
        if current != run_id:
            need(run_id not in closed, 'reordered lifecycle observation block')
            if current is not None:
                closed.add(current)
            current = run_id
        seen[run_id] += 1
        count += 1
        yield row
    exact(seen, expected, 'missing first/interior/final observations including event-free samples')


def ordered_records(directory):
    readers = load(directory/'readers.json')
    O.reader_inventory(directory, readers)
    records = [A.read(directory/'runs'/r['file']) for r in readers]
    need(all(r.ok for r in records), 'incomplete/corrupt lifecycle recording')
    records.sort(key=lambda r:(r.header['metadata']['attempt'], r.header['metadata']['map'],
                              r.header['metadata']['preset'], r.header['metadata']['start_reason'],
                              r.seal['outcome']['kind'], len(r.columns['tick'])))
    signatures = [(r.header['metadata']['attempt'], r.header['metadata']['map'], r.header['metadata']['preset'],
                   r.header['metadata']['start_reason'], r.seal['outcome']['kind'], len(r.columns['tick'])) for r in records]
    need(len(set(signatures)) == len(signatures), 'ambiguous lifecycle run-order mapping')
    return records


def record_view(record, contract, side):
    rec, value = C.OLD.recording(record.path, A)
    keys(value['header'], K.HEADER_KEYS-{'run_id','created_unix','created_utc'}, 'canonical recording header')
    meta = value['header']['metadata']
    keys(meta, K.META_KEYS, 'full recording metadata')
    motion = value['header']['identity']
    keys(motion, K.IDENTITY_KEYS, 'recording motion identity')
    exact(motion, contract['identity_policy']['identities'][motion['map']+'/'+motion['preset']], 'original motion identity')
    expected = contract['identity_policy']['metadata'][motion['map']+'/'+motion['preset']]
    for field in ('build','build_label'):
        exact(meta[field], expected[field] if side == 'old' else contract['new_metadata'][field], 'explicit '+side+' '+field)
        meta[field] = expected[field]
    exact(meta['scoring'], expected['scoring'], 'unchanged production scoring identity')
    exact(sorted(rec.columns), sorted(A.COLUMN_NAMES), 'all frozen sample columns')
    exact(sorted(rec.inputs), sorted(n for n,_,_ in A.INPUT_LAYOUT), 'all frozen input columns')
    # packed hashes preserve every binary bit, including signed zero and original scalar types.
    value['columns'] = C.packed_columns(rec.columns, True)
    value['inputs'] = C.packed_columns(rec.inputs)
    return value


def observation_view(rows, records, contract, side):
    bindings = {r.header['run_id']:i for i,r in enumerate(records)}
    for row in coverage(rows, records):
        value = copy.deepcopy(row)
        value['run_id'] = bindings[value['run_id']]
        # every style event, snapshot, diagnostic, ordinary reference and unknown field remains.
        yield value


def toggle_contract(summary, variant, plan):
    moving = [t for t in (40,113,381,700,1200,1900,2600,3400,4400) if t < plan['duration_ticks']]
    labels = ['moving tick '+str(t) for t in moving]+['paused','after map change'] if variant == 'toggle' else []
    exact([r['label'] for r in summary['toggles']], labels, 'all inherited moving/paused/map L operations')
    extra_checks = []
    previous = True
    for index,row in enumerate(summary['toggles']):
        keys(row, {'at','label','before','after','speed_m_s','finished'}, 'toggle observation')
        expected_at = moving[index] if index < len(moving) else plan['duration_ticks']-1
        need(type(row['at']) is int and row['at'] == expected_at, 'toggle tick/order')
        need(type(row['before']) is bool and type(row['after']) is bool
             and row['before'] is previous and row['after'] is not previous, 'actual L transition')
        previous = row['after']
        need(type(row['finished']) is bool and type(row['speed_m_s']) is float
             and __import__('math').isfinite(row['speed_m_s']) and row['speed_m_s'] >= 0, 'toggle field schema')
        extra_checks.extend([row['label']+': actual Input L changed look',
                             row['label']+': L preserved immediate gameplay'])
    if variant == 'toggle':
        extra_checks.append('actual L dispatch occurred during moving unfinished run')
    checks = summary['checks']
    for row in checks:
        keys(row, {'name','ok'}, 'actual executor check')
        need(row['ok'] is True and type(row['name']) is str, 'failed or malformed executor check')
    for name in extra_checks:
        need(sum(c['name'] == name for c in checks) == 1, 'missing/duplicate inherited L invariant: '+name)
    # remove only the exact mandatory additional L assertions to compare the entire old control check list.
    return [c for c in checks if c['name'] not in extra_checks]


def assertion_view(checks, records):
    # bind process-generated names to independently read lifecycle records, never erase assertion text.
    prefix = 'Godot reader validates lifecycle recording '
    names = [r.path.name for r in records]
    need(len(set(names)) == len(names) and all(Path(n).name == n for n in names),
         'ambiguous lifecycle assertion recording names')
    found = []
    result = []
    for row in checks:
        keys(row, {'name','ok'}, 'actual executor assertion')
        need(type(row['name']) is str and row['ok'] is True, 'failed or malformed executor assertion')
        name = row['name']
        if name.startswith(prefix):
            filename = name[len(prefix):]
            need(filename in names, 'reader assertion names an unread recording')
            found.append(filename)
            name = prefix + str(names.index(filename))
        result.append({'name':name, 'ok':True})
    # the frozen executor walks every actual filename in lexical directory order exactly once.
    exact(found, sorted(names), 'missing/duplicate/reordered lifecycle reader assertions')
    return result


def summary_guard(summary, route, variant, plan, contract):
    keys(summary, set(load(BASELINE/route['name']/'old/summary.json')) | {'r21_presentation'}, 'complete actual summary')
    B.host_guard(summary, SCENE, SCRIPT)
    toggle_contract(summary, variant, plan)
    need(summary['variant'] == variant, 'look variant substitution')
    f = summary['finish']
    need(type(f['last_tick']) is int and f['last_tick']+1 == plan['duration_ticks']
         and f['finished'] is True and f['finish_kind'] == 'clean' and f['respawns'] == 0, 'incomplete earned route')
    need(f['map'] == route['map'] and f['preset'] == route['preset'], 'map/preset substitution')
    exact(f['identity'], contract['identity_policy']['identities'][route['map']+'/'+route['preset']], 'finished identity')
    exact(sorted(r['field'] for r in summary['identity_rejections']), sorted(K.IDENTITY_KEYS), 'all identity negatives')
    need(all(r['ok'] is True and bool(r['error']) for r in summary['identity_rejections']), 'ghost refusal failure')
    need(any(c['ok'] is True and c['name'] == 'same golden ghost discovered before moving tape'
             for c in summary['checks']), 'earned baseline ghost not present before movement')
    if variant == 'toggle':
        need(any(t['label'] == 'paused' for t in summary['toggles'])
             and any(t['speed_m_s'] > .1 and not t['finished'] for t in summary['toggles']), 'moving/paused L coverage')
    presentation = summary['r21_presentation']
    keys(presentation, {'window_title','menu_registry'}, 'actual presentation observer')
    exact(presentation['window_title'], contract['window_titles'][route['name']], 'actual window title')
    exact(presentation['menu_registry'], contract['menu_registry'], 'actual complete cross-map menu identities')
    return True


def finish_view(summary, records, original_directory=None):
    value = copy.deepcopy(summary['finish'])
    by_path = {str((original_directory/r.path.name) if original_directory else r.path):i for i,r in enumerate(records)}
    need(value['record_path'] in by_path, 'finish recording path is not an actual ordered recording')
    value['record_path'] = by_path[value['record_path']]
    return value


def route_command(route, variant, source, dest, golden, tape):
    need(variant in VARIANTS, 'unknown variant')
    command = [str(B.GODOT),'--headless','--audio-driver','Dummy','--path',str(source),'--fixed-fps','128',
               '--script','res://tests/r21_parity.gd','--',f'--out={dest}',f'--tape={tape}','--physics-hz=128',
               f'--warmup={route["warmup"]}',f'--map={route["map"]}',f'--preset={route["preset"]}',
               f'--sensitivity={route.get("sensitivity",2.5)}',f'--variant={variant}','--frames=none',
               '--wall-budget-s=150','--host-scene='+SCENE,'--host-script='+SCRIPT,f'--ghost={golden}']
    if variant == 'old':
        command.append('--look=old')
    return command


def engine_guard(engine, old, command, profile):
    value = copy.deepcopy(engine)
    # validate actual process-bound presentation/path metadata before mapping only those exact fields.
    exact(value['cmdline'], ['--script','res://tests/r21_parity.gd'], 'actual executor cmdline')
    exact(value['executor_script'], 'res://tests/r21_parity.gd', 'actual executor script')
    exact(value['game']['node_script'], SCRIPT, 'actual configured host script')
    exact(value['user_args'], command[command.index('--')+1:], 'actual complete route argv')
    expected_data = profile/'xdg_data_home/godot/app_userdata/Spillway'
    exact(value['user_data_dir'], str(expected_data), 'isolated actual user profile')
    for field in ('cmdline','executor_script','user_args','user_data_dir'):
        value[field] = old[field]
    value['game']['node_script'] = old['game']['node_script']
    exact(value, old, 'full engine/input/alias/default-preset configuration')
    return True


def stream(path):
    # strict JSON including duplicate keys/non-finite values; complete newline-delimited observations only.
    with gzip.open(path, 'rt') as incoming:
        for line in incoming:
            need(line.endswith('\n'), 'incomplete raw JSONL row')
            def pairs(items):
                result = {}
                for k,v in items:
                    need(k not in result, 'duplicate trace key: '+k)
                    result[k] = v
                return result
            yield json.loads(line, object_pairs_hook=pairs,
                             parse_constant=lambda v: (_ for _ in ()).throw(Refused('non-finite trace value')))


def bounded_output(before, after, target):
    emitted = 0
    with target.open('wb') as packed, gzip.GzipFile(filename='', mode='wb', fileobj=packed, mtime=0) as output:
        def emit(row):
            nonlocal emitted
            output.write(canonical(row)+b'\n')
            emitted += 1
            if emitted % 256 == 0 and target.is_relative_to(FINAL):
                need(B.allocated_footprint(FINAL) <= B.CAP, 'bounded difference output exceeds candidate cap')
                B.gate()
        result = compare_rows(before, after, emit)
    if target.is_relative_to(FINAL):
        need(B.allocated_footprint(FINAL) <= B.CAP, 'candidate audit output cap')
        B.gate()
    return result
