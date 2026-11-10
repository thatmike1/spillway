#!/usr/bin/env python3
"""capture exact R19 and fail closed until reviewed R20 candidate contracts exist."""
import argparse
import ctypes
import gzip
import hashlib
import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import threading
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'
PREFIX = 'projects/foldrunner/'
CAP = 600 * 2**20
MIN_FREE = 15_000_000_000
SCRATCH = Path('/tmp/r20-parity-baseline')

def module(path, name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


C = module(PROJECT/'tools/check-r19-parity.py', 'r20_inherited_checker')
OLD = C.OLD
sha, write, difference, stream = C.sha, C.write, C.difference, C.stream
GODOT = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
physical, compare_traces = C.physical, C.compare_traces
observation_audit, ordered_tape_audit = C.observation_audit, C.ordered_tape_audit
packed_columns, record_compare_view = C.packed_columns, C.record_compare_view
validate_record_identity = C.validate_record_identity


def gate():
    free = shutil.disk_usage('/home').free
    if free < MIN_FREE:
        raise RuntimeError(f'HOME free space {free} < {MIN_FREE}')
    return free


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
    # git is the authoritative exact R19 pin; the outer inventory is corroboration only.
    if commit == BASE:
        pin_path = OUTER/'look/evidence/r20-baseline/SOURCE.json'
        pin = json.loads(pin_path.read_text())
        assert pin['baseline'] == BASE
        assert all(original[k] == digest for k,digest in pin['files'].items() if k in original), 'exact R19 parent source mismatch'
        missing = sorted(set(pin['files'])-set(original))
        assert all(k.endswith('.import') for k in missing), ('non-import source missing from archive',missing)
        archive_info['generated_import_entries_excluded'] = missing
        archive_info['parent_pin_sha256'] = sha(pin_path)
        archive_info['parent_pinned_files_verified'] = len(set(pin['files']) & set(original))
    # the only injected Godot source is the observational adapter. inherited executor remains from git.
    shutil.copy2(PROJECT/'tests/r20_parity.gd', source/'tests/r20_parity.gd')
    executed = {str(p.relative_to(source)): sha(p) for p in sorted(source.rglob('*')) if p.is_file()}
    assert all(executed[k] == v for k,v in original.items() if k != 'tests/r20_parity.gd')
    manifest = {'commit': commit, 'archive': archive_info, 'archive_files': original, 'executed_files': executed,
                'injected': {'tests/r20_parity.gd': executed['tests/r20_parity.gd']}}
    write(out/('source-'+('r19' if commit == BASE else 'candidate')+'.json'), manifest)
    return manifest


def inherited_pins():
    names = ['tools/check-r19-parity.py', 'tools/check-r17-parity.py',
             'tests/r19_parity.gd', 'tests/r17_parity.gd', 'tools/momentum-tape.gd',
             'tools/momentum-tape.py', 'tools/analyze-r16-runs.py']
    pins = {}
    for name in names:
        data = subprocess.check_output(['git','show', BASE+':'+PREFIX+name],cwd=REPO)
        digest = hashlib.sha256(data).hexdigest()
        assert sha(PROJECT/name) == digest, ('inherited helper changed',name)
        pins[name] = digest
    return pins


def host_guard(summary, scene='res://scenes/r19.tscn', script='res://scripts/r19_main.gd'):
    assert summary['host_scene'] == scene and summary['host_script'] == script, 'wrong actual configured host'
    assert summary['checks'] and all(c['ok'] for c in summary['checks']), 'host assertions failed'


def complete_guard(run, plan):
    assert run['ok'] and run['exit'] == 0 and not run['engine_errors'], 'unsuccessful actual play'
    finish = run['summary']['finish']
    assert finish['last_tick']+1 == plan['duration_ticks'], 'incomplete input tape'
    assert finish['finished'] and finish['finish_kind'] == 'clean' and finish['respawns'] == 0, 'not an earned clean route'
    host_guard(run['summary'])


def source_guard(manifest):
    assert manifest['commit'] == manifest['archive']['commit'] == BASE, 'wrong baseline commit'
    assert set(manifest['injected']) == {'tests/r20_parity.gd'}, 'untrusted fixture injection'
    expected = dict(manifest['archive_files'])
    expected.update(manifest['injected'])
    assert expected == manifest['executed_files'], 'archive/injected source mismatch'
    for name,digest in inherited_pins().items():
        assert expected[name] == digest, ('archive helper mismatch', name)
    return True


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
            with Path(str(path)+'.gz').open('wb') as packed, gzip.GzipFile(filename='',mode='wb',compresslevel=6,fileobj=packed,mtime=0) as target:
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


def run_route(route, variant, source, dest, env, out, golden, tape, scene=None, host_script=None, incompatible=False):
    dest.mkdir()
    if golden:
        (dest/'runs').mkdir()
        shutil.copy2(golden,dest/'runs/golden.r16run')
        assert sha(golden) == sha(dest/'runs/golden.r16run')
    command = [str(GODOT),'--headless','--audio-driver','Dummy','--path',str(source),'--fixed-fps','128',
               '--script','res://tests/r20_parity.gd','--',f'--out={dest}',f'--tape={tape}',
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
    assert not stream_errors and all(not t.is_alive() for t in threads), ('trace compression failed',stream_errors)
    for pipe in pipes:
        pipe.unlink()
    run['trace_compression'] = {'method':'regular files streamed to gzip; consumed tmpfs blocks reclaimed after compression', 'receipts':receipts}
    summary_path = dest/'summary.json'
    run['summary'] = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    run['engine_errors'] = [line for line in (dest/'engine.log').read_text().splitlines() if 'ERROR' in line][:12]
    run['ok'] = run['exit'] == 0 and not run['engine_errors'] and bool(run['summary']) and all(c['ok'] for c in run['summary'].get('checks',[]))
    return run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--routes', help='smoke only; full acceptance always needs the complete sixteen')
    parser.add_argument('--candidate', help='reserved: explicit parent frozen commit')
    parser.add_argument('--runtime-freeze', type=Path)
    parser.add_argument('--scoring-contract', type=Path)
    parser.add_argument('--identity-contract', type=Path)
    args = parser.parse_args()
    # no permissive R19 scoring or Breakwater exception is inherited into R20.
    assert not args.candidate, 'R20 candidate acceptance pending parent frozen runtime and reviewed scoring/identity contracts; baseline only in this revision'
    assert not any([args.runtime_freeze,args.scoring_contract,args.identity_contract]), 'contracts belong to the pending candidate stage'
    gate()
    out = args.out.resolve()
    assert out == SCRATCH, 'source/import/profile/evidence scratch must be /tmp/r20-parity-baseline'
    out.mkdir()
    source = out/'snapshot-r19'
    helpers = inherited_pins()
    helpers.update({name:sha(PROJECT/name) for name in ['tools/check-r20-parity.py','tests/r20_parity.gd',
                   'tests/r20_parity_audit.py','tests/r20_parity_mutations.py']})
    report = {'ok':False,'baseline_commit':BASE,'mode':'baseline-only','r20_final_gate':'pending',
              'scope':'fresh exact R19 source plays; candidate matrix, native rendering and packaging remain pending',
              'routes':[],'minimum_home_free_bytes':gate(),'cap_bytes':CAP,'godot':str(GODOT),
              'godot_sha256':sha(GODOT),'verification_source_sha256':helpers}
    try:
        manifest_path = OUTER/'delivery/spillway-r16/VERIFICATION.json'
        manifest = json.loads(manifest_path.read_text())
        report['retained_delivery_manifest_sha256'] = sha(manifest_path)
        routes = manifest['routes']
        assert len(routes) == 16 and len({r['map'] for r in routes}) == 8
        if args.routes:
            names = set(args.routes.split(','))
            routes = [r for r in routes if r['name'] in names]
            assert len(routes) == len(names), 'unknown route'
        report['requested_routes'] = [r['name'] for r in routes]
        source_manifest = freeze(BASE,source,out)
        source_guard(source_manifest)
        report['configured_project_sha256'] = sha(source/'project.godot')
        assert 'run/main_scene="res://scenes/r19.tscn"' in (source/'project.godot').read_text(), 'not exact R19 configured scene'
        pin = json.loads((OUTER/'look/evidence/r19-baseline/SOURCE.json').read_text())
        protected = [k.removeprefix(PREFIX) for k in pin['protected_F2_motor_sources']]
        report['F2_pins_from_exact_R19'] = {k:source_manifest['archive_files'][k] for k in protected}
        expander = module(source/'tools/momentum-tape.py','r20_frozen_tape')
        analyzer = module(source/'tools/analyze-r16-runs.py','r20_frozen_reader')
        report['executed_python_sha256'] = {name:sha(source/name) for name in ['tools/momentum-tape.py','tools/analyze-r16-runs.py']}
        profile = out/'profile'
        profile.mkdir()
        env = OLD.environment(profile)
        env['MALLOC_ARENA_MAX'] = '1'
        cache = out/'import'
        cache.mkdir()
        (source/'.godot').symlink_to(cache)
        report['import'] = bounded([str(GODOT),'--headless','--editor','--path',str(source),'--import'],env,source,out/'import.log',out)
        assert report['import']['exit'] == 0, 'import failed'
        write(out/'REPORT.json',report)
        for route in routes:
            gate()
            folder = out/route['name']
            folder.mkdir()
            retained = Path(route['tape'])
            plan = expander.expand(json.loads(retained.read_text()))
            tape = folder/'expanded.json'
            write(tape,plan)
            result = {'route':route,'tape_sha256':sha(retained),'expanded_sha256':sha(tape),
                      'expected_ticks':plan['duration_ticks'],'runs':{},'comparisons':{}}
            golden = None
            base_records = None
            for variant in ['r19','r19-ghost']:
                run = run_route(route,variant,source,folder/variant,env,out,golden,tape,
                                'res://scenes/r19.tscn','res://scripts/r19_main.gd')
                run['executed_verification_source_sha256'] = helpers
                result['runs'][variant] = run
                write(folder/'result.json',result)
                complete_guard(run,plan)
                path = Path(run['summary']['finish']['record_path'])
                rec,_ = OLD.recording(path,analyzer)
                run['recording_alignment'] = OLD.recording_alignment(rec,folder/variant/'evaluator/trace.jsonl.gz',route['warmup'])
                run['ordered_tape'] = ordered_tape_audit(rec,plan,route['warmup'])
                run['observation_audit'],records = observation_audit(folder/variant,analyzer)
                run['recording'] = {'path':str(path),'sha256':sha(path),'ticks':len(rec.columns['tick']),
                                    'inputs':len(rec.inputs['tick']),'events':len(rec.events)}
                write(folder/'result.json',result)
                assert all(run[k]['ok'] for k in ['recording_alignment','ordered_tape','observation_audit']), 'recording evidence failed'
                if variant == 'r19':
                    golden,base_records = path,records
                else:
                    before = result['runs']['r19']['summary']
                    comparisons = {
                        'motion':compare_traces(folder/'r19/evaluator/trace.jsonl.gz',folder/variant/'evaluator/trace.jsonl.gz'),
                        'recordings':{'ok':difference(base_records,records) is None,'difference':difference(base_records,records)},
                        'ghost_probes':{'ok':difference(before['finish']['ghost_probes'],run['summary']['finish']['ghost_probes']) is None},
                        'controls':{'ok':difference(before['tour'],run['summary']['tour']) is None}}
                    result['comparisons'][variant] = comparisons
                write(folder/'result.json',result)
            result['ok'] = all(c['ok'] for v in result['comparisons'].values() for c in v.values())
            write(folder/'result.json',result)
            report['routes'].append({'name':route['name'],'map':route['map'],'preset':route['preset'],'ok':result['ok'],
                                     'ticks':plan['duration_ticks'],'recordings':sum(r['observation_audit']['recordings'] for r in result['runs'].values())})
            write(out/'REPORT.json',report)
            print(json.dumps(report['routes'][-1]),flush=True)
            assert result['ok'], 'baseline repeat differs; evidence preserved'
        assert all(sha(source/k) == v for k,v in source_manifest['executed_files'].items()), 'executed source changed during capture'
        assert all(sha(PROJECT/k) == v for k,v in helpers.items()), 'verification changed during capture'
        report['source_postflight'] = {'ok':True,'files':len(source_manifest['executed_files'])}
        report['ok'] = len(report['routes']) == 16 and all(r['ok'] for r in report['routes'])
        report['smoke_ok'] = all(r['ok'] for r in report['routes'])
        report['home_free_end'] = gate()
    except BaseException as exc:
        report['error'] = repr(exc)
        raise
    finally:
        for path in [source,out/'import',out/'profile']:
            if path.exists():
                shutil.rmtree(path)
        report['cleanup'] = {'source_import_profile_removed':all(not p.exists() for p in [source,out/'import',out/'profile']),
                             'live_project_cache_untouched':True}
        write(out/'REPORT.json',report)
    return 0 if report.get('smoke_ok') else 1


if __name__ == '__main__':
    raise SystemExit(main())
