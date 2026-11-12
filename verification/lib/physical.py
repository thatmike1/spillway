import importlib.util,copy,gzip,hashlib,itertools,json,math,re,struct
from pathlib import Path
import legacy as OLD
sha,write,difference,stream = OLD.sha,OLD.write,OLD.difference,None
NEW_KINDS = {"backward_bhop","sideways_bhop"}
def module(path, name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def physical(row):
    """only the top-level style snapshot belongs in the separate scoring comparison."""
    return {key:value for key,value in row.items() if key != 'style'}


def godot_number(text):
    """independent exact reference for Godot String.to_float's published built_in_strtod algorithm.

    JSON numbers use this parser, not correctly-rounded libc strtod. Reproduce the
    18-digit mantissa/powers-of-ten operations exactly, without a numeric tolerance.
    https://github.com/godotengine/godot/blob/master/core/string/ustring.cpp
    """
    mantissa, _, exponent_text = text.lower().partition('e')
    exponent = int(exponent_text or 0)
    sign = -1 if mantissa.startswith('-') else 1
    mantissa = mantissa.lstrip('+-')
    integer, _, fraction = mantissa.partition('.')
    digits = integer + fraction
    count = min(len(digits),18)
    exponent += len(integer) - count
    digits = digits[:count]
    value = 1e9 * int(digits[:-9] or 0) + int(digits[-9:] or 0)
    scale = 1.0
    remaining = min(abs(exponent),511)
    for power in [10.,100.,1e4,1e8,1e16,1e32,1e64,1e128,1e256]:
        if remaining & 1:
            scale *= power
        remaining >>= 1
    return sign * (value / scale if exponent < 0 else value * scale)


def godot_json_reader(analyzer):
    import types
    expected = module(Path(analyzer.__file__),'r19_godot_json_reference')
    expected.json = types.SimpleNamespace(loads=lambda data,**kwargs:json.loads(data,parse_float=godot_number,parse_int=godot_number,**kwargs))
    return expected


def reader_difference(a, b, path='$'):
    # godot's JSON parser represents all JSON numbers as doubles; retain exact values, not that parser's numeric tag.
    if type(a) in (int,float) and type(b) in (int,float):
        return None if a == b else {'path':path,'a':a,'b':b}
    if isinstance(a,dict) and isinstance(b,dict) and a.keys() == b.keys():
        for key in a:
            found = reader_difference(a[key],b[key],path+'.'+key)
            if found:
                return found
        return None
    if isinstance(a,list) and isinstance(b,list) and len(a) == len(b):
        for i,(x,y) in enumerate(zip(a,b)):
            found = reader_difference(x,y,path+f'[{i}]')
            if found:
                return found
        return None
    return difference(a,b,path)


def validate_style_fixture(contract, baseline_sha, candidate_sha):
    assert contract['baseline_style_sha256'] == baseline_sha and contract['candidate_style_sha256'] == candidate_sha
    path = Path(contract['fixture_evidence']['path'])
    assert sha(path) == contract['fixture_evidence']['sha256']
    proof = json.loads(path.read_text())
    assert proof['ok'] and proof['source_hashes']['baseline_style_sha256'] == baseline_sha and proof['source_hashes']['candidate_style_sha256'] == candidate_sha
    raw_path = Path(proof['raw_summary']['path'])
    assert sha(raw_path) == proof['raw_summary']['sha256']
    raw = json.loads(raw_path.read_text())
    assert raw['failed'] == 0 and len(raw['checks']) == 25 and raw['checks'] == proof['checks'] and all(c['pass'] for c in raw['checks'])
    required = {'backwards_earned_and_growing','sideways_earned_and_smaller','multiplier_caps','actual_hops_and_real_speed',
                'idle_no_direction_award','slow_no_direction_award','walk_no_direction_award','tiny_no_direction_award',
                'fake_hop_counters_and_grounded_jump_events_do_not_pay','respawn_requires_two_new_hops','teleport_detected',
                'teleport_requires_two_new_hops','revisited_line_cannot_farm','reversing_heading_breaks_chain',
                'forward_exact_r18_events_and_score','forward_existing_events_present','observer_never_writes_body'}
    assert required <= {c['name'] for c in raw['checks']}
    forward = next(c for c in raw['checks'] if c['name'] == 'forward_exact_r18_events_and_score')
    assert proof['forward_exact_samples'] == int(forward['detail'].split()[0]) >= 2000
    for relative,digest in proof['raw_files'].items():
        assert sha(path.parent/relative) == digest, ('style raw evidence changed',relative)
    binding = Path(proof['bindings']['path'])
    assert sha(binding) == proof['bindings']['sha256']
    sources = json.loads(binding.read_text())
    assert sources['injected']['tests/r19_baseline_style.gd'] == baseline_sha
    assert sources['injected']['tests/r19_style_bhop.gd'] == proof['source_hashes']['test_sha256']
    return proof


def validate_revision(revision):
    assert set(revision) == {'baseline_identity','candidate_identity','routes','off_line_routes','evidence','presets'}, 'unknown revision contract schema'
    assert set(revision['routes']) == set(revision['off_line_routes']) == {'breakwater-basic','breakwater-return'}, 'only proven off-line retained routes supported'
    old,new = revision['baseline_identity'],revision['candidate_identity']
    keys = {'format','map','preset','course_key','geometry','overlay','physics_hz','motor','runner','timing'}
    assert set(old) == set(new) == keys
    assert old['map'] == new['map'] == 'breakwater'
    assert old['overlay'].startswith('r16-opportunities-1:') and new['overlay'].startswith('r19-breakwater-flow-1:')
    assert all(old[k] != new[k] for k in ['geometry','overlay','course_key'])
    assert difference({k:v for k,v in old.items() if k not in ['geometry','overlay','course_key']},
                      {k:v for k,v in new.items() if k not in ['geometry','overlay','course_key']}) is None
    proof = Path(revision['evidence']['path'])
    assert sha(proof) == revision['evidence']['sha256'], 'targeted proof hash mismatch'
    evidence = json.loads(proof.read_text())
    assert evidence['ok'] and evidence['failed'] == 0 and evidence['checks'] and all(c['ok'] for c in evidence['checks'])
    row = next(r for r in evidence['maps'] if r['map'] == 'breakwater')
    assert row['before']['identity'] == old and row['after']['identity'] == new, 'proof does not bind both supplied identities'
    assert revision['presets'] == {side:row[which]['presets'] for side,which in [('baseline','before'),('candidate','after')]}
    assert set(revision['presets']['baseline']) == set(revision['presets']['candidate']) == {'server128','server128_aa1000'}
    for preset in revision['presets']['baseline']:
        a,b = [revision['presets'][side][preset]['metadata'] for side in ['baseline','candidate']]
        assert a['record_identity'][1] == b['record_identity'][1] and a['record_identity'][3] == b['record_identity'][3]
        assert a['opportunities']['applied'] == b['opportunities']['applied'] and a['opportunities']['passages'] == b['opportunities']['passages']
        assert len(a['record_identity']) == len(b['record_identity']) == 13
        assert difference([v for i,v in enumerate(a['record_identity']) if i not in [2,12]],
                          [v for i,v in enumerate(b['record_identity']) if i not in [2,12]]) is None
        assert {k:v for k,v in a['opportunities'].items() if k not in ['version','reason','hash','base_geometry']} == {k:v for k,v in b['opportunities'].items() if k not in ['version','reason','hash','base_geometry']}
        for meta in [a,b]:
            assert meta['overlay'] == meta['opportunities']['version']+':'+meta['opportunities']['hash']
            assert meta['identity']['geometry'] == meta['opportunities']['base_geometry'] == meta['record_identity'][2]
        assert b['opportunities']['version'] == 'r19-breakwater-flow-1'
        assert b['opportunities']['reason'] == 'widen_optional_thread_after_repeated_front_contacts'
    return revision


def validate_record_identity(header, text):
    meta, identity = header['metadata'],header['identity']
    ordered = meta['record_identity']
    assert len(ordered) == 13 and len(ordered[1]) == 5, 'ordered record identity schema changed'
    assert reader_difference(json.loads(text),ordered) is None, 'identity text/header mismatch'
    assert hashlib.sha256(text.encode()).hexdigest()[:16] == identity['course_key'] == meta['course_key'], 'record identity course key hash mismatch'
    assert identity == meta['identity'], 'own header and metadata identities differ'
    for key,value in [('map',ordered[1][0]),('geometry',ordered[2]),('preset',ordered[4]),('motor',ordered[6]),
                      ('runner',ordered[7]),('physics_hz',ordered[8]),('timing',ordered[0]),('overlay',ordered[12])]:
        assert identity[key] == value, ('record identity/header relation',key)
    assert meta['map'] == ordered[1][0] and meta['map_kind'] == ordered[1][1] and meta['preset'] == ordered[4] and meta['family'] == ordered[5]
    for index,key in [(9,'fingerprint'),(10,'hull'),(11,'mechanics')]:
        assert reader_difference(json.loads(ordered[index]),meta['physics'][key]) is None, ('ordered physics/header relation',key)


def revision_state(state, revisions, side):
    state = copy.deepcopy(state)
    identity = state['identity']
    if identity['map'] not in revisions:
        return state
    revision = revisions[identity['map']]
    contract = revision['presets'][side][identity['preset']]['metadata']
    assert identity == contract['identity'] and state['course_key'] == identity['course_key'], 'unexpected revised motion identity'
    for key in ['geometry','overlay','course_key']:
        state['identity'][key] = '<verified revision '+key+'>'
    state['course_key'] = '<verified revision course_key>'
    return state


def revision_record(value, revisions, side):
    value = copy.deepcopy(value)
    header = value['header']
    meta = header['metadata']
    if meta['map'] not in revisions:
        return value
    revision = revisions[meta['map']]
    contract = revision['presets'][side][meta['preset']]['metadata']
    assert header['identity'] == meta['identity'] == contract['identity'], 'unexpected revised recording identity'
    assert meta['course_key'] == header['identity']['course_key']
    ordered = meta['record_identity']
    assert len(ordered) == 13 and len(ordered[1]) == 5, 'ordered record identity schema changed'
    assert ordered[1] == contract['record_identity'][1] and ordered[3] == contract['record_identity'][3], 'map identity or stage titles changed'
    assert ordered[2] == contract['record_identity'][2] and ordered[12] == contract['record_identity'][12]
    assert meta['overlay'] == contract['overlay'] and meta['opportunities'] == contract['opportunities'], 'unexpected revision metadata/opportunities'
    assert set(meta['opportunities']) == {'version','applied','reason','hash','base_geometry','passages'}
    for identity in [header['identity'],meta['identity']]:
        for key in ['geometry','overlay','course_key']:
            identity[key] = '<verified revision '+key+'>'
    meta['course_key'] = '<verified revision course_key>'
    meta['overlay'] = ordered[12] = '<verified revision overlay>'
    ordered[2] = '<verified revision geometry>'
    for key in ['version','reason','hash','base_geometry']:
        meta['opportunities'][key] = '<verified revision '+key+'>'
    return value


def geometry_guard(a, b, revisions):
    """off-line retained lines require every physical/view/input/clock field to match exactly."""
    bad,count = [],0
    try:
        for count,(x,y) in enumerate(itertools.zip_longest(stream(a),stream(b)),1):
            if x is None or y is None:
                return {'ok':False,'difference':'route length changed'}
            found = difference(physical(revision_state(x,revisions,'baseline')),physical(revision_state(y,revisions,'candidate')))
            if found and len(bad)<4:
                bad.append({'row':count-1,**found})
    except (AssertionError,KeyError,TypeError) as exc:
        return {'ok':False,'difference':str(exc)}
    return {'ok':not bad,'rows':count,'first_differences':bad}


def geometry_record_guard(old, new, revisions):
    """preserve the complete recording after verifying and normalizing only exact revision identities."""
    try:
        a,_,_ = record_compare_view(old)
        b,_,_ = record_compare_view(new)
        found = difference(revision_record(a,revisions,'baseline'),revision_record(b,revisions,'candidate'))
        return {'ok':found is None,'first_difference':found}
    except (AssertionError,KeyError,TypeError) as exc:
        return {'ok':False,'first_difference':str(exc)}


def packed_columns(columns, vectors=False):
    codes = {'tick':'i','flags':'i','dt':'d','elapsed':'d','physics_hz':'i','checkpoint':'i','respawns':'i',
             'yaw':'d','pitch':'d','held':'q'} if vectors else {'tick':'i','kind':'i','flags':'i','code':'q','aux':'q','x':'f','y':'f','x2':'f','y2':'f'}
    result = {}
    for key, code in codes.items():
        result[key] = hashlib.sha256(struct.pack(f'<{len(columns[key])}{code}', *columns[key])).hexdigest()
    if vectors:
        for key in ['p','reference_p','v','actual_v']:
            values = [v for i in range(len(columns['tick'])) for v in [columns[key+'_'+a][i] for a in 'xyz']]
            result[key] = hashlib.sha256(struct.pack(f'<{len(values)}f', *values)).hexdigest()
    return result


def record_compare_view(value):
    """explicit score/label separation; no motion identity, version, map or physics key removed."""
    value = copy.deepcopy(value)
    scoring = {'header':value['header']['metadata'].pop('scoring', None),
               'outcome':value['seal']['outcome'].pop('style', None)}
    labels = {key:value['header']['metadata'].pop(key, None) for key in ['build','build_label']}
    scoring['events'] = [e for e in value['events'] if e.get('s') == 'capture']
    value['events'] = [e for e in value['events'] if e.get('s') != 'capture']
    for i,event in enumerate(value['events']):
        event['q'] = i
    # byte offsets and event counts are validated against each actual stream, then reported separately.
    scoring['storage'] = {key:value['seal']['counts'].pop(key) for key in ['bytes','events']}
    return value, scoring, labels


def detector_comparison(a, b):
    """existing detector decisions/geometry must match; directional awards and multipliers are explicit."""
    old = [e['d'] for e in a['events']]
    new = [e['d'] for e in b['events'] if e['d']['kind'] not in NEW_KINDS]
    altered = []
    for x,y in itertools.zip_longest(old,new):
        if x is None or y is None:
            return {'ok':False, 'difference':'existing detector count changed'}
        y = copy.deepcopy(y)
        direction = y.pop('direction_mult', 1.0)
        combo = y.pop('combo_mult', y['mult'])
        # when directional multiplier is one, the old award must have exactly the old score.
        if direction != 1.0:
            altered.append({'tick':y['tick'],'kind':y['kind'],'old_points':x['points'],'new_points':y['points'],'direction_mult':direction})
            y['points'] = x['points']
        y['mult'] = combo
        found = difference(x,y)
        if found:
            return {'ok':False, 'difference':found}
    return {'ok':True, 'existing_events':len(old), 'directional_point_changes':altered,
            'new_awards':len(b['events'])-len(new)}


def observation_audit(run_dir, analyzer):
    """cross-reader agreement plus every attempt's actual pose/input/style alignment."""
    readers = json.loads((run_dir/'readers.json').read_text())
    observations = run_dir/'evaluator/observations.jsonl.gz'
    records, by_id, checks = [], {}, []
    godot_expected_reader = godot_json_reader(analyzer)
    for row in readers:
        path = run_dir/'runs'/row['file']
        rec, canonical = OLD.recording(path, analyzer)
        validate_record_identity(rec.header,row['identity_text'])
        godot_expected = godot_expected_reader.read(path)
        assert godot_expected.ok, godot_expected.errors
        by_id[rec.header['run_id']] = (rec, row)
        cross = difference(packed_columns(rec.columns, True), row['columns_sha256'])
        inputs = difference(packed_columns(rec.inputs), row['inputs_sha256'])
        checks.append({'ok':cross is None and inputs is None and sha(path) == row['sha256'] and
                       reader_difference(godot_expected.header,row['header']) is None and reader_difference(godot_expected.events,row['events']) is None and
                       reader_difference(godot_expected.seal,row['seal']) is None, 'name':'both readers decode all bytes '+row['file'], 'difference':cross or inputs})
        assert all(int(e['q']) == i for i,e in enumerate(rec.events)), 'event sequence is not dense'
        assert rec.seal['counts']['events'] == len(rec.events)
        records.append(canonical)
    seen = set()
    count = inputs_checked = style_checked = 0
    failures = []
    f32 = lambda x: struct.unpack('<f', struct.pack('<f',x))[0]
    held_tables, input_tables, style_tables = {}, {}, {}
    for run_id,(rec,_) in by_id.items():
        held_tables[run_id] = next(e['d']['names'] for e in rec.events if e['k'] == 'held_names')
        actions = {e['d']['index']:e['d']['name'] for e in rec.events if e['k'] == 'action_name'}
        input_tables[run_id] = {}
        ins = rec.inputs
        for j,tick in enumerate(ins['tick']):
            kind = ins['kind'][j]
            if kind == 1:
                event = {'type':'key','keycode':ins['code'][j],'physical_keycode':ins['aux'][j],
                         'pressed':bool(ins['flags'][j]&1),'echo':bool(ins['flags'][j]&2)}
            elif kind == 3:
                event = {'type':'mouse_motion','screen_relative':[ins['x'][j],ins['y'][j]],'relative':[ins['x2'][j],ins['y2'][j]]}
            elif kind == 4:
                event = {'type':'action','action':actions[ins['code'][j]],'pressed':bool(ins['flags'][j]&1)}
            else:
                raise AssertionError(('unexpected retained-route input kind',kind))
            input_tables[run_id].setdefault(tick,[]).append(event)
        style_tables[run_id] = {}
        for e in rec.events:
            if e.get('s') == 'capture':
                style_tables[run_id].setdefault(e['t'],[]).append(e['d'])
    for row in stream(observations):
        run_id, sample, actual = row['run_id'], row['sample'], row['actual']
        assert run_id in by_id, ('observation has no completed recording',run_id)
        rec,_ = by_id[run_id]
        i = int(sample['tick'])
        assert (run_id,i) not in seen and i < len(rec.columns['tick'])
        seen.add((run_id,i))
        c = rec.columns
        wanted = {k:sample[k] for k in ['tick','dt','physics_hz','elapsed','checkpoint','respawns','yaw','pitch']}
        wanted['flags'] = sum(int(sample[k])<<bit for bit,k in enumerate(['started','finished','clean','grounded','ducked']))
        wanted['held'] = sum(int(bool(sample['held'].get(name,False)))<<bit for bit,name in enumerate(held_tables[run_id]))
        for group in ['p','reference_p','v','actual_v']:
            for axis,value in zip('xyz',sample[group]):
                wanted[group+'_'+axis] = f32(value)
        got = {k:c[k][i] for k in wanted}
        observed = {k:sample[k] for k in ['p','v','yaw','pitch','grounded','ducked','elapsed','checkpoint','respawns','started','finished','clean','motion','stats']}
        want_inputs = copy.deepcopy(sample['input_events'])
        for event in want_inputs:
            if event['type'] == 'mouse_motion':
                for field in ['relative','screen_relative']:
                    event[field] = [f32(v) for v in event[field]]
        found = difference(wanted,got) or difference(observed,{k:actual[k] for k in observed}) or difference(want_inputs,input_tables[run_id].get(i,[])) or reader_difference(row['style_events'],style_tables[run_id].get(i,[]))
        if found and len(failures) < 4:
            failures.append({'run_id':run_id,'tick':i, **found})
        count += 1
        inputs_checked += len(want_inputs)
        style_checked += len(row['style_events'])
    expected = sum(len(rec.columns['tick']) for rec,_ in by_id.values())
    checks.append({'ok':count == expected and not failures, 'name':'every attempt sample matches actual body, inputs and style events',
                   'observed':count,'expected':expected,'first_differences':failures})
    checks.append({'ok':inputs_checked == sum(len(rec.inputs['tick']) for rec,_ in by_id.values()) and
                   style_checked == sum(len(events) for table in style_tables.values() for events in table.values()),
                   'name':'no unmatched input or style event', 'input_rows':inputs_checked,'style_events':style_checked})
    for rec,_ in by_id.values():
        events = [e['d'] for e in rec.events if e.get('s') == 'capture']
        tally = {}
        for event in events:
            kind = event['kind']
            n,p = tally.get(kind,(0,0))
            tally[kind] = (n+1,p+int(event['points']))
        score = rec.seal['outcome']['style']
        checks.append({'ok':sum(p for _,p in tally.values()) == score['score'] and
                       {k:{'n':n,'points':p} for k,(n,p) in tally.items()} == score['by_kind'], 'name':'independent style tally '+rec.path.name})
    records.sort(key=lambda r:(r['header']['metadata']['attempt'],r['header']['metadata']['map'],r['header']['metadata']['preset'],
                              r['header']['metadata']['start_reason'],r['seal']['outcome']['kind'],len(r['columns']['tick'])))
    return {'ok':all(c['ok'] for c in checks),'checks':checks,'recordings':len(records),'ticks':count,
            'inputs':inputs_checked,'style_events':style_checked}, records


def ordered_tape_audit(rec, plan, warmup):
    codes = {'w':87,'a':65,'s':83,'d':68,'space':32,'ctrl':4194326,'shift':4194325,'e':69}
    expected, observed = {}, {}
    f32 = lambda x: struct.unpack('<f',struct.pack('<f',x))[0]
    for e in plan['events']:
        if e['tick']+warmup >= len(rec.columns['tick']):
            continue
        event = ('key',codes[e['key']],e['edge']=='press') if 'key' in e else ('mouse',*[f32(v) for v in e['mouse']])
        expected.setdefault(e['tick'],[]).append(event)
    # the retained executor's contract is keys first in original order, then mouse, without reordering observed rows.
    expected = {tick:[e for e in events if e[0]=='key']+[e for e in events if e[0]=='mouse'] for tick,events in expected.items()}
    ins = rec.inputs
    for j,tick in enumerate(ins['tick']):
        if ins['kind'][j] == 1:
            observed.setdefault(tick-warmup,[]).append(('key',ins['aux'][j] or ins['code'][j],bool(ins['flags'][j]&1)))
        elif ins['kind'][j] == 3:
            observed.setdefault(tick-warmup,[]).append(('mouse',ins['x'][j],ins['y'][j]))
    found = difference({str(k):v for k,v in expected.items()},{str(k):v for k,v in observed.items()})
    return {'ok':found is None,'first_difference':found,'raw_rows':sum(map(len,observed.values()))}
