#!/usr/bin/env python3
"""Prepare R21 parity, or later capture/audit the complete explicitly authorized freeze.

Preparation is read-only and engine-free. Execution has no inferred candidate,
review contract, baseline, output, identity, or permission defaults.
"""
import argparse
import fcntl
import gzip
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import r21_parity_core as K


def write(path, value):
    K.B.write(path, value)


def prepare():
    K.B.gate()
    before = K.baseline_guard()
    plans = []
    for route in K.routes():
        plan, encoded = K.route_plan(route)
        plans.append({'name':route['name'], 'tape_sha256':K.sha(Path(route['tape'])),
                      'expanded_sha256':hashlib.sha256(encoded).hexdigest(), 'ticks':plan['duration_ticks']})
    identity = K.identity_policy()
    result = {'prepared':True, 'runtime_checked':False, 'matrix_accepted':False,
              'baseline':before, 'routes':plans, 'fresh_plays_required':48,
              'original_identity_count':len(identity['identities']), 'helpers':K.helpers(),
              'pending':['parent reviewed final committed runtime/identity/intentional-hash contract',
                         'explicit capture authorization bound to reviewed contract hash',
                         'Godot parse/import and fresh actual R21 48-play matrix',
                         'independent --audit including unchanged original 56 controls'],
              'limits':{'preparation_tmp_bytes':K.PREP_CAP, 'durable_bytes':5*2**20,
                        'capture_owned_bytes':K.B.CAP, 'home_floor_bytes':K.B.MIN_FREE}}
    K.exact(K.baseline_guard(), before, 'baseline changed during read-only preparation')
    return result


def preflight(args):
    K.B.gate()
    K.need(type(args.candidate) is str and __import__('re').fullmatch('[0-9a-f]{40}', args.candidate),
           'explicit full40 frozen candidate required')
    K.need(all((args.baseline_dir, args.freeze, args.freeze_sha256, args.identity,
                args.contract, args.contract_sha256)), 'all explicit reviewed inputs required')
    K.need(args.baseline_dir == K.BASELINE and not args.baseline_dir.is_symlink(), 'exact restored baseline required')
    before = K.baseline_guard()
    freeze = K.checked(args.freeze, args.freeze_sha256)
    contract = K.checked(args.contract, args.contract_sha256)
    identity = K.load(args.identity)
    K.need(subprocess.run(['git','merge-base','--is-ancestor',K.BASE,args.candidate],
                         cwd=K.B.REPO, capture_output=True).returncode == 0, 'candidate not descended from promoted R20')
    K.need(subprocess.check_output(['git','branch','--show-current'], cwd=K.B.REPO, text=True).strip()
           == 'feat/spillway-r21', 'only the R21 feature branch is allowed')
    K.need(subprocess.check_output(['git','status','--porcelain','--untracked-files=all','--',K.B.PREFIX],
                                 cwd=K.B.REPO, text=True) == '', 'dirty/untracked project source refuses final acceptance')
    # inventory uses streamed Git archives with tree/blob/mode verification; never trust a dirty HEAD snapshot.
    guard = K.module('r21_committed_inventory', K.PROJECT/'tools/check-r21-preservation.py')
    K.need(K.D.committed_bytes(args.candidate, 'tools/check-r21-preservation.py')
           == (K.PROJECT/'tools/check-r21-preservation.py').read_bytes(), 'preservation helper not frozen on candidate')
    K.need(subprocess.check_output(['git','rev-parse','HEAD'], cwd=K.B.REPO, text=True).strip()
           == args.candidate, 'explicit candidate must equal the parent frozen complete HEAD')
    inventory = guard.inventory(args.candidate)
    files = {n:v['sha256'] for n,v in inventory['files'].items()}
    preservation = K.validate_contract(freeze, contract, args.candidate, identity, files, args.freeze_sha256)
    plans = {r['name']:hashlib.sha256(K.route_plan(r)[1]).hexdigest() for r in K.routes()}
    K.exact(K.baseline_guard(), before, 'baseline changed during preflight')
    return {'candidate_commit':args.candidate, 'freeze_sha256':args.freeze_sha256,
            'contract_sha256':args.contract_sha256, 'identity_sha256':K.sha(args.identity),
            'baseline':before, 'source':inventory, 'helpers':K.helpers(), 'plans':plans,
            'preservation':preservation, 'contract':contract}


def source_state(root, cache):
    K.need((root/'.godot').is_symlink() and (root/'.godot').resolve() == cache.resolve(), 'private import cache binding')
    result = {}
    for path in root.rglob('*'):
        if path == root/'.godot':
            continue
        K.need(not path.is_symlink() and (path.is_file() or path.is_dir()), 'unknown source/import link/type')
        if path.is_file():
            result[path.relative_to(root).as_posix()] = K.sha(path)
    return result


def imported_source(root, cache, files, inventory=None):
    actual = source_state(root, cache)
    K.need(inventory is not None, 'complete committed source modes required')
    for name, entry in inventory.items():
        K.need((root/name).stat().st_mode & 0o777 == int(entry['mode'],8) & 0o777,
               'private source mode changed: '+name)
    K.need(all(actual.get(n) == v for n,v in files.items()), 'private committed source missing/changed')
    added = {n:v for n,v in actual.items() if n not in files}
    K.G.import_metadata_guard(root, added, files)
    return added


def snapshot(commit, source, expected):
    source.mkdir()
    process = subprocess.Popen(['git','archive','--format=tar',commit+':projects/foldrunner'],
                               cwd=K.B.REPO, stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=process.stdout, mode='r|') as packed:
            seen = set()
            for item in packed:
                name = item.name
                K.need(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe private archive')
                if item.isdir():
                    continue
                K.need(item.isfile() and name in expected and name not in seen, 'unknown/duplicate archive entry')
                seen.add(name)
                target = source/name
                target.parent.mkdir(parents=True, exist_ok=True)
                with packed.extractfile(item) as incoming, target.open('wb') as outgoing:
                    shutil.copyfileobj(incoming, outgoing, 65536)
                os.chmod(target, int(expected[name]['mode'], 8) & 0o777)
                K.need(K.sha(target) == expected[name]['sha256'], 'candidate private archive bytes')
        K.exact(sorted(seen), sorted(expected), 'private committed source membership')
    finally:
        process.stdout.close()
        K.need(process.wait() == 0, 'private archive failed')


def run_route(route, variant, source, dest, profile, out, plan):
    dest.mkdir()
    (dest/'runs').mkdir()
    golden = K.BASELINE/route['name']/'old/runs/golden.r16run'
    shutil.copy2(golden, dest/'runs/golden.r16run')
    K.need(K.sha(golden) == K.sha(dest/'runs/golden.r16run'), 'golden fixture transport')
    command = K.route_command(route, variant, source, dest, golden, plan)
    env = K.B.OLD.environment(profile)
    env['MALLOC_ARENA_MAX'] = '1'
    stopped, threads, paths, errors, receipts = K.B.start_trace_streams(dest)
    try:
        run = K.B.bounded(command, env, source, dest/'engine.log', out)
    finally:
        stopped.set()
        for thread in threads:
            thread.join(10)
    K.need(not errors and all(not t.is_alive() for t in threads), 'raw stream transport failed; retain proof')
    for path in paths:
        path.unlink()
    run['trace_compression'] = {'receipts':receipts}
    run['summary'] = K.load(dest/'summary.json')
    run['engine_errors'] = [line for line in (dest/'engine.log').read_text().splitlines()
                            if any(t in line for t in ('ERROR','Parse Error','Assertion failed'))]
    run['ok'] = run['exit'] == 0 and not run['engine_errors']
    K.need(run['ok'], 'candidate play failed')
    return run


def execute(args, inputs):
    # a reviewed contract is not itself permission to start an engine.
    K.need(args.authorize_capture == args.contract_sha256, 'explicit --authorize-capture REVIEWED_CONTRACT_SHA256 required')
    K.need(args.out == K.FINAL and not args.out.exists(), 'new exact /tmp/r21-candidate-parity output required')
    K.need(shutil.disk_usage('/tmp').free >= K.B.CAP, 'reserve inherited 600MiB owned scratch cap')
    engine_pins = K.D.r20.engine_pins()
    K.need(K.sha(K.B.GODOT) == engine_pins['editor_sha256'], 'pinned official engine required')
    # nonblocking flock never queues an unexpected engine behind another worker.
    with K.LOCK.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise K.Refused('R21 engine lock held; no engine started')
        out = args.out
        out.mkdir()
        source, cache, profile = out/'source', out/'import', out/'profile'
        report = {'ok':False, 'capture_complete':False, 'r21_final_gate':'pending',
                  'inputs':inputs, 'engine_pins':engine_pins, 'routes':[]}
        try:
            snapshot(args.candidate, source, inputs['source']['files'])
            cache.mkdir()
            profile.mkdir()
            (source/'.godot').symlink_to(cache)
            files = {n:v['sha256'] for n,v in inputs['source']['files'].items()}
            report['source_before_import'] = source_state(source, cache)
            K.exact(report['source_before_import'], files, 'before import source inventory')
            env = K.B.OLD.environment(profile)
            env['MALLOC_ARENA_MAX'] = '1'
            report['import'] = K.B.bounded([str(K.B.GODOT),'--headless','--editor','--path',str(source),'--import'],
                                          env, source, out/'import.log', out)
            K.need(report['import']['exit'] == 0 and not any(t in (out/'import.log').read_text()
                    for t in ('ERROR','Parse Error','Assertion failed')), 'R21 import failed')
            generated = imported_source(source, cache, files, inputs['source']['files'])
            report['generated_import_metadata'] = generated
            report['source_after_import'] = source_state(source, cache)
            for name in generated:
                target = out/'generated-import-metadata'/name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source/name, target)
            for route in K.routes():
                directory = out/route['name']
                directory.mkdir()
                plan, encoded = K.route_plan(route)
                (directory/'expanded.json').write_bytes(encoded)
                result = {'route':route, 'runs':{}}
                for variant in K.VARIANTS:
                    K.exact(imported_source(source, cache, files, inputs['source']['files']), generated, 'before play frozen source/import inventory')
                    K.exact(K.fixture_binding(route), inputs['contract']['fixtures'][route['name']], 'actual original fixture before play')
                    run = run_route(route, variant, source, directory/variant, profile, out, directory/'expanded.json')
                    run['helpers'] = K.helpers()
                    K.exact(run['helpers'], inputs['helpers'], 'actual capture helper inventory')
                    K.summary_guard(run['summary'], route, variant, plan, inputs['contract'])
                    result['runs'][variant] = run
                    write(directory/'result.json', result)
                    K.exact(imported_source(source, cache, files, inputs['source']['files']), generated, 'after play frozen source/import inventory')
                report['routes'].append({'name':route['name'], 'map':route['map'], 'preset':route['preset'],
                                         'variants':list(K.VARIANTS)})
                write(out/'REPORT.json', report)
                print(route['name']+': all three captured; audit pending', flush=True)
            K.exact(K.helpers(), inputs['helpers'], 'post-matrix helpers')
            K.exact({r['name']:K.fixture_binding(r) for r in K.routes()}, inputs['contract']['fixtures'], 'post-matrix fixture bindings')
            K.exact(K.baseline_guard(), inputs['baseline'], 'post-matrix baseline')
            report['source_postflight'] = {'ok':True, 'files':len(files),
                                           'inventory':source_state(source, cache), 'helpers':K.helpers()}
            report['capture_complete'] = True
        except BaseException as exc:
            report['error'] = repr(exc)
            raise
        finally:
            # retain raw outputs/receipts on any failure; remove only this invocation's private source/cache/profile.
            for path in (source, cache, profile):
                if path.exists():
                    shutil.rmtree(path)
            report['cleanup'] = {'private_source_import_profile_removed':all(not p.exists() for p in (source,cache,profile))}
            write(out/'REPORT.json', report)
        transport = []
        for route in K.routes():
            result = K.load(out/route['name']/'result.json')
            for variant in K.VARIANTS:
                for name in ('trace.jsonl','ghost.jsonl','observations.jsonl'):
                    receipt = result['runs'][variant]['trace_compression']['receipts'][name]
                    transport.append({'path':route['name']+'/'+variant+'/evaluator/'+name+'.gz', **receipt})
        write(out/'TRANSPORT.json', {'receipts':transport, 'report_sha256':K.sha(out/'REPORT.json')})
        write(out/'RAW-MANIFEST.json', {p.relative_to(out).as_posix():K.sha(p)
                                       for p in sorted(out.rglob('*')) if p.is_file()})
    # a new Python process reopens all completed raw evidence after capture, never reports R21 acceptance here.
    command = [sys.executable, '-B', str(K.PROJECT/'tests/r21_parity_audit.py'), '--audit']
    for field in ('candidate','baseline_dir','freeze','freeze_sha256','identity','contract','contract_sha256','out'):
        command.extend(['--'+field.replace('_','-'), str(getattr(args,field))])
    return subprocess.run(command, cwd=K.PROJECT).returncode


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    modes = p.add_mutually_exclusive_group(required=True)
    for mode in ('prepare','preflight','execute','audit'):
        modes.add_argument('--'+mode, action='store_true')
    for field in ('candidate','freeze-sha256','contract-sha256','authorize-capture'):
        p.add_argument('--'+field)
    for field in ('baseline-dir','freeze','identity','contract','out'):
        p.add_argument('--'+field, type=Path)
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.prepare:
            print(__import__('json').dumps(prepare(), indent=2))
            return 0
        if args.audit and args.out == K.FINAL and (args.out/'audit').is_dir():
            write(args.out/'audit/AUDIT.json', {'ok':False, 'r21_final_gate':'pending', 'reason':'independent audit requested'})
        inputs = preflight(args)
        if args.preflight:
            print(__import__('json').dumps({'preflight':True, 'runtime_checked':False, 'matrix_accepted':False,
                                          'candidate_commit':args.candidate, 'helpers':inputs['helpers']}, indent=2))
            return 0
        if args.audit:
            audit = K.module('r21_independent_auditor', K.PROJECT/'tests/r21_parity_audit.py')
            return audit.audit(args, inputs)
        return execute(args, inputs)
    except (ValueError, OSError, AssertionError, KeyError, TypeError, RuntimeError, subprocess.SubprocessError) as exc:
        print('r21-parity refused: '+str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
