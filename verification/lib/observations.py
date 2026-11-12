import copy,json,struct
from pathlib import Path
import support as K
C=K.C
OLD,packed_columns,difference=C.OLD,C.packed_columns,C.difference
validate_record_identity,godot_json_reader=C.validate_record_identity,C.godot_json_reader
reader_difference,sha=C.reader_difference,C.sha
def stream(path):
 from parity_core import stream as read
 return read(path)
def reader_inventory(run_dir, readers):
    K.need(type(readers) is list and bool(readers),'missing lifecycle reader inventory')
    files=[];ids=[]
    for row in readers:
        K.keys(row, {'file','sha256','columns_sha256','inputs_sha256','identity_text','header','events','seal'}, 'reader dump')
        K.need(type(row['file']) is str and Path(row['file']).name==row['file'] and row['file'].endswith('.r16run'),
            'unsafe/incomplete lifecycle recording')
        files.append(row['file']);ids.append(row['header']['run_id'])
    K.need(len(set(files))==len(files) and len(set(ids))==len(ids),'duplicate lifecycle reader/file identity')
    K.exact(sorted(p.name for p in (run_dir/'runs').iterdir()),sorted(files+['golden.r16run']),
        'unknown/missing recording outside both-reader inventory')
    return True


def observation_audit(run_dir, analyzer):
    """retain the R19 sample/input/reader audit and use tagged R20 scoring accounting."""
    readers = K.load(run_dir/'readers.json')
    reader_inventory(run_dir,readers)
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
    observed_by_id = {k:[] for k in by_id}
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
            if e.get('s') == 'capture' and e['k'] == 'style':
                style_tables[run_id].setdefault(e['t'],[]).append(e['d'])
    for row in stream(observations):
        run_id, sample, actual = row['run_id'], row['sample'], row['actual']
        assert run_id in by_id, ('observation has no completed recording',run_id)
        rec,_ = by_id[run_id]
        K.keys(row, {'run_id','sample','actual','style_events','style_score','style_time_s','style_direction','style_direction_verdict','ordinary_reference','ordinary_snapshot'}, 'candidate observation')
        observed_by_id[run_id].append(row)
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
        if found:
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
    for run_id,(rec,_) in by_id.items():
        rows = observed_by_id[run_id]
        K.exact([r['sample']['tick'] for r in rows], list(range(len(rec.columns['tick']))), 'all actual samples ordered')
        K.exact(sorted(rec.columns), sorted(K.A.COLUMN_NAMES), 'unknown/missing binary sample column')
        K.exact(sorted(rec.inputs), sorted(n for n,_,_ in K.A.INPUT_LAYOUT), 'unknown/missing binary input column')
        K.keys(rec.header, K.HEADER_KEYS, 'header')
        K.keys(rec.header['metadata'], K.META_KEYS, 'metadata')
        for event in rec.events:
            K.keys(event, {'q','s','k','t','d'}, 'event envelope')
            K.need(type(event['t']) is int and -1 <= event['t'] < len(rows), 'bad event attribution')
            if event['k'] == 'style':
                K.strict_event(event['d'])
        K.P.audit_style_stream(rec, rows)
        K.style_snapshots(rows)
        for row in rows:
            ordinary = [e for e in row['style_events'] if e['v'] == 1]
            K.exact(ordinary, row['ordinary_reference'], 'independent exact unrounded ordinary R19 reference')
        checks.append({'ok':True,'name':'tagged scored/diagnostic/live/seal/by-kind and exact reference '+rec.path.name})
    records.sort(key=lambda r:(r['header']['metadata']['attempt'],r['header']['metadata']['map'],r['header']['metadata']['preset'],
                              r['header']['metadata']['start_reason'],r['seal']['outcome']['kind'],len(r['columns']['tick'])))
    return {'ok':all(c['ok'] for c in checks),'checks':checks,'recordings':len(records),'ticks':count,
            'inputs':inputs_checked,'style_events':style_checked}, records
