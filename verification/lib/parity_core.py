import array,copy,gzip,hashlib,itertools,json,math,struct,types
from pathlib import Path
import support as K
import observations as O
import run_reader as A
B,C=K.B,K.C
need,keys,sha,load,canonical=K.need,K.keys,K.sha,K.load,K.canonical
Refused=K.Refused
META_KEYS,IDENTITY_KEYS=K.META_KEYS,K.IDENTITY_KEYS
lab_guard=K.lab_guard
PROJECT=Path(__file__).resolve().parents[2]
BASELINE=PROJECT/"tests/fixtures/original-map-parity"
FINAL=Path("/tmp/spillway-parity")
VARIANTS=("old","new","toggle")
SCENE="res://scenes/r21.tscn"
SCRIPT="res://scripts/r21_main.gd"
MISSING=object()
def unique_recording_object(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError('duplicate recording JSON key: '+name)
        result[name] = value
    return result


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
               '--script','res://tests/original_map_parity.gd','--',f'--out={dest}',f'--tape={tape}','--physics-hz=128',
               f'--warmup={route["warmup"]}',f'--map={route["map"]}',f'--preset={route["preset"]}',
               f'--sensitivity={route.get("sensitivity",2.5)}',f'--variant={variant}','--frames=none',
               '--wall-budget-s=150','--host-scene='+SCENE,'--host-script='+SCRIPT,f'--ghost={golden}']
    if variant == 'old':
        command.append('--look=old')
    return command


def engine_guard(engine, old, command, profile):
    value = copy.deepcopy(engine)
    # validate actual process-bound presentation/path metadata before mapping only those exact fields.
    exact(value['cmdline'], ['--script','res://tests/original_map_parity.gd'], 'actual executor cmdline')
    exact(value['executor_script'], 'res://tests/original_map_parity.gd', 'actual executor script')
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


A.json = types.SimpleNamespace(loads=lambda data, **kwargs: json.loads(data,object_pairs_hook=unique_recording_object,**kwargs))

def route_plan(route):
 path=PROJECT/route["tape"]; path=path.with_name("expanded.json")
 return load(path),path.read_bytes()
