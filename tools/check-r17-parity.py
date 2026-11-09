#!/usr/bin/env python3
"""source-only exact R16/R17 replay, recordings and live ghost parity from retained input tapes.

python3 tools/check-r17-parity.py --out /absolute/new/evidence-directory
--routes NAME[,NAME] restricts work; default is every retained R16 delivery route.
Snapshots come from git archive, with only this new adapter copied in. Imports and profiles
live in bounded RAM. No original checkout, user profile or retained evidence is modified.
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
GODOT = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
MIN_FREE = 15_000_000_000
RAM_CAP = 500 * 2**20


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def write(path, value):
    path.write_text(json.dumps(value, indent=1) + '\n')


def gate():
    free = shutil.disk_usage('/home').free
    if free < MIN_FREE:
        raise RuntimeError(f'free-space gate: {free} < {MIN_FREE}')
    return free


def footprint(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())


def bounded(command, env, cwd, log, ram, timeout=120):
    with log.open('w') as stream:
        p = subprocess.Popen(command, env=env, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
        started = time.monotonic()
        peak = 0
        rss_peak = 0
        try:
            while p.poll() is None:
                peak = max(peak, footprint(ram))
                try:
                    for line in Path(f"/proc/{p.pid}/status").read_text().splitlines():
                        if line.startswith("VmRSS:"):
                            rss_peak = max(rss_peak, int(line.split()[1])*1024)
                except FileNotFoundError:
                    pass
                if peak > RAM_CAP or time.monotonic() - started > timeout:
                    raise RuntimeError(f'bounded process exceeded RAM/duration: {peak} bytes; command {command}')
                gate()
                time.sleep(.2)
            code = p.wait()
        finally:
            if p.poll() is None:
                p.terminate()
                try:
                    p.wait(5)
                except subprocess.TimeoutExpired:
                    p.kill()
                    p.wait()
    return {'command': command, 'exit': code, 'seconds': round(time.monotonic()-started, 3), 'ram_scratch_peak_bytes': peak, 'engine_rss_peak_bytes': rss_peak}


def freeze(commit, dest):
    prefix = 'projects/foldrunner/'
    p = subprocess.Popen(['git', 'archive', commit, prefix], cwd=REPO, stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=p.stdout, mode='r|') as archive:
            for item in archive:
                if item.isfile() and item.name.startswith(prefix):
                    target = dest / item.name[len(prefix):]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.extractfile(item) as source, target.open('wb') as output:
                        shutil.copyfileobj(source, output)
        assert p.wait() == 0
    finally:
        p.stdout.close()
        if p.poll() is None:
            p.terminate()
            p.wait()
    shutil.copy2(PROJECT/'tests/r17_parity.gd', dest/'tests/r17_parity.gd')
    return {str(f.relative_to(dest)): sha(f) for f in sorted(dest.rglob('*')) if f.is_file()}


def environment(ram):
    env = {'PATH': os.environ['PATH'], 'LANG': 'C.UTF-8'}
    for key in ['HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR']:
        target = ram/key.lower()
        target.mkdir(mode=0o700, exist_ok=True)
        env[key] = str(target)
    return env


def stream(path):
    with gzip.open(path, 'rt') as f:
        for line in f:
            yield json.loads(line)


def compress(path):
    target = Path(str(path)+'.gz')
    with path.open('rb') as a, gzip.open(target, 'wb', compresslevel=6) as b:
        shutil.copyfileobj(a, b)
    path.unlink()
    return target


def canonical(value):
    # preserve every gameplay field; recording labels are normalized separately.
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in value.items()}
    if isinstance(value, list):
        return [canonical(v) for v in value]
    return value


def difference(a, b, path='$'):
    if type(a) is not type(b):
        return {'path': path, 'a': a, 'b': b}
    if isinstance(a, dict):
        if a.keys() != b.keys():
            return {'path': path, 'keys_a': list(a), 'keys_b': list(b)}
        for key in a:
            found = difference(a[key], b[key], path+'.'+key)
            if found:
                return found
    elif isinstance(a, list):
        if len(a) != len(b):
            return {'path': path, 'length_a': len(a), 'length_b': len(b)}
        for i, (x,y) in enumerate(zip(a,b)):
            found = difference(x,y,path+f'[{i}]')
            if found:
                return found
    elif a != b:
        return {'path': path, 'a': a, 'b': b}
    return None


def compare_traces(a, b):
    import itertools
    count = 0
    bad = []
    for x,y in itertools.zip_longest(stream(a),stream(b)):
        count += 1
        found = difference(canonical(x),canonical(y))
        if found and len(bad)<4:
            bad.append({'row':count-1, **found})
    return {'ok': not bad, 'rows': count, 'first_differences':bad}


def recording(path, analyzer):
    rec = analyzer.read(path)
    assert rec.ok, (str(path),rec.errors)
    header = dict(rec.header)
    # docs/r16/RECORDINGS.md: wall clock/run id are labels, never gameplay.
    for key in ['run_id','created_utc','created_unix']:
        header.pop(key, None)
    seal = {k:v for k,v in rec.seal.items() if k != 'ended_unix'}
    seal['counts'] = dict(seal['counts'])
    data = path.read_bytes()
    header_bytes = struct.unpack_from('<I',data,12)[0]
    at = 16+header_bytes+32
    while data[at+4] != 2:
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    assert rec.seal['counts']['bytes']==at, 'pre-seal byte bookkeeping must match actual validated stream offset'
    # docs/r16/RECORDINGS.md: counts.bytes includes the variable-sized label/time header.
    # remove its physical size contribution only; compare every compressed gameplay payload byte count.
    seal['counts']['bytes'] -= header_bytes
    return rec, {'header':header,'columns':rec.columns,'inputs':rec.inputs,'events':rec.events,'seal':seal}


def compare_reference(actual, reference):
    import itertools
    keys = ['tick','p','v','yaw','pitch','grounded','elapsed','checkpoint','finished','finish_kind','respawns']
    refs = (r for r in stream(reference) if r.get('phase') == 'tape')
    count = 0
    bad = []
    for a,b in itertools.zip_longest(stream(actual),refs):
        count += 1
        if a is None or b is None:
            bad.append({'tick':count-1,'missing':'actual' if a is None else 'reference'})
            break
        translated = {'tick':b['tick'], **{k:b['post'][k] for k in ['p','v','yaw','pitch','grounded']},
                      **{k:b['game'][k] for k in ['elapsed','checkpoint','finished','finish_kind','respawns']}}
        found = difference({k:a[k] for k in keys}, translated)
        if found and len(bad)<4:
            bad.append({'tick':count-1, **found})
    return {'ok':not bad,'ticks':count,'sha256':sha(reference),'path':str(reference),'differences':bad}


def recording_alignment(rec, trace, offset):
    import struct
    def f32(v):
        return struct.unpack('<f',struct.pack('<f',v))[0]
    c=rec.columns
    names=[]
    for event in rec.events:
        if event['k']=='held_names':
            names=event['d']['names']
            break
    actions={e['d']['index']:e['d']['name'] for e in rec.events if e['k']=='action_name'}
    actual_inputs={}
    ins=rec.inputs
    for j,tick in enumerate(ins['tick']):
        kind=ins['kind'][j]
        if kind==1:
            event={'type':'key','keycode':ins['code'][j],'physical_keycode':ins['aux'][j],
                   'pressed':bool(ins['flags'][j]&1),'echo':bool(ins['flags'][j]&2)}
        elif kind==3:
            event={'type':'mouse_motion','screen_relative':[ins['x'][j],ins['y'][j]],'relative':[ins['x2'][j],ins['y2'][j]]}
        elif kind==4:
            event={'type':'action','action':actions[ins['code'][j]],'pressed':bool(ins['flags'][j]&1)}
        else:
            raise AssertionError(('unexpected input kind in retained keyboard/mouse route',kind))
        actual_inputs.setdefault(tick,[]).append(event)
    bad=[]
    compared=0
    input_count=0
    for row in stream(trace):
        i=offset+row['tick']
        if i>=len(c['tick']):
            break
        fields={k:row[k] for k in ['dt','physics_hz','elapsed','checkpoint','respawns','yaw','pitch']}
        fields['flags']=sum(int(row[k])<<bit for bit,k in enumerate(['started','finished','clean','grounded','ducked']))
        fields['held']=sum(int(bool(row['held'].get(name,False)))<<bit for bit,name in enumerate(names))
        for group in ['p','reference_p','v','actual_v']:
            for axis,value in zip('xyz',row[group]):
                fields[group+'_'+axis]=f32(value)
        for key,want in fields.items():
            if c[key][i]!=want and len(bad)<4:
                bad.append({'tick':row['tick'],'column':key,'want':want,'actual':c[key][i]})
        want_inputs=row['input']
        for event in want_inputs:
            if event['type']=='mouse_motion':
                for key in ['relative','screen_relative']:
                    event[key]=[f32(v) for v in event[key]]
        got_inputs=actual_inputs.get(i,[])
        found=difference(want_inputs,got_inputs)
        if found and len(bad)<4:
            bad.append({'tick':row['tick'],'inputs':found})
        input_count+=len(got_inputs)
        compared+=1
    if input_count != len(ins['tick']):
        bad.append({'unmatched_inputs':len(ins['tick'])-input_count})
    style=[e for e in rec.events if e.get('s')=='capture']
    points=sum(int(e.get('d',{}).get('points',0)) for e in style)
    style_ok=points==rec.seal['outcome']['style']['score'] and not any(e['t']>rec.seal['finish_tick'] for e in style)
    return {'ok':not bad and compared==len(c['tick'])-offset and style_ok,
            'offset':offset,'compared':compared,'recorded_ticks':len(c['tick']),'first_differences':bad,'input_rows_checked':input_count,
            'independent_style_total':points,'style_seal_ok':style_ok}


def run_route(route, variant, source, dest, env, ram, golden, tape):
    dest.mkdir()
    if golden:
        (dest/'runs').mkdir()
        shutil.copy2(golden,dest/'runs/golden.r16run')
        assert sha(golden)==sha(dest/'runs/golden.r16run')
    command = [str(GODOT),'--headless','--audio-driver','Dummy','--path',str(source),'--fixed-fps','128',
               '--script','res://tests/r17_parity.gd','--',f'--out={dest}',f'--tape={tape}',
               '--physics-hz=128',f'--warmup={route["warmup"]}',f'--map={route["map"]}',
               f'--preset={route["preset"]}',f'--sensitivity={route.get("sensitivity",2.5)}',
               f'--variant={variant}','--frames=none','--wall-budget-s=100']
    if variant == 'old':
        command.append('--look=old')
    if golden:
        command.append(f'--ghost={golden}')
    run = bounded(command,env,source,dest/'engine.log',ram,120)
    for name in ['trace', 'ghost']:
        raw = dest/f'evaluator/{name}.jsonl'
        if raw.exists():
            compress(raw)
    summary_path = dest/'summary.json'
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    run['summary'] = summary
    run['engine_errors'] = [s for s in (dest/'engine.log').read_text().splitlines() if 'ERROR' in s or 'SCRIPT ERROR' in s][:12]
    run['ok'] = run['exit']==0 and not run['engine_errors'] and bool(summary) and all(c['ok'] for c in summary.get('checks',[]))
    return run


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--routes')
    p.add_argument('--reuse-from',type=Path,help='reuse completed plays only when both full source manifests including adapter match exactly')
    p.add_argument('--r16',default='7261ba593')
    p.add_argument('--r17',default='7c82e0877')
    args = p.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True,exist_ok=False)
    report = {'scope':'headless frozen external source snapshots, not packaged/native visual or enjoyment acceptance',
              'minimum_home_free_bytes':gate(),'godot':str(GODOT),'godot_sha256':sha(GODOT),'routes':[],
              'verification_source_sha256':{str(f.relative_to(PROJECT)):sha(f) for f in [Path(__file__),PROJECT/'tests/r17_parity.gd',PROJECT/'tools/analyze-r16-runs.py',PROJECT/'tools/momentum-tape.py',PROJECT/'tools/momentum-tape.gd']},
              'normalization':['header.run_id','header.created_utc','header.created_unix','seal.ended_unix','seal.counts.bytes minus validated physical header length'],
              'reproduction':f'python3 {Path(__file__).resolve()} --out /absolute/new/evidence-directory'}
    manifest = json.loads((OUTER/'delivery/spillway-r16/VERIFICATION.json').read_text())
    routes = manifest['routes']
    if args.routes:
        names = set(args.routes.split(','))
        routes = [r for r in routes if r['name'] in names]
        assert len(routes)==len(names), 'unknown route name'
    reuse = args.reuse_from.resolve() if args.reuse_from else None
    if reuse:
        report['reuse_from']=str(reuse)
    analyzer = module(PROJECT/'tools/analyze-r16-runs.py','r17_reader')
    expander = module(PROJECT/'tools/momentum-tape.py','r17_tape')
    try:
        with tempfile.TemporaryDirectory(prefix='r17-parity-',dir='/dev/shm') as tmp:
            ram = Path(tmp)
            env = environment(ram)
            sources = {}
            for label, commit in [('r16',args.r16),('r17',args.r17)]:
                source = out/f'snapshot-{label}'
                hashes = freeze(commit,source)
                write(out/f'source-{label}.json',{'commit':subprocess.check_output(['git','rev-parse',commit],cwd=REPO,text=True).strip(),'files':hashes})
                cache = ram/f'import-{label}'
                cache.mkdir()
                (source/'.godot').symlink_to(cache)
                imported = bounded([str(GODOT),'--headless','--editor','--path',str(source),'--import'],env,source,out/f'import-{label}.log',ram,120)
                report[label+'_import']=imported
                assert imported['exit']==0, imported
                sources[label]=source
                if reuse:
                    prior=json.loads((reuse/f'source-{label}.json').read_text())
                    assert prior['files']==hashes, 'reuse source/adapter hash mismatch'
            baseline_hashes=json.loads((out/'source-r16.json').read_text())['files']
            current_hashes=json.loads((out/'source-r17.json').read_text())['files']
            preserved={k:v for k,v in baseline_hashes.items() if k.split('/')[0] in ['assets','scripts','shaders','scenes']}
            changed=[k for k,v in preserved.items() if current_hashes.get(k)!=v]
            report['runtime_preservation']={'files':len(preserved),'changed':changed,'ok':not changed}
            assert not changed, changed
            report['native_movie_routes']=[]
            for route in routes:
                gate()
                folder=out/route['name']
                prior_result = None
                if reuse and (reuse/route['name']/'result.json').exists():
                    shutil.copytree(reuse/route['name'],folder)
                    prior_result=json.loads((folder/'result.json').read_text())
                    assert prior_result['route']==route, 'reuse route changed'
                else:
                    folder.mkdir()
                tape=folder/'expanded.json'
                plan=expander.expand(json.loads(Path(route['tape']).read_text()))
                write(tape,plan)
                report['native_movie_routes'].append({'map':route['map'],'route':route['name'],'tape':str(tape),'warmup':route['warmup'],
                    'preset':route['preset'],'sensitivity':route.get('sensitivity',2.5),'duration_ticks':plan['duration_ticks'],
                    'adapter':'res://tests/r17_parity.gd','short_movie_option':'--movie-ticks=768',
                    'example_command':[str(GODOT),'--path','ABSOLUTE_IMPORTED_SNAPSHOT','--audio-driver','Dummy','--fixed-fps','30',
                      '--write-movie','ABSOLUTE_OUTPUT/movie.avi','--script','res://tests/r17_parity.gd','--',
                      '--out=ABSOLUTE_OUTPUT',f'--tape={tape}','--physics-hz=128',f'--warmup={route["warmup"]}',
                      f'--map={route["map"]}',f'--preset={route["preset"]}',f'--sensitivity={route.get("sensitivity",2.5)}',
                      '--variant=new','--frames=none','--movie-ticks=768','--wall-budget-s=100']})
                write(out/'native-movie-routes.json',report['native_movie_routes'])
                result={'route':route,'tape_sha256':sha(Path(route['tape'])),'expanded_sha256':sha(tape),
                        'expected_ticks':plan['duration_ticks'],'runs':{},'comparisons':{}}
                golden=None
                baseline_rec=None
                for variant in ['r16','r16-ghost','old','new','toggle']:
                    prior_run=(prior_result or {}).get('runs',{}).get(variant)
                    if prior_run and prior_run['exit']==0 and not prior_run['engine_errors'] and all(c['ok'] for c in prior_run['summary']['checks']):
                        run=prior_run
                        run['reused_from']=str(reuse/route['name']/variant)
                        run['ok']=True
                    else:
                        if (folder/variant).exists():
                            shutil.rmtree(folder/variant)
                        run=run_route(route,'r16' if variant=='r16-ghost' else variant,sources['r16' if variant.startswith('r16') else 'r17'],folder/variant,env,ram,golden,tape)
                    result['runs'][variant]=run
                    if not run['ok']:
                        write(folder/'result.json',result)
                        raise RuntimeError(f'run failed: {route["name"]}/{variant}; inspect engine.log/summary.json')
                    run['complete_tape']=run['summary']['finish']['last_tick']+1==plan['duration_ticks']
                    run['ok']=run['ok'] and run['complete_tape']
                    record_path=Path(run['summary']['finish']['record_path'])
                    rec, semantics=recording(record_path,analyzer)
                    run['recording_alignment']=recording_alignment(rec,folder/variant/'evaluator/trace.jsonl.gz',route['warmup'])
                    run['ok'] = run['ok'] and run['recording_alignment']['ok']
                    run['recording']={'path':str(record_path),'sha256':sha(record_path),'ticks':len(rec.columns['tick']),
                                      'inputs':len(rec.inputs['tick']),'events':len(rec.events),'independent_reader':True}
                    if variant=='r16':
                        golden=record_path
                        baseline_rec=semantics
                    else:
                        traces=compare_traces(folder/'r16/evaluator/trace.jsonl.gz',folder/variant/'evaluator/trace.jsonl.gz')
                        rec_diff=difference(baseline_rec,semantics)
                        # ghost probes use exactly the same golden bytes and actual identity.
                        ghost_diff=difference(result['runs']['r16']['summary']['finish']['ghost_probes'],run['summary']['finish']['ghost_probes'])
                        result['comparisons'][variant]={'trace':traces,'recording':{'ok':rec_diff is None,'first_difference':rec_diff},
                                                        'ghost_probes':{'ok':ghost_diff is None,'first_difference':ghost_diff},
                                                        'controls':{'ok':difference(result['runs']['r16']['summary']['tour'],run['summary']['tour']) is None}}
                        if variant != 'r16-ghost':
                            result['comparisons'][variant]['live_ghost'] = compare_traces(folder/'r16-ghost/evaluator/ghost.jsonl.gz',folder/variant/'evaluator/ghost.jsonl.gz')
                result['reference']=compare_reference(folder/'r16/evaluator/trace.jsonl.gz',Path(route['reference']))
                result['ok']=all(run['ok'] for run in result['runs'].values()) and all(
                    all(v['ok'] for v in c.values()) for c in result['comparisons'].values()) and result['reference']['ok']
                write(folder/'result.json',result)
                report['routes'].append({'name':route['name'],'map':route['map'],'preset':route['preset'],'ok':result['ok'],
                    'ticks':result['expected_ticks'],'max_speed_m_s':result['runs']['r16']['summary']['finish']['max_speed_m_s'],
                    'comparisons':result['comparisons'],'reference':result['reference']})
                write(out/'REPORT.json',report)
                print(json.dumps(report['routes'][-1]),flush=True)
                if not result['ok']:
                    raise RuntimeError('exact parity failed; preserved evidence')
            report['ok']=all(r['ok'] for r in report['routes']) and len(report['routes'])==len(routes)
            report['home_free_end']=gate()
    except BaseException as exc:
        report['ok']=False
        report['error']=repr(exc)
        write(out/'REPORT.json',report)
        raise
    finally:
        # our source copies are reproducible from hashes; retain evidence, remove only own imports/copies.
        for label in ['r16','r17']:
            own=out/f'snapshot-{label}'
            if own.exists():
                shutil.rmtree(own)
    write(out/'REPORT.json',report)
    return 0 if report['ok'] else 1


if __name__=='__main__':
    raise SystemExit(main())
