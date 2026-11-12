import gzip,hashlib,itertools
from pathlib import Path
import parity_core as K
import mutations
def independent_ghost(directory, golden, plan):
    reference = mutations
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
    mutation = mutations
    header_editor = mutations.edit_header
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
        duplicate_editor = mutations.duplicate_record_json
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
