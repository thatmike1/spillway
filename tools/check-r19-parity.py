#!/usr/bin/env python3
"""freeze delivered R18 and verify later R19 without writing the checkout or player profile.

Baseline: --out /tmp/r19-parity-baseline. Candidate: --candidate COMMIT
--baseline-dir /tmp/r19-parity-baseline --out /tmp/r19-parity-final.
No candidate is inferred from the working tree. See tests/r19_parity_README.md.
"""
import argparse
import ast
import gzip
import ctypes
import threading
import copy
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
BASE = '640d06e6539b53da752f03bfddb64fb46310abb7'
PREFIX = 'projects/foldrunner/'
CAP = 600 * 2**20
MIN_FREE = 15_000_000_000


def module(path, name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


OLD = module(PROJECT/'tools/check-r17-parity.py', 'r19_inherited_checker')
sha, write, difference, stream = OLD.sha, OLD.write, OLD.difference, OLD.stream
GODOT = OLD.GODOT
NEW_KINDS = {'backward_bhop', 'sideways_bhop'}


def gate():
    return OLD.gate()


def bounded(command, env, cwd, log, ram, timeout=180):
    """cap owned RAM evidence/source/import/profile scratch; report engine memory separately."""
    gate()
    with log.open('w') as output:
        process = subprocess.Popen(command, env=env, cwd=cwd, stdout=output, stderr=subprocess.STDOUT)
        start = time.monotonic()
        peak = rss_peak = anon_peak = combined_peak = 0
        minimum_free = gate()
        try:
            while process.poll() is None:
                size = allocated_footprint(ram)
                rss = anonymous = 0
                try:
                    for line in Path(f'/proc/{process.pid}/status').read_text().splitlines():
                        if line.startswith('VmRSS:'):
                            rss = int(line.split()[1]) * 1024
                        elif line.startswith('RssAnon:'):
                            anonymous = int(line.split()[1]) * 1024
                except FileNotFoundError:
                    pass
                peak = max(peak, size)
                rss_peak = max(rss_peak, rss)
                anon_peak = max(anon_peak, anonymous)
                combined_peak = max(combined_peak, size + anonymous)
                minimum_free = min(minimum_free, gate())
                if size > CAP or time.monotonic() - start > timeout:
                    raise RuntimeError(f'600 MiB owned RAM scratch or time bound exceeded: scratch={size}, anonymous={anonymous}, rss={rss}')
                time.sleep(.25)
            code = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    return {'command': command, 'exit': code, 'seconds': round(time.monotonic()-start, 3),
            'owned_scratch_peak_bytes': peak, 'engine_rss_peak_bytes': rss_peak, 'engine_anonymous_peak_bytes':anon_peak, 'combined_owned_peak_bytes':combined_peak, 'minimum_home_free_bytes': minimum_free}


def freeze(commit, source, out):
    gate()
    commit = subprocess.check_output(['git', 'rev-parse', commit+'^{commit}'], cwd=REPO, text=True).strip()
    archive = out/'project.tar'
    with archive.open('wb') as target:
        subprocess.run(['git', 'archive', '--format=tar', commit, PREFIX], cwd=REPO, stdout=target, check=True)
    archive_info = {'sha256': sha(archive), 'bytes': archive.stat().st_size, 'commit': commit, 'prefix': PREFIX}
    if archive_info['bytes'] > 180 * 2**20:
        raise RuntimeError('unexpectedly large project archive')
    original = {}
    with tarfile.open(archive) as packed:
        for entry in packed:
            if not entry.isfile():
                if not entry.isdir():
                    raise RuntimeError('archive contains unsupported link: '+entry.name)
                continue
            assert entry.name.startswith(PREFIX) and '..' not in Path(entry.name).parts
            relative = entry.name[len(PREFIX):]
            target = source/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with packed.extractfile(entry) as incoming, target.open('wb') as outgoing:
                shutil.copyfileobj(incoming, outgoing)
            original[relative] = sha(target)
    archive.unlink()
    if commit == BASE:
        pin = json.loads((OUTER/'look/evidence/r19-baseline/SOURCE.json').read_text())
        assert pin['base_commit'] == BASE
        assert len(pin['files']) == pin['scoped_source_files'] == 346
        assert all(original[k.removeprefix(PREFIX)] == v['sha256'] for k,v in pin['files'].items()), 'R18 pin/archive mismatch'
        archive_info['parent_pin_sha256'] = sha(OUTER/'look/evidence/r19-baseline/SOURCE.json')
        archive_info['parent_pinned_files_verified'] = len(pin['files'])
    # the only injected Godot source is the observational adapter. inherited executor remains from git.
    shutil.copy2(PROJECT/'tests/r19_parity.gd', source/'tests/r19_parity.gd')
    executed = {str(p.relative_to(source)): sha(p) for p in sorted(source.rglob('*')) if p.is_file()}
    assert all(executed[k] == v for k,v in original.items() if k != 'tests/r19_parity.gd')
    manifest = {'commit': commit, 'archive': archive_info, 'archive_files': original, 'executed_files': executed,
                'injected': {'tests/r19_parity.gd': executed['tests/r19_parity.gd']}}
    write(out/('source-'+('r18' if commit == BASE else 'candidate')+'.json'), manifest)
    return manifest


def physical(row):
    """only the top-level style snapshot belongs in the separate scoring comparison."""
    return {key:value for key,value in row.items() if key != 'style'}


def compare_traces(a, b, scoring=False):
    bad, count, score_changes = [], 0, 0
    for x,y in itertools.zip_longest(stream(a), stream(b)):
        count += 1
        if x is None or y is None:
            bad.append({'row':count-1, 'missing':'a' if x is None else 'b'})
            break
        found = difference(physical(x), physical(y)) if scoring else difference(x,y)
        if found and len(bad) < 4:
            bad.append({'row':count-1, **found})
        score_changes += int(difference(x.get('style'), y.get('style')) is not None)
    return {'ok':not bad, 'rows':count, 'first_differences':bad, 'separate_style_snapshot_changes':score_changes}


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


def geometry_guard(a, b, revision):
    """geometry can change travel/contact/progress, never input/view/laws or an unknown field."""
    dynamic = {'p','v','reference_p','actual_v','grounded','ducked','motion','stats','elapsed','checkpoint','finished',
               'finish_kind','started','clean','practice_reason','course_key','identity','style','live_hull','view'}
    bad = []
    for i,(x,y) in enumerate(itertools.zip_longest(stream(a),stream(b))):
        if x is None or y is None:
            return {'ok':False,'difference':'route length changed'}
        found = difference({k:v for k,v in x.items() if k not in dynamic},{k:v for k,v in y.items() if k not in dynamic})
        if not found:
            found = difference({k:v for k,v in x['view'].items() if k != 'p'},{k:v for k,v in y['view'].items() if k != 'p'})
        if not found:
            found = difference(x['identity'],revision['baseline_identity']) or difference(y['identity'],revision['candidate_identity'])
        if found and len(bad)<4:
            bad.append({'row':i,**found})
    return {'ok':not bad,'first_differences':bad}


def geometry_record_guard(old, new):
    """preserve all format, law and view metadata when a map is deliberately revised."""
    a,_,_ = record_compare_view(old)
    b,_,_ = record_compare_view(new)
    a,b = a['header'],b['header']
    for header in [a,b]:
        meta = header['metadata']
        # retain timing, preset, runner, rate, physics/hull/mechanics entries of the ordered time identity.
        identity = meta.pop('record_identity')
        meta['preserved_record_identity'] = [identity[0],*identity[4:]]
        for key in ['identity','course_key']:
            meta.pop(key)
        meta['opportunities'].pop('base_geometry')
        for key in ['course_key','geometry']:
            header['identity'].pop(key)
    return {'ok':difference(a,b) is None,'first_difference':difference(a,b)}


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


def allocated_footprint(path):
    # sparse consumed trace blocks do not occupy tmpfs RAM; include ordinary files at allocated size.
    return sum(p.stat().st_blocks*512 for p in path.rglob('*') if p.is_file())


def start_trace_streams(dest):
    """compress regular-file output continuously and reclaim only already-compressed tmpfs blocks."""
    directory = dest/'evaluator'
    directory.mkdir()
    stopped = threading.Event()
    errors,threads,paths,receipts = [],[],[],{}
    libc = ctypes.CDLL(None,use_errno=True)
    punch = libc.fallocate
    punch.argtypes = [ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_longlong]
    punch.restype = ctypes.c_int
    def drain(path):
        fd = os.open(path,os.O_RDWR)
        digest = hashlib.sha256()
        length = reclaimed = 0
        try:
            with gzip.open(Path(str(path)+'.gz'),'wb',compresslevel=6) as target:
                while True:
                    data = os.read(fd,65536)
                    if data:
                        target.write(data)
                        digest.update(data)
                        length += len(data)
                        boundary = length // (1024*1024) * (1024*1024)
                        if boundary > reclaimed:
                            target.flush()
                            if punch(fd,3,reclaimed,boundary-reclaimed) != 0:
                                raise OSError(ctypes.get_errno(),'cannot reclaim compressed trace blocks')
                            reclaimed = boundary
                    elif stopped.is_set():
                        break
                    else:
                        stopped.wait(.02)
            # verify the lossless output independently before removing the sparse transport file.
            observed = hashlib.sha256()
            decoded = 0
            with gzip.open(Path(str(path)+'.gz'),'rb') as verify:
                for block in iter(lambda:verify.read(65536),b''):
                    observed.update(block)
                    decoded += len(block)
            assert observed.hexdigest() == digest.hexdigest() and decoded == length
            receipts[path.name] = {'raw_sha256':digest.hexdigest(),'raw_bytes':length,'reclaimed_bytes':reclaimed,
                                   'gzip_sha256':sha(Path(str(path)+'.gz')),'lossless_verified':True}
        except BaseException as exc:
            errors.append(repr(exc))
        finally:
            os.close(fd)
    for name in ['trace','ghost','observations']:
        path = directory/(name+'.jsonl')
        path.touch()
        paths.append(path)
        thread = threading.Thread(target=drain,args=(path,),daemon=False)
        thread.start()
        threads.append(thread)
    return stopped,threads,paths,errors,receipts


def validate_resume_contract(prior, out):
    """reuse is allowed only for identical engine sources and unchanged acceptance functions."""
    assert prior['mode'] == 'baseline-only' and prior['baseline_commit'] == BASE
    old_path = out/'preflight/check-r19-parity-before-streaming.py'
    assert sha(old_path) == prior['verification_source_sha256']['tools/check-r19-parity.py']
    for name,digest in prior['verification_source_sha256'].items():
        if name != 'tools/check-r19-parity.py':
            assert sha(PROJECT/name) == digest, 'resume changed an executed adapter/audit/inherited helper'
    def functions(text):
        return {n.name:ast.dump(n,include_attributes=False) for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)}
    old,new = functions(old_path.read_text()),functions(Path(__file__).read_text())
    changed = [name for name,body in old.items() if name not in ['main','run_route','bounded'] and new.get(name) != body]
    assert not changed, 'resume changed acceptance: '+str(changed)
    assert set(new)-set(old) <= {'allocated_footprint','start_trace_streams','validate_resume_contract','resume_route'}, 'unexpected new resume helper'
    return {'ok':True,'old_wrapper_sha256':sha(old_path),'new_wrapper_sha256':sha(Path(__file__)),
            'unchanged_acceptance_functions':sorted(set(old)-{'main','run_route','bounded'}),
            'scope':'resource output plumbing and explicit resume only; identical Godot adapter and archived project required'}


def resume_route(folder, route, plan, tape, analyzer, prior):
    result = json.loads((folder/'result.json').read_text())
    assert result.get('ok') and result['route'] == route and result['expected_ticks'] == plan['duration_ticks']
    assert result['expanded_sha256'] == sha(tape) and result['tape_sha256'] == sha(Path(route['tape']))
    assert set(result['runs']) == {'r18','r18-ghost'}
    records = {}
    for variant,run in result['runs'].items():
        assert run['ok'] and run['exit'] == 0 and not run['engine_errors'] and all(c['ok'] for c in run['summary']['checks'])
        assert run['summary']['finish']['last_tick']+1 == plan['duration_ticks']
        record = Path(run['summary']['finish']['record_path'])
        assert sha(record) == run['recording']['sha256']
        rec,_ = OLD.recording(record,analyzer)
        assert OLD.recording_alignment(rec,folder/variant/'evaluator/trace.jsonl.gz',route['warmup'])['ok']
        assert ordered_tape_audit(rec,plan,route['warmup'])['ok']
        audit,records[variant] = observation_audit(folder/variant,analyzer)
        assert audit['ok']
        run['executed_verification_source_sha256'] = prior['verification_source_sha256']
        run['resumed_without_reexecution'] = True
    assert compare_traces(folder/'r18/evaluator/trace.jsonl.gz',folder/'r18-ghost/evaluator/trace.jsonl.gz')['ok']
    assert difference(records['r18'],records['r18-ghost']) is None
    assert difference(result['runs']['r18']['summary']['finish']['ghost_probes'],result['runs']['r18-ghost']['summary']['finish']['ghost_probes']) is None
    assert difference(result['runs']['r18']['summary']['tour'],result['runs']['r18-ghost']['summary']['tour']) is None
    assert OLD.compare_reference(folder/'r18/evaluator/trace.jsonl.gz',Path(route['reference']))['ok']
    write(folder/'result.json',result)
    return result


def run_route(route, variant, source, dest, env, out, golden, tape, scene=None, host_script=None, incompatible=False):
    dest.mkdir()
    if golden:
        (dest/'runs').mkdir()
        shutil.copy2(golden,dest/'runs/golden.r16run')
        assert sha(golden) == sha(dest/'runs/golden.r16run')
    command = [str(GODOT),'--headless','--audio-driver','Dummy','--path',str(source),'--fixed-fps','128',
               '--script','res://tests/r19_parity.gd','--',f'--out={dest}',f'--tape={tape}',
               '--physics-hz=128',f'--warmup={route["warmup"]}',f'--map={route["map"]}',
               f'--preset={route["preset"]}',f'--sensitivity={route.get("sensitivity",2.5)}',
               f'--variant={variant}','--frames=none','--wall-budget-s=150']
    if scene:
        command.append('--host-scene='+scene)
    if host_script:
        command.append('--host-script='+host_script)
    if variant == 'old':
        command.append('--look=old')
    if golden:
        command.append(f'--{"incompatible-ghost" if incompatible else "ghost"}={golden}')
    stopped,threads,pipes,stream_errors,receipts = start_trace_streams(dest)
    try:
        run = bounded(command,env,source,dest/'engine.log',out)
    finally:
        stopped.set()
        for thread in threads:
            thread.join(10)
        for pipe in pipes:
            pipe.unlink()
    assert not stream_errors and all(not t.is_alive() for t in threads), ('trace compression failed',stream_errors)
    run['trace_compression'] = {'method':'regular files streamed to gzip; consumed tmpfs blocks reclaimed after compression', 'receipts':receipts}
    summary_path = dest/'summary.json'
    run['summary'] = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    run['engine_errors'] = [line for line in (dest/'engine.log').read_text().splitlines() if 'ERROR' in line][:12]
    run['ok'] = run['exit'] == 0 and not run['engine_errors'] and bool(run['summary']) and all(c['ok'] for c in run['summary'].get('checks',[]))
    return run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--routes')
    parser.add_argument('--resume',action='store_true',help='resume this exact R18 matrix after a streaming-only resource fix; acceptance/adapter/source hashes must match')
    parser.add_argument('--candidate',help='explicit frozen Git commit; omitted means baseline-only')
    parser.add_argument('--baseline-dir',type=Path)
    parser.add_argument('--host-scene',help='candidate PackedScene; default read from its project.godot')
    parser.add_argument('--host-script',help='optional assertion of candidate scene root script')
    parser.add_argument('--scoring-contract',type=Path,help='required for candidate: baseline/candidate style source hashes and fixture evidence')
    parser.add_argument('--map-revisions',type=Path,help='explicit changed-map identities/routes and targeted evidence; see README')
    args = parser.parse_args()
    gate()
    out = args.out.resolve()
    assert out.is_relative_to(Path('/tmp')) or out.is_relative_to(Path('/dev/shm')), 'all evidence must be in RAM /tmp or /dev/shm'
    prior_report = json.loads((out/'REPORT.json').read_text()) if args.resume else None
    prior_source = json.loads((out/'source-r18.json').read_text()) if args.resume else None
    if args.resume:
        assert not args.candidate, 'resume is baseline-only'
        resume_contract = validate_resume_contract(prior_report,out)
    out.mkdir(parents=True,exist_ok=args.resume)
    report = {'ok':False,'baseline_commit':BASE,'mode':'candidate' if args.candidate else 'baseline-only',
              'scope':'headless source-only actual R18/R19 configured hosts; final R19, packaging, visuals and native Windows are separate gates',
              'r19_final_gate':'pending' if not args.candidate else 'running','routes':[],
              'minimum_home_free_bytes':gate(),'cap_bytes':CAP,'godot':str(GODOT),'godot_sha256':sha(GODOT),
              'verification_source_sha256':{str(p.relative_to(PROJECT)):sha(p) for p in [Path(__file__),PROJECT/'tests/r19_parity.gd',
                  PROJECT/'tests/r19_parity_audit.py',PROJECT/'tests/r17_parity.gd',PROJECT/'tools/check-r17-parity.py']}}
    manifest_path = OUTER/'delivery/spillway-r16/VERIFICATION.json'
    manifest = json.loads(manifest_path.read_text())
    report['retained_delivery_manifest_sha256'] = sha(manifest_path)
    routes = manifest['routes']
    if args.routes:
        names = set(args.routes.split(','))
        routes = [r for r in routes if r['name'] in names]
        assert len(routes) == len(names), 'unknown route name'
    report['requested_routes'] = [r['name'] for r in routes]
    if args.resume:
        report['resume'] = resume_contract
        report['resume']['prior_report_sha256'] = sha(out/'preflight/REPORT-before-streaming.json')
    baseline = args.baseline_dir.resolve() if args.baseline_dir else None
    sources = {}
    try:
        if args.candidate:
            assert baseline and args.scoring_contract, 'candidate needs exact baseline evidence and explicit scoring contract'
            base_report = json.loads((baseline/'REPORT.json').read_text())
            assert base_report['ok'] and base_report['baseline_commit'] == BASE
            assert base_report['verification_source_sha256'] == report['verification_source_sha256'], 'executed helper hashes changed; recapture baseline'
        label = 'candidate' if args.candidate else 'r18'
        source = out/('snapshot-'+label)
        source_manifest = freeze(args.candidate or BASE, source, out)
        sources[label] = source
        if args.resume:
            assert prior_source['executed_files'] == source_manifest['executed_files'], 'resume archive/adapter source mismatch'
            assert prior_source['archive']['sha256'] == source_manifest['archive']['sha256'], 'resume archive byte mismatch'
        runtime_files = {k:sha(source/k) for k in source_manifest['executed_files']}
        expander = module(source/'tools/momentum-tape.py','r19_frozen_tape')
        analyzer = module(source/'tools/analyze-r16-runs.py','r19_frozen_reader')
        report['executed_python_sha256'] = {name:sha(source/name) for name in ['tools/momentum-tape.py','tools/analyze-r16-runs.py']}
        if args.candidate:
            pinned = json.loads((OUTER/'look/evidence/r19-baseline/SOURCE.json').read_text())
            assert all(source_manifest['archive_files'][k.removeprefix(PREFIX)] == pinned['files'][k]['sha256'] for k in pinned['protected_F2_motor_sources']), 'protected F2 law changed'
            score_contract = json.loads(args.scoring_contract.read_text())
            prior_source = json.loads((baseline/'source-r18.json').read_text())
            style_path = 'scripts/r16_style.gd'
            assert score_contract['baseline_style_sha256'] == prior_source['executed_files'][style_path]
            assert score_contract['candidate_style_sha256'] == source_manifest['executed_files'][style_path]
            fixture = Path(score_contract['fixture_evidence']['path'])
            assert sha(fixture) == score_contract['fixture_evidence']['sha256'] and json.loads(fixture.read_text())['ok'], 'style fixture evidence is not verified'
            report['scoring_contract'] = score_contract
        revisions = json.loads(args.map_revisions.read_text()) if args.map_revisions else {}
        assert set(revisions) <= {r['map'] for r in routes}, 'unknown geometry map allowlist entry'
        profile = out/'profile'
        profile.mkdir()
        env = OLD.environment(profile)
        env['MALLOC_ARENA_MAX'] = '1'
        cache = out/'import'
        cache.mkdir()
        (source/'.godot').symlink_to(cache)
        report['import'] = bounded([str(GODOT),'--headless','--editor','--path',str(source),'--import'],env,source,out/'import.log',out)
        assert report['import']['exit'] == 0, 'import failed'
        for route in routes:
            gate()
            folder = out/route['name']
            folder.mkdir(exist_ok=args.resume)
            tape = folder/'expanded.json'
            retained = Path(route['tape'])
            plan = expander.expand(json.loads(retained.read_text()))
            if args.resume and (folder/'result.json').exists():
                assert json.loads(tape.read_text()) == plan
                result = resume_route(folder,route,plan,tape,analyzer,prior_report)
                report['routes'].append({'name':route['name'],'map':route['map'],'preset':route['preset'],'ok':True,
                    'ticks':result['expected_ticks'],'recordings':sum(r['observation_audit']['recordings'] for r in result['runs'].values()),
                    'resumed_without_reexecution':True})
                write(out/'REPORT.json',report)
                print(json.dumps(report['routes'][-1]),flush=True)
                continue
            write(tape,plan)
            result = {'route':route,'tape_sha256':sha(retained),'expanded_sha256':sha(tape),'expected_ticks':plan['duration_ticks'],'runs':{},'comparisons':{}}
            prior = json.loads((baseline/route['name']/'result.json').read_text()) if args.candidate else None
            if prior:
                assert prior['route'] == route and prior['expanded_sha256'] == sha(tape) and prior['tape_sha256'] == sha(retained)
            golden = Path(prior['runs']['r18']['summary']['finish']['record_path']) if prior else None
            variants = ['old','new','toggle'] if args.candidate else ['r18','r18-ghost']
            baseline_records = None
            for variant in variants:
                incompatible = bool(variant == 'old' and route['map'] in revisions)
                run = run_route(route,variant,source,folder/variant,env,out,golden,tape,args.host_scene,args.host_script,incompatible)
                run['executed_verification_source_sha256'] = report['verification_source_sha256']
                result['runs'][variant] = run
                write(folder/'result.json',result)
                assert run['ok'], f'run failed: {route["name"]}/{variant}'
                assert run['summary']['finish']['last_tick']+1 == plan['duration_ticks'], 'short tape'
                if not args.candidate:
                    assert run['summary']['host_scene'] == 'res://scenes/r17.tscn' and run['summary']['host_script'] == 'res://scripts/r17_main.gd', 'not delivered R18 host'
                path = Path(run['summary']['finish']['record_path'])
                rec, semantic = OLD.recording(path,analyzer)
                run['recording_alignment'] = OLD.recording_alignment(rec,folder/variant/'evaluator/trace.jsonl.gz',route['warmup'])
                run['ordered_tape'] = ordered_tape_audit(rec,plan,route['warmup'])
                run['observation_audit'], records = observation_audit(folder/variant,analyzer)
                run['recording'] = {'path':str(path),'sha256':sha(path),'ticks':len(rec.columns['tick']),'inputs':len(rec.inputs['tick']),'events':len(rec.events)}
                write(folder/'result.json',result)
                assert run['recording_alignment']['ok'] and run['ordered_tape']['ok'] and run['observation_audit']['ok'], 'recording evidence failed'
                if not prior and variant == 'r18':
                    golden = path
                    baseline_records = records
                else:
                    reference_dir = baseline/route['name'] if prior else folder
                    prior_run = prior['runs']['r18-ghost'] if prior else result['runs']['r18']
                    reference_variant = 'r18-ghost' if prior else 'r18'
                    comparisons = {'motion':compare_traces(reference_dir/reference_variant/'evaluator/trace.jsonl.gz',folder/variant/'evaluator/trace.jsonl.gz',bool(prior)),
                                   'ghost_probes':{'ok':difference(prior_run['summary']['finish']['ghost_probes'],run['summary']['finish']['ghost_probes']) is None}}
                    if prior:
                        comparisons['live_ghost'] = OLD.compare_traces(reference_dir/'r18-ghost/evaluator/ghost.jsonl.gz',folder/variant/'evaluator/ghost.jsonl.gz')
                        _, baseline_records = observation_audit(reference_dir/'r18',analyzer)
                        scoring = []
                        physical_records = []
                        baseline_physical = []
                        assert len(records) == len(baseline_records), 'lifecycle recording count changed'
                        for old_record,new_record in zip(baseline_records,records):
                            a,sa,la = record_compare_view(old_record)
                            b,sb,lb = record_compare_view(new_record)
                            detector = detector_comparison(sa,sb)
                            scoring.append({'ok':detector['ok'],'detectors':detector,'metadata_difference':difference(sa['header'],sb['header']),
                                            'outcome_difference':difference(sa['outcome'],sb['outcome']),'labels_difference':difference(la,lb),'storage_difference':difference(sa['storage'],sb['storage'])})
                            physical_records.append(b)
                            baseline_physical.append(a)
                        comparisons['recordings'] = {'ok':difference(baseline_physical,physical_records) is None,'first_difference':difference(baseline_physical,physical_records)}
                        result.setdefault('separate_scoring',{})[variant] = scoring
                        comparisons['scoring'] = {'ok':all(s['ok'] for s in scoring)}
                        comparisons['controls'] = {'ok':difference([{**r,'game':physical(r['game'])} for r in prior_run['summary']['tour']],
                                                                  [{**r,'game':physical(r['game'])} for r in run['summary']['tour']]) is None}
                    else:
                        found = difference(baseline_records,records)
                        comparisons['recordings'] = {'ok':found is None,'first_difference':found}
                        comparisons['controls'] = {'ok':difference(prior_run['summary']['tour'],run['summary']['tour']) is None}
                    if route['map'] in revisions:
                        # an explicit allowlist is never an automatic pass: require exact before/after identity, route and targeted proof.
                        revision = revisions[route['map']]
                        assert route['name'] in revision['routes'], 'changed route not listed'
                        assert revision['baseline_identity'] == prior_run['summary']['finish']['identity']
                        assert revision['candidate_identity'] == run['summary']['finish']['identity']
                        proof = Path(revision['evidence']['path'])
                        assert sha(proof) == revision['evidence']['sha256'] and json.loads(proof.read_text())['ok']
                        assert difference({k:v for k,v in revision['baseline_identity'].items() if k not in ['geometry','course_key']},
                                          {k:v for k,v in revision['candidate_identity'].items() if k not in ['geometry','course_key']}) is None, 'map revision changed a nongeometry compatibility identity'
                        # all raw differences remain; these guards still reject changed input/view/laws and unknown metadata.
                        result['geometry_revision'] = revision
                        comparisons['geometry_invariants'] = geometry_guard(reference_dir/'r18-ghost/evaluator/trace.jsonl.gz',
                                                                           folder/variant/'evaluator/trace.jsonl.gz',revision)
                        guards = [geometry_record_guard(a,b) for a,b in zip(baseline_records,records)]
                        comparisons['geometry_record_invariants'] = {'ok':all(g['ok'] for g in guards),'records':guards}
                        comparisons['geometry_exception'] = {'ok':True,'scope':'listed targeted map revision; exact parity not established'}
                        if route['name'] not in revision.get('off_line_routes',[]):
                            for key in ['motion','recordings','controls','ghost_probes','live_ghost','scoring']:
                                if key in comparisons:
                                    comparisons[key]['accepted_geometry_exception'] = True
                        golden = path
                    result['comparisons'][variant] = comparisons
                write(folder/'result.json',result)
            if not args.candidate:
                result['retained_reference'] = OLD.compare_reference(folder/'r18/evaluator/trace.jsonl.gz',Path(route['reference']))
                # an R16 reference is corroboration, not a substitute for the executed R18 baseline.
                assert result['retained_reference']['ok'], 'R18 no longer matches retained physical acceptance route'
            result['ok'] = all(r['ok'] for r in result['runs'].values()) and all(c['ok'] or c.get('accepted_geometry_exception',False)
                for comparisons in result['comparisons'].values() for c in comparisons.values())
            write(folder/'result.json',result)
            report['routes'].append({'name':route['name'],'map':route['map'],'preset':route['preset'],'ok':result['ok'],
                                     'ticks':result['expected_ticks'],'recordings':sum(r['observation_audit']['recordings'] for r in result['runs'].values())})
            write(out/'REPORT.json',report)
            print(json.dumps(report['routes'][-1]),flush=True)
            assert result['ok'], 'parity failed; evidence preserved'
        assert all(sha(source/k) == v for k,v in runtime_files.items()), 'executed source changed during matrix'
        report['source_postflight'] = {'ok':True,'files':len(runtime_files),'note':'Godot-generated import/UID metadata is outside archived executed source hashes'}
        report['ok'] = len(report['routes']) == len(routes) and all(r['ok'] for r in report['routes'])
        report['home_free_end'] = gate()
        report['r19_final_gate'] = 'pending' if not args.candidate else ('passed' if report['ok'] else 'failed')
    except BaseException as exc:
        report['error'] = repr(exc)
        write(out/'REPORT.json',report)
        raise
    finally:
        for source in sources.values():
            if source.exists():
                shutil.rmtree(source)
        for name in ['import','profile']:
            if (out/name).exists():
                shutil.rmtree(out/name)
        report['cleanup'] = {'source_import_profile_removed':all(not (out/name).exists() for name in ['snapshot-r18','snapshot-candidate','import','profile']),
                             'live_project_cache_untouched':True}
        write(out/'REPORT.json',report)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
