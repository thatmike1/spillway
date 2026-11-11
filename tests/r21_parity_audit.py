#!/usr/bin/env python3
"""Independent read-back of a complete authorized R21 capture; never launches Godot."""
import gzip
import hashlib
import itertools
from pathlib import Path
import subprocess
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import r21_parity_core as K


def raw_guard(folder, inputs):
    manifest = K.load(folder/'RAW-MANIFEST.json')
    K.need(type(manifest) is dict and bool(manifest), 'missing raw capture manifest')
    for name,digest in manifest.items():
        K.need(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe capture manifest path')
        path = folder/name
        K.need(path.is_file() and not path.is_symlink() and K.sha(path) == digest, 'raw capture changed: '+name)
    found = set()
    for path in folder.rglob('*'):
        K.need(not path.is_symlink(), 'raw evidence symlink')
        if path.is_file() and not path.is_relative_to(folder/'audit'):
            found.add(path.relative_to(folder).as_posix())
    K.exact(sorted(found), sorted([*manifest, 'RAW-MANIFEST.json']), 'unmanifested capture file')
    report = K.load(folder/'REPORT.json')
    K.exact(report['inputs'], inputs, 'review inputs/source/fixture/helper hashes changed')
    K.need(report['ok'] is False and report['r21_final_gate'] == 'pending'
           and report['capture_complete'] is True and report['source_postflight']['ok'] is True
           and report['cleanup']['private_source_import_profile_removed'] is True, 'raw capture incomplete or relabelled')
    K.exact(report['routes'], [{'name':r['name'], 'map':r['map'], 'preset':r['preset'],
                               'variants':list(K.VARIANTS)} for r in K.routes()], '48 fresh ordered plays')
    files = {n:v['sha256'] for n,v in inputs['source']['files'].items()}
    K.exact(report['source_before_import'], files, 'complete pre-import inventory')
    K.exact(K.cache_inventory_guard(report['cache_before_import']), {}, 'empty pristine import cache')
    K.cache_inventory_guard(report['cache_after_import'])
    K.cache_inventory_guard(report['source_postflight']['cache'])
    post_import = {**files, **report['generated_import_metadata']}
    K.exact(report['source_after_import'], post_import, 'complete post-import inventory')
    K.exact(report['source_postflight']['inventory'], post_import, 'complete post-matrix inventory')
    K.exact(report['source_postflight']['helpers'], inputs['helpers'], 'complete post-matrix helper inventory')
    K.exact(report['engine_pins'], K.D.r20.engine_pins(), 'official engine and template pins')
    imported = report['import']
    K.exact(imported['command'], [str(K.B.GODOT),'--headless','--editor','--path',str(folder/'source'),'--import'],
            'actual private import command')
    K.need(imported['exit'] == 0 and imported['owned_scratch_peak_bytes'] <= K.B.CAP
           and imported['minimum_home_free_bytes'] >= K.B.MIN_FREE, 'import result/resource limits')
    K.need(not any(t in (folder/'import.log').read_text() for t in ('ERROR','Parse Error','Assertion failed')), 'raw import error')
    transport = K.load(folder/'TRANSPORT.json')
    K.need(transport['report_sha256'] == K.sha(folder/'REPORT.json'), 'raw report binding')
    expected = []
    previous_cache = report['cache_after_import']
    for route in K.routes():
        result = K.load(folder/route['name']/'result.json')
        K.exact(list(result['runs']), list(K.VARIANTS), 'ordered complete play variants')
        for variant in K.VARIANTS:
            K.cache_inventory_guard(result['runs'][variant]['cache_before'])
            K.cache_inventory_guard(result['runs'][variant]['cache_after'])
            K.exact(result['runs'][variant]['cache_before'], previous_cache, 'cache changed between engine stages')
            previous_cache = result['runs'][variant]['cache_after']
            receipts = result['runs'][variant]['trace_compression']['receipts']
            K.keys(receipts, {'trace.jsonl','ghost.jsonl','observations.jsonl'}, 'all raw trace streams')
            for name in ('trace.jsonl','ghost.jsonl','observations.jsonl'):
                expected.append({'path':route['name']+'/'+variant+'/evaluator/'+name+'.gz', **receipts[name]})
    K.exact(transport['receipts'], expected, 'complete ordered raw transport receipts')
    K.exact(report['source_postflight']['cache'], previous_cache, 'complete final import cache inventory')
    K.need(len(expected) == 144, 'full 48 plays/144 streams required')
    for receipt in expected:
        K.need(receipt['lossless_verified'] is True, 'unverified stream compression')
        path = folder/receipt['path']
        K.need(K.sha(path) == receipt['gzip_sha256'], 'compressed raw stream changed')
        digest, count = hashlib.sha256(), 0
        with gzip.open(path,'rb') as incoming:
            for block in iter(lambda:incoming.read(65536), b''):
                digest.update(block)
                count += len(block)
        K.need(digest.hexdigest() == receipt['raw_sha256'] and count == receipt['raw_bytes'], 'incomplete/changed raw stream')
    metadata = folder/'generated-import-metadata'
    K.exact({p.relative_to(metadata).as_posix():K.sha(p) for p in metadata.rglob('*') if p.is_file()},
            report['generated_import_metadata'], 'retained generated sidecars')
    K.G.import_metadata_guard(metadata, report['generated_import_metadata'], inputs['source']['files'])
    return report


def independent_ghost(directory, golden, plan):
    reference = K.module('r21_frozen_ghost_pose', K.PROJECT/'tests/r20_parity_provenance.py')
    rec = K.A.read(golden)
    K.need(rec.ok, 'strict golden reader refused')
    pose_at = reference.ghost_track(rec)
    count = 0
    for count,(trace, ghost) in enumerate(itertools.zip_longest(K.stream(directory/'evaluator/trace.jsonl.gz'),
                                                              K.stream(directory/'evaluator/ghost.jsonl.gz')), 1):
        K.need(trace is not None and ghost is not None, 'ghost or clock truncated')
        K.need(type(trace['tick']) is int and trace['tick'] == count-1
               and type(ghost['tick']) is int and ghost['tick'] == count-1, 'ghost/physics tick order/type')
        K.need(ghost['loaded'] is True and ghost['shown'] is True, 'earned golden ghost disappeared')
        K.exact(pose_at(trace['elapsed']), ghost['pose_at_clock'], 'independent original golden pose at actual clock')
    K.need(count == plan['duration_ticks'], 'missing first/interior/final ghost/physics row')
    return count


def audit_route(folder, route, inputs, output):
    base = K.BASELINE/route['name']/'old'
    directory = folder/route['name']
    result = K.load(directory/'result.json')
    K.exact(result['route'], route, 'exact original route binding')
    plan, encoded = K.route_plan(route)
    K.need((directory/'expanded.json').read_bytes() == encoded, 'raw expanded tape changed')
    contract = inputs['contract']
    original_summary = K.load(base/'summary.json')
    originals = K.ordered_records(base)
    baseline_audit, _ = K.O.observation_audit(base, K.A)
    K.need(baseline_audit['ok'], 'full R20 original baseline observation accounting failed')
    original_views = [K.record_view(r, contract, 'old') for r in originals]
    comparisons, variant_records = {}, {}
    for variant in K.VARIANTS:
        run_dir = directory/variant
        run = result['runs'][variant]
        K.exact(run['helpers'], inputs['helpers'], 'executed helpers')
        K.exact(run['summary'], K.load(run_dir/'summary.json'), 'raw summary binding')
        golden = base/'runs/golden.r16run'
        command = K.route_command(route, variant, folder/'source', run_dir, golden, directory/'expanded.json')
        K.exact(run['command'], command, 'actual configured command/source/tape/ghost')
        K.need(K.sha(run_dir/'runs/golden.r16run') == K.sha(golden), 'actual initial earned golden bytes')
        K.need(run['ok'] is True and run['exit'] == 0 and not run['engine_errors']
               and run['owned_scratch_peak_bytes'] <= K.B.CAP and run['minimum_home_free_bytes'] >= K.B.MIN_FREE,
               'failed/oversized candidate engine run')
        K.need(not any(t in (run_dir/'engine.log').read_text() for t in ('ERROR','Parse Error','Assertion failed')),
               'raw engine errors were hidden')
        K.summary_guard(run['summary'], route, variant, plan, contract)
        K.engine_guard(K.load(run_dir/'evaluator/engine.json'), K.load(base/'evaluator/engine.json'), command, folder/'profile')
        observed, _ = K.O.observation_audit(run_dir, K.A)
        K.need(observed['ok'], 'both readers/all samples/input/scored/diagnostic/seal/reference audit failed')
        records = K.ordered_records(run_dir)
        K.need(len(records) == len(originals), 'missing/extra lifecycle recording')
        views = [K.record_view(r, contract, 'new') for r in records]
        variant_records[variant] = records
        metrics = {}
        metrics['recordings'] = K.bounded_output(original_views, views, output/(variant+'-recordings.jsonl.gz'))
        metrics['motion'] = K.bounded_output(K.stream(base/'evaluator/trace.jsonl.gz'),
                                               K.stream(run_dir/'evaluator/trace.jsonl.gz'), output/(variant+'-motion.jsonl.gz'))
        metrics['ghost'] = K.bounded_output(K.stream(base/'evaluator/ghost.jsonl.gz'),
                                              K.stream(run_dir/'evaluator/ghost.jsonl.gz'), output/(variant+'-ghost.jsonl.gz'))
        metrics['observations'] = K.bounded_output(
            K.observation_view(K.stream(base/'evaluator/observations.jsonl.gz'), originals, contract, 'old'),
            K.observation_view(K.stream(run_dir/'evaluator/observations.jsonl.gz'), records, contract, 'new'),
            output/(variant+'-observations.jsonl.gz'))
        metrics['controls'] = K.bounded_output(original_summary['tour'], run['summary']['tour'], output/(variant+'-controls.jsonl.gz'))
        old_origin = Path('/tmp/r20-candidate-parity')/route['name']/'old/runs'
        metrics['finish'] = K.bounded_output([K.finish_view(original_summary, originals, old_origin)],
                                                [K.finish_view(run['summary'], records)], output/(variant+'-finish.jsonl.gz'))
        # all original controls/checks survive; presentation is checked separately above, never grounds for dropping tours.
        K.exact(K.assertion_view(K.toggle_contract(run['summary'], variant, plan), records),
                K.assertion_view(original_summary['checks'], originals), 'all original executor assertions')
        for field in ('identity_rejections','setup_writes','scope'):
            K.exact(run['summary'][field], original_summary[field], 'complete original summary '+field)
        K.need(all(m['ok'] for m in metrics.values()), 'R20 exact parity failed; all differences retained')
        finish_record = next(r for r in records if str(r.path) == run['summary']['finish']['record_path'])
        K.need(K.C.ordered_tape_audit(finish_record, plan, route['warmup'])['ok'], 'complete ordered original input tape')
        K.need(K.C.OLD.recording_alignment(finish_record, run_dir/'evaluator/trace.jsonl.gz', route['warmup'])['ok'],
               'binary recording/physical tape alignment')
        kinds = {r.seal['outcome']['kind'] for r in records}
        K.need({'finish','restart','practice','preset','map','quit'} <= kinds, 'full lifecycle control seals')
        K.need({'pause','resume','ghost'} <= {e['k'] for r in records for e in r.events}, 'pause/resume/ghost recorded controls')
        independent_ghost(run_dir, golden, plan)
        if route['name'] == 'r16-lab-flow':
            K.lab_guard(K.stream(run_dir/'evaluator/trace.jsonl.gz'))
        comparisons[variant] = {'exact':metrics, 'independent_samples':observed}
    # explicit cross-variant equality supplements each comparison with the same delivered R20 physical reference.
    for variant in ('new','toggle'):
        for stream in ('trace','ghost'):
            comparison = K.bounded_output(K.stream(directory/'old/evaluator'/(stream+'.jsonl.gz')),
                                           K.stream(directory/variant/'evaluator'/(stream+'.jsonl.gz')),
                                           output/('old-'+variant+'-'+stream+'.jsonl.gz'))
            K.need(comparison['ok'], 'cross-variant '+stream+' drift')
        comparison = K.bounded_output(
            K.observation_view(K.stream(directory/'old/evaluator/observations.jsonl.gz'), variant_records['old'], contract, 'new'),
            K.observation_view(K.stream(directory/variant/'evaluator/observations.jsonl.gz'), variant_records[variant], contract, 'new'),
            output/('old-'+variant+'-observations.jsonl.gz'))
        K.need(comparison['ok'], 'cross-variant observation drift')
    return comparisons


def negative_seed(directory, output, contract, side):
    """Challenge actual decoded bytes with repaired chains, without editing any capture."""
    mutation = K.module('r21_retained_mutator', K.PROJECT/'tests/r20_parity_mutations.py')
    header_editor = K.module('r21_parity_mutation_support', K.PROJECT/'tests/test_r21_parity.py').edit_header
    records = K.ordered_records(directory)
    seed = next(r for r in records if r.seal['outcome']['kind'] == 'finish')
    data = Path(seed.path).read_bytes()
    original = K.record_view(seed, contract, side)
    checks = []
    output.mkdir()
    path = output/'working.r16run'
    def challenge(name, payload):
        path.write_bytes(payload)
        parsed = K.A.read(path)
        refused = not parsed.ok
        if not refused:
            try:
                current = K.record_view(parsed, contract, side)
                refused = next(K.differences(original, current), None) is not None
            except (ValueError, AssertionError, KeyError, TypeError):
                refused = True
        checks.append({'name':name, 'refused':refused, 'mutant_sha256':K.sha(path)})
        K.need(refused, 'actual candidate mutation was not refused: '+name)
        K.B.gate()
        if output.is_relative_to(K.FINAL):
            K.need(K.B.allocated_footprint(K.FINAL) <= K.B.CAP, 'candidate negative control cap')
    try:
        for group,names in [('columns',K.A.COLUMN_NAMES),('inputs',[n for n,_,_ in K.A.INPUT_LAYOUT])]:
            for name in names:
                challenge(group+'.'+name, mutation.rewrite(data, mutation.column_edit(group, name)))
        for group,fields in [('metadata',K.META_KEYS),('identity',K.IDENTITY_KEYS)]:
            for name in sorted(fields):
                challenge('header.'+group+'.'+name,
                          header_editor(data,lambda h,g=group,n=name:h[g].__setitem__(n,{'unreviewed':n})))
        for group in ('metadata','identity'):
            challenge('unknown '+group, header_editor(data,lambda h,g=group:h[g].update(unreviewed=True)))
        duplicate_editor = K.module('r21_shadowed_JSON_support', K.PROJECT/'tests/test_r21_parity.py').duplicate_record_json
        for section in ('header','events','seal'):
            challenge('hash-valid duplicate JSON '+section, duplicate_editor(data,section))
        source = directory/'evaluator/observations.jsonl.gz'
        def without_row(position):
            previous = None
            for i,row in enumerate(K.stream(source)):
                if position == 'final':
                    if previous is not None:
                        yield previous
                    previous = row
                elif i != position:
                    yield row
            if position == 'final':
                K.need(previous is not None and previous['style_events'] == [], 'negative requires actual event-free final sample')
        for position in (0,10,'final'):
            try:
                sum(1 for _ in K.coverage(without_row(position),records))
            except (ValueError,AssertionError,KeyError,TypeError):
                refused = True
            else:
                refused = False
            checks.append({'name':'missing actual observation '+str(position), 'refused':refused})
            K.need(refused, 'missing actual sample was accepted')
        result = {'ok':all(c['refused'] for c in checks), 'checks':checks,
                  'seed_sha256':K.sha(seed.path), 'view':side,
                  'scope':'actual byte/header/coverage mutations only; not a fresh-play or full-matrix acceptance'}
        K.B.write(output/'SUMMARY.json',result)
        return result
    finally:
        if path.exists():
            path.unlink()


def original_controls(output):
    # unchanged R19 proof is used only for the original 56 negatives, never as R21 physical reference.
    before = K.K.baseline_guard()
    directory = output/'original-56-controls'
    K.need(not directory.exists(), 'original controls need a fresh bounded output')
    command = [sys.executable,'-B',str(K.PROJECT/'tests/r20_parity_mutations.py'),
               str(K.K.BASELINE),'--out',str(directory)]
    with (output/'original-controls.log').open('w') as log:
        process = subprocess.Popen(command, cwd=K.PROJECT, stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                K.need(K.B.allocated_footprint(output.parent.parent) <= K.B.CAP, 'negative controls exceed total candidate cap')
                K.B.gate()
                time.sleep(.1)
            K.need(process.wait() == 0, 'original negative controls failed; see retained log')
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait()
    result = K.load(directory/'SUMMARY.json')
    K.need(result['ok'] is True and len(result['checks']) == 56 and all(c['ok'] for c in result['checks']),
           'unchanged original 56 controls failed or skipped')
    K.exact(K.K.baseline_guard(), before, 'R19 negative-control-only proof changed')
    return {'checks':56, 'summary_sha256':K.sha(directory/'SUMMARY.json'),
            'scope':'unchanged original negative controls only; no R19 R21 physical reference'}


def audit(args, inputs):
    K.need(args.out == K.FINAL and args.out.is_dir(), 'exact completed capture directory required')
    folder = args.out
    output = folder/'audit'
    output.mkdir(exist_ok=True)
    # revoke a previous success receipt before reading any fallible evidence.
    K.B.write(output/'AUDIT.json', {'ok':False, 'r21_final_gate':'pending'})
    raw_guard(folder, inputs)
    results = []
    try:
        for route in K.routes():
            target = output/route['name']
            target.mkdir(exist_ok=True)
            results.append({'route':route['name'], 'comparisons':audit_route(folder, route, inputs, target)})
            K.need(K.B.allocated_footprint(folder) <= K.B.CAP, 'complete candidate-owned evidence exceeds 600MiB')
            K.B.gate()
            K.B.write(output/'PROGRESS.json', {'ok':False, 'routes':results})
        negative_output = output/'negative-controls'
        if negative_output.exists():
            # only derived outputs of this auditor are replaceable; raw proof is immutable.
            shutil = __import__('shutil')
            shutil.rmtree(negative_output)
        negative_output.mkdir()
        negatives = original_controls(negative_output)
        candidate_negatives = negative_seed(folder/'breakwater-basic/new', negative_output/'actual-candidate',
                                           inputs['contract'], 'new')
        K.exact(K.baseline_guard(), inputs['baseline'], 'baseline changed during independent audit')
        K.exact(K.helpers(), inputs['helpers'], 'helpers changed during independent audit')
        K.B.gate()
        K.need(K.B.allocated_footprint(folder) <= K.B.CAP, 'final owned evidence cap')
        K.B.write(output/'AUDIT.json', {'ok':True, 'r21_final_gate':'passed', 'candidate_commit':inputs['candidate_commit'],
                                      'routes':results, 'original_controls':negatives, 'candidate_controls':candidate_negatives,
                                      'raw_manifest_sha256':K.sha(folder/'RAW-MANIFEST.json'),
                                      'scope':'headless source parity only; no native/export/Windows/enjoyment claim'})
    except BaseException as error:
        K.B.write(output/'AUDIT.json', {'ok':False, 'r21_final_gate':'pending', 'error':repr(error), 'routes':results})
        raise
    print('R21 independent source parity passed: 48 fresh plays, original 56 controls; no delivery claim')
    return 0


if __name__ == '__main__':
    driver = K.module('r21_audit_driver', K.PROJECT/'tools/check-r21-parity.py')
    raise SystemExit(driver.main())
