#!/usr/bin/env python3
"""prepare, preflight, capture and independently audit the explicit frozen final R20 matrix.

No candidate defaults. --prepare-templates and --preflight never start an engine.
--execute is reserved for the later fully frozen runtime, all sixteen tapes and three looks.
"""
import argparse
import copy
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import r20_candidate_core as K
B,C,P = K.B,K.C,K.P
O = K.module('r20_candidate_observations',K.PROJECT/'tests/r20_candidate_observations.py')


def write(path,value):
    Path(path).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')


def import_metadata_guard(root, generated, executed):
    # only bounded editor sidecars paired with the frozen source may appear after import.
    for name, digest in generated.items():
        relative = Path(name)
        K.need(not relative.is_absolute() and '..' not in relative.parts and relative.as_posix() == name,
            'unsafe generated metadata path: '+name)
        path = root / name
        K.need(path.is_file() and not path.is_symlink() and path.stat().st_size <= 65536,
            'unsupported generated metadata file: '+name)
        K.need(K.sha(path) == digest, 'generated metadata changed: '+name)
        data = path.read_bytes()
        if name.endswith('.uid'):
            paired = name[:-4]
            K.need(paired in executed and Path(paired).suffix in ('.gd', '.gdshader')
                and re.fullmatch(rb'uid://[a-z0-9]{1,13}\n', data) is not None,
                'unpaired or malformed generated UID: '+name)
        elif name.endswith('.import'):
            paired = name[:-7]
            K.need(paired in executed and Path(paired).suffix in ('.png', '.jpg', '.hdr', '.gltf', '.glb', '.ttf')
                and data.startswith(b'[remap]\n'), 'unpaired or malformed generated import: '+name)
        else:
            raise K.Refused('unexpected injected source after import: '+name)
    return True


def templates(commit=None):
    B.gate(); K.PREP.mkdir(exist_ok=True)
    target=K.PREP
    if commit is not None:
        K.need(__import__('re').fullmatch('[0-9a-f]{40}',commit),'explicit full40 template commit required')
        target=K.PREP/commit;target.mkdir()
    policy = K.identity_policy()
    first = K.load(K.BASELINE/'breakwater-basic/r19/readers.json')[0]
    seed = K.A.read(K.BASELINE/'breakwater-basic/r19/runs'/first['file']).header['metadata']
    shared = {'schema':1,'status':'UNFINALIZED','reviewed_by':'','baseline_manifest_sha256':K.BASELINE_MANIFEST_SHA}
    identity = dict(shared,kind='r20-original-map-identity',policy=policy)
    scoring = dict(shared,kind='r20-direction-stack-parity',component_sha256=K.COMPONENT_SHA,
        candidate_commit=commit or 'UNFINALIZED',
        runtime_sources=K.runtime_files(P.committed_manifest(commit,B.PREFIX,B.REPO)) if commit else {},
        verification_helpers=K.helpers(),
        old_metadata={k:seed[k] for k in ('scoring','build','build_label')},
        new_metadata={'scoring':{'style':K.STYLE_ID,'style_key':K.STYLE_KEY,'timing':'r16-timing-1'},
            'build':'spillway-2026.11.10-r20','build_label':'Spillway R20'})
    freeze = {'schema':1,'runtime_frozen':False,'source_commit':commit or 'UNFINALIZED','identity_sha256':'UNFINALIZED',
        'new_maps':list(P.NEW_MAPS),'required_maps':list(P.REQUIRED_MAPS),'experimental_maps':list(P.EXPERIMENTAL_MAPS),
        'reached_items':[],'intentional_changes':{}}
    for name,value in [('IDENTITY-UNFINALIZED.json',identity),('SCORING-UNFINALIZED.json',scoring),('RUNTIME-UNFINALIZED.json',freeze)]:
        path=target/name; K.need(not path.exists(),'never overwrite a review template: '+str(path)); write(path,value)
    return {'ok':True,'scope':'templates only; no candidate or runtime inferred','policy_identities':len(policy['identities'])}


def preflight(args):
    B.gate()
    K.need(type(args.candidate) is str and __import__('re').fullmatch('[0-9a-f]{40}',args.candidate), 'explicit full40 candidate required')
    K.need(all([args.runtime_freeze,args.runtime_identity,args.scoring_contract,args.scoring_contract_sha256,
        args.identity_contract,args.identity_contract_sha256,args.baseline_dir]), 'all explicit parent inputs required')
    K.need(args.baseline_dir.resolve()==K.BASELINE,'baseline substitution or relocation needs a new reviewed implementation')
    frozen = K.load(args.runtime_freeze)
    K.freeze_guard(frozen,args.candidate)
    identity = K.checked_json(args.identity_contract,args.identity_contract_sha256)
    scoring = K.checked_json(args.scoring_contract,args.scoring_contract_sha256)
    runtime_identity = K.load(args.runtime_identity)
    proof = K.baseline_guard()
    files = P.committed_manifest(args.candidate,B.PREFIX,B.REPO)
    K.contracts(frozen,scoring,identity,args.candidate,runtime_identity,files)
    # all current helpers must be committed on the explicit final candidate; loose verification edits refuse.
    K.need(subprocess.check_output(['git','status','--porcelain','--untracked-files=all','--',B.PREFIX],cwd=B.REPO,text=True)=='',
        'dirty or untracked project files cannot be final acceptance')
    pins = {str(p):K.sha(p) for p in [args.runtime_freeze,args.runtime_identity,args.scoring_contract,args.identity_contract]}
    return frozen,scoring,identity,files,{'baseline':proof,'input_sha256':pins,'helpers':K.helpers()}


def snapshot(commit, source, out, expected):
    manifest = B.freeze(commit,source,out)
    K.exact(manifest['archive_files'],expected,'candidate archive differs from committed inventory')
    target = source/'tests/r20_candidate_r19_style.gd'
    K.need(K.sha(target) == K.load(K.BASELINE/'source-r19.json')['archive_files']['scripts/r16_style.gd'],
        'committed observational R19 reference source substitution')
    write(out/'source-candidate.json',manifest)
    return manifest


def route_command(route,variant,source,dest,golden,tape):
    command = [str(B.GODOT),'--headless','--audio-driver','Dummy','--path',str(source),'--fixed-fps','128',
        '--script','res://tests/r20_candidate_parity.gd','--',f'--out={dest}',f'--tape={tape}','--physics-hz=128',
        f'--warmup={route["warmup"]}',f'--map={route["map"]}',f'--preset={route["preset"]}',
        f'--sensitivity={route.get("sensitivity",2.5)}',f'--variant={variant}','--frames=none','--wall-budget-s=150',
        '--host-scene=res://scenes/r20.tscn','--host-script=res://scripts/r20_main.gd',f'--ghost={golden}']
    if variant=='old': command.append('--look=old')
    return command


def run_route(route,variant,source,dest,env,out,golden,tape):
    dest.mkdir(); (dest/'runs').mkdir()
    shutil.copy2(golden,dest/'runs/golden.r16run')
    K.need(K.sha(golden)==K.sha(dest/'runs/golden.r16run'),'golden transport')
    command=route_command(route,variant,source,dest,golden,tape)
    stopped,threads,paths,errors,receipts=B.start_trace_streams(dest)
    try:
        run=B.bounded(command,env,source,dest/'engine.log',out)
    finally:
        stopped.set()
        for thread in threads: thread.join(10)
    K.need(not errors and all(not t.is_alive() for t in threads),'trace compression failure; preserve raw transport')
    for path in paths: path.unlink()
    run['trace_compression']={'receipts':receipts}
    run['summary']=K.load(dest/'summary.json') if (dest/'summary.json').exists() else {}
    run['engine_errors']=[line for line in (dest/'engine.log').read_text().splitlines()
        if any(word in line for word in ('ERROR','SCRIPT ERROR','Assertion failed','Parse Error'))]
    run['ok']=run['exit']==0 and not run['engine_errors'] and bool(run['summary']) and all(c['ok'] for c in run['summary'].get('checks',[]))
    return run


def finalize_transport(folder,report):
    K.need('transport' not in report,'transport already finalized')
    shutil.copy2(folder/'REPORT.json',folder/'REPORT-CAPTURE.json')
    receipts=[]
    for route in report['routes']:
        path=folder/route['name']/'result.json'; result=K.load(path)
        shutil.copy2(path,path.with_name('result-capture.json'))
        for variant,run in result['runs'].items():
            for name,receipt in run['trace_compression']['receipts'].items():
                source=path.parent/variant/'evaluator'/(name+'.gz')
                K.need(K.sha(source)==receipt['gzip_sha256'],'streamed gzip changed')
                temp=source.with_suffix('.canonicalizing')
                got=K.transport(source,temp)
                K.exact({k:got[k] for k in ('raw_sha256','raw_bytes')},
                    {k:receipt[k] for k in ('raw_sha256','raw_bytes')},'raw compression changed')
                test=source.with_suffix('.determinism')
                alt=K.transport(temp,test,1021)
                K.exact(got,alt,'chunk-size-dependent transport')
                test.unlink()
                receipt['streamed_gzip_sha256']=receipt['gzip_sha256']
                receipt['gzip_sha256']=got['gzip_sha256']
                os.replace(temp,source)
                receipts.append({'path':str(source.relative_to(folder)),**receipt})
        write(path,result)
    need_count=16*3*3
    K.need(len(receipts)==need_count,'full 144-stream transport required')
    transport={'ok':True,'determinism_different_chunk_sizes':True,'receipts':receipts,
        'capture_report_sha256':K.sha(folder/'REPORT-CAPTURE.json'),'helper_sha256':K.sha(Path(__file__))}
    write(folder/'TRANSPORT.json',transport)
    report['transport']={'sha256':K.sha(folder/'TRANSPORT.json')};write(folder/'REPORT.json',report)


def stream_comparison(a,b,path,style=False):
    with path.open('wb') as packed,gzip.GzipFile(filename='',mode='wb',fileobj=packed,mtime=0) as output:
        return K.compare_rows(a,b,lambda row:output.write(K.canonical(row)+b'\n'),style)


def audit_route(folder,route,scoring):
    directory=folder/route['name'];result=K.load(directory/'result.json')
    original=K.load(K.BASELINE/route['name']/'result.json')
    K.exact(result['route'],route,'actual route contract')
    K.exact(K.load(directory/'expanded.json'),K.load(K.BASELINE/route['name']/'expanded.json'),'whole tape')
    K.need(K.sha(directory/'expanded.json')==original['expanded_sha256']==result['expanded_sha256'],'expanded tape bytes')
    K.need(K.sha(Path(route['tape']))==original['tape_sha256']==result['tape_sha256'],'retained tape changed')
    K.need(set(result['runs'])==set(K.VARIANTS),'partial look matrix')
    old_dir=K.BASELINE/route['name']/'r19-ghost'
    old_audit,old_records=C.observation_audit(old_dir,K.A)
    K.need(old_audit['ok'],'original independent sample audit')
    comparisons={}
    for variant in K.VARIANTS:
        run_dir=directory/variant;run=result['runs'][variant]
        K.exact(K.load(run_dir/'summary.json'),run['summary'],'raw candidate summary')
        K.exact(run['executed_verification_source_sha256'],K.helpers(),'actual executed helpers')
        golden=Path(original['runs']['r19']['summary']['finish']['record_path'])
        K.exact(run['command'],route_command(route,variant,folder/'source',run_dir,golden,directory/'expanded.json'),'actual command/fixture/scene/ghost/tape')
        K.need(K.sha(run_dir/'runs/golden.r16run')==K.sha(golden),'actual startup golden bytes')
        K.need(run['owned_scratch_peak_bytes']<=B.CAP and run['minimum_home_free_bytes']>=B.MIN_FREE,'actual resource floor/cap')
        K.complete_guard(run,K.load(directory/'expanded.json'),route,variant)
        observed,records=O.observation_audit(run_dir,K.A)
        write(run_dir/'observations-audit.json',observed)
        K.need(observed['ok'],'all samples/inputs/readers/styles: '+repr(observed))
        K.need(len(old_records)==len(records),'missing lifecycle recording')
        separated=[]
        for a,b in zip(old_records,records): separated.append(K.record_compare(a,b,scoring))
        with (run_dir/'record-comparison.json.gz').open('wb') as packed, gzip.GzipFile(filename='',mode='wb',fileobj=packed,mtime=0) as output:
            output.write(K.canonical(separated))
        rec,_=C.OLD.recording(Path(run['summary']['finish']['record_path']),K.A)
        ordered=C.ordered_tape_audit(rec,K.load(directory/'expanded.json'),route['warmup'])
        K.need(ordered['ok'],'complete ordered original tape')
        if route['name']=='r16-lab-flow':
            write(run_dir/'lab-sequence.json',K.lab_guard(C.stream(run_dir/'evaluator/trace.jsonl.gz')))
        motion=stream_comparison(C.stream(old_dir/'evaluator/trace.jsonl.gz'),C.stream(run_dir/'evaluator/trace.jsonl.gz'),
            run_dir/'motion-differences.jsonl.gz',True)
        ghost=stream_comparison(C.stream(old_dir/'evaluator/ghost.jsonl.gz'),C.stream(run_dir/'evaluator/ghost.jsonl.gz'),
            run_dir/'ghost-differences.jsonl.gz')
        provenance=K.module('r20_candidate_ghost_reference',K.PROJECT/'tests/r20_parity_provenance.py')
        golden_record=K.A.read(golden);K.need(golden_record.ok,'golden reader refused')
        pose_at=provenance.ghost_track(golden_record)
        clocks=0
        for actual,ghost_row in __import__('itertools').zip_longest(C.stream(run_dir/'evaluator/trace.jsonl.gz'),C.stream(run_dir/'evaluator/ghost.jsonl.gz')):
            K.need(actual is not None and ghost_row is not None,'ghost/clock stream truncated')
            K.need(ghost_row['loaded'] and ghost_row['shown'],'original golden not live at actual clock')
            K.exact(pose_at(actual['elapsed']),ghost_row['pose_at_clock'],'independent original golden at actual clock')
            clocks+=1
        K.need(clocks==K.load(directory/'expanded.json')['duration_ticks'],'incomplete ghost clocks')
        # all actual samples, including warmup and every lifecycle record, have a physical comparison.
        observation=stream_comparison((K.observation_view(r)[0] for r in C.stream(old_dir/'evaluator/observations.jsonl.gz')),
            (K.observation_view(r)[0] for r in C.stream(run_dir/'evaluator/observations.jsonl.gz')),
            run_dir/'observation-differences.jsonl.gz')
        before=copy.deepcopy(original['runs']['r19-ghost']['summary']['finish'])
        after=copy.deepcopy(run['summary']['finish'])
        before.pop('record_path');after.pop('record_path')
        finish=stream_comparison([before],[after],run_dir/'finish-differences.jsonl.gz',True)
        old_tour=original['runs']['r19-ghost']['summary']['tour'];new_tour=run['summary']['tour']
        def tour_view(rows):
            for row in rows:
                row=copy.deepcopy(row);row['game'].pop('style');yield row
        tour=stream_comparison(tour_view(old_tour),tour_view(new_tour),run_dir/'controls-differences.jsonl.gz')
        K.need(all(r['ok'] for r in separated),'record mismatch; complete raw comparisons retained')
        for kind,comp in [('motion',motion),('ghost',ghost),('observations',observation),('finish',finish),('controls',tour)]:
            K.need(comp['ok'],'raw '+kind+' drift: '+str(run_dir))
        comparisons[variant]={'ok':True,'observations':observed,'motion':motion,'ghost':ghost,'all_samples':observation,
            'finish':finish,'controls':tour,'ordered_tape':ordered}
    return comparisons


def transport_guard(folder,report):
    transport=K.checked_json(folder/'TRANSPORT.json',report['transport']['sha256'])
    K.need(transport['ok'] and transport['determinism_different_chunk_sizes'],'transport not verified')
    K.need(transport['helper_sha256']==K.sha(Path(__file__)),'transport helper changed')
    K.need(K.sha(folder/'REPORT-CAPTURE.json')==transport['capture_report_sha256'],'raw report changed')
    current=copy.deepcopy(report)
    for key in ('transport','audit_routes','home_free_end'):current.pop(key,None)
    current['ok']=False;current['r20_final_gate']='pending'
    K.exact(current,K.load(folder/'REPORT-CAPTURE.json'),'transport changed capture report')
    expected=[]
    for route in report['routes']:
        path=folder/route['name']/'result.json'
        restored=copy.deepcopy(K.load(path))
        for variant,run in restored['runs'].items():
            K.need(set(run['trace_compression']['receipts'])=={'trace.jsonl','ghost.jsonl','observations.jsonl'},'unknown/missing trace stream')
            for name,receipt in run['trace_compression']['receipts'].items():
                relative=str((path.parent/variant/'evaluator'/(name+'.gz')).relative_to(folder))
                expected.append({'path':relative,**copy.deepcopy(receipt)})
                K.need(receipt['lossless_verified'] is True,'unverified raw compression')
                receipt['gzip_sha256']=receipt.pop('streamed_gzip_sha256')
                header=(folder/relative).open('rb')
                with header: head=header.read(10)
                K.need(head[:4]==b'\x1f\x8b\x08\x00' and head[4:8]==bytes(4),'noncanonical gzip header')
        K.exact(restored,K.load(path.with_name('result-capture.json')),'transport changed/dropped raw result fields')
    K.exact(transport['receipts'],expected,'transport receipt set/order')
    K.need(len(expected)==144,'transport lacks all 48 plays/144 streams')
    return transport


def verify(args,preflight_result):
    folder=args.out.resolve();K.need(folder==K.FINAL,'wrong final evidence directory')
    report=K.load(folder/'REPORT.json');K.matrix_guard(report)
    report['ok']=False;report['r20_final_gate']='pending';write(folder/'REPORT.json',report)
    K.need(report['capture_complete'] is True and report['cleanup']['source_import_profile_removed'] and report['source_postflight']['ok'], 'capture/source/cleanup incomplete')
    K.exact(report['inputs'],preflight_result[-1],'reviewed inputs/helpers/baseline changed')
    source=K.load(folder/'source-candidate.json');K.exact(source['archive_files'],preflight_result[3],'source manifest changed')
    K.need(source['commit']==source['archive']['commit']==args.candidate,'wrong source commit')
    with subprocess.Popen(['git','archive','--format=tar',args.candidate,B.PREFIX],cwd=B.REPO,stdout=subprocess.PIPE) as process:
        digest=hashlib.file_digest(process.stdout,'sha256').hexdigest()
        K.need(process.wait()==0 and digest==source['archive']['sha256'],'independent candidate archive reconstruction')
    expected_injected={'tests/r20_parity.gd':K.sha(K.PROJECT/'tests/r20_parity.gd')}
    K.exact(source['injected'],expected_injected,'fixture injection')
    K.exact(source['executed_files'],{**source['archive_files'],**expected_injected},'complete executed source')
    metadata = folder/'generated-import-metadata'
    generated = report['generated_import_metadata']
    K.exact({str(p.relative_to(metadata)):K.sha(p) for p in metadata.rglob('*') if p.is_file()},
        generated, 'retained generated metadata inventory')
    import_metadata_guard(metadata, generated, source['executed_files'])
    transport=transport_guard(folder,report)
    for receipt in transport['receipts']:
        path=folder/receipt['path'];K.need(K.sha(path)==receipt['gzip_sha256'],'trace gzip changed')
        digest=hashlib.sha256();length=0
        with gzip.open(path,'rb') as incoming:
            for block in iter(lambda:incoming.read(65536),b''):digest.update(block);length+=len(block)
        K.need(digest.hexdigest()==receipt['raw_sha256'] and length==receipt['raw_bytes'],'trace raw bytes changed')
    audits=[]
    for route in K.routes():
        audits.append({'route':route['name'],'variants':audit_route(folder,route,preflight_result[1])})
        write(folder/'AUDIT-PROGRESS.json',{'ok':False,'completed':audits})
    # reuse original all-byte negatives unchanged; they only write to the new output directory.
    negative_dir=folder/'original-negative-controls'
    if not negative_dir.exists():
        command=[sys.executable,'-B','tests/r20_parity_mutations.py',str(K.BASELINE),'--out',str(negative_dir)]
        stage=B.bounded(command,dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),K.PROJECT,folder/'negative-controls.log',folder,timeout=600)
        K.need(stage['exit']==0,'original negatives failed')
        write(folder/'NEGATIVE-STAGE.json',stage)
    negatives=K.load(negative_dir/'SUMMARY.json')
    K.need(negatives['ok'] and len(negatives['checks'])==56 and all(c['ok'] for c in negatives['checks']),'original negatives incomplete')
    M=K.module('r20_candidate_mutations',K.PROJECT/'tests/r20_candidate_mutations.py')
    mutations=M.audit(folder,preflight_result[1])
    write(folder/'CANDIDATE-NEGATIVES.json',mutations)
    K.need(mutations['ok'],'candidate mutation refusals failed')
    report['ok']=True;report['r20_final_gate']='passed';report['audit_routes']=len(audits)
    report['home_free_end']=B.gate();write(folder/'REPORT.json',report)
    write(folder/'AUDIT.json',{'ok':True,'routes':audits,'helpers':K.helpers(),'negative_controls':mutations})
    write(folder/'MANIFEST.json',{str(p.relative_to(folder)):K.sha(p) for p in sorted(folder.rglob('*')) if p.is_file() and p!=folder/'MANIFEST.json'})
    return {'ok':True,'plays':48,'routes':16,'maps':8,'scope':'source/headless only; no pack/native/Windows/enjoyment claim'}


def execute(args,preflight_result):
    out=args.out.resolve();K.need(out==K.FINAL and not out.exists(),'future final output must be new /tmp/r20-candidate-parity')
    K.need(shutil.disk_usage('/tmp').free>=B.CAP,'reserve 600MiB owned RAM scratch before final run')
    K.need(K.sha(B.GODOT)==K.load(K.BASELINE/'REPORT.json')['godot_sha256'],'unpinned engine')
    out.mkdir();source=out/'source';profile=out/'profile';cache=out/'import'
    report={'ok':False,'capture_complete':False,'mode':'candidate','baseline_commit':B.BASE,'candidate_commit':args.candidate,
        'r20_final_gate':'pending','inputs':preflight_result[-1],'routes':[],'minimum_home_free_bytes':B.gate()}
    try:
        manifest=snapshot(args.candidate,source,out,preflight_result[3])
        profile.mkdir();cache.mkdir();(source/'.godot').symlink_to(cache)
        env=B.OLD.environment(profile);env['MALLOC_ARENA_MAX']='1'
        report['import']=B.bounded([str(B.GODOT),'--headless','--editor','--path',str(source),'--import'],env,source,out/'import.log',out)
        K.need(report['import']['exit']==0 and not any(word in (out/'import.log').read_text() for word in ('ERROR','Parse Error','Assertion failed')),'candidate import failed')
        generated={str(p.relative_to(source)):K.sha(p) for p in source.rglob('*') if p.is_file() and str(p.relative_to(source)) not in manifest['executed_files']}
        report['generated_import_metadata']=generated
        write(out/'REPORT.json',report)
        import_metadata_guard(source, generated, manifest['executed_files'])
        metadata=out/'generated-import-metadata';metadata.mkdir()
        for name in generated:
            target=metadata/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source/name,target)
        for name,digest in manifest['executed_files'].items():
            K.need(K.sha(source/name)==digest,'import mutated frozen source: '+name)
        for route in K.routes():
            directory=out/route['name'];directory.mkdir()
            original=K.load(K.BASELINE/route['name']/'result.json')
            shutil.copy2(K.BASELINE/route['name']/'expanded.json',directory/'expanded.json')
            golden=Path(original['runs']['r19']['summary']['finish']['record_path'])
            K.need(golden.is_relative_to(K.BASELINE) and K.sha(golden)==original['runs']['r19']['recording']['sha256'],'wrong baseline golden')
            result={'route':route,'expanded_sha256':K.sha(directory/'expanded.json'),'tape_sha256':K.sha(Path(route['tape'])),'runs':{}}
            for variant in K.VARIANTS:
                run=run_route(route,variant,source,directory/variant,env,out,golden,directory/'expanded.json')
                run['executed_verification_source_sha256']=preflight_result[-1]['helpers']
                result['runs'][variant]=run;write(directory/'result.json',result)
                K.complete_guard(run,K.load(directory/'expanded.json'),route,variant)
            report['routes'].append({'name':route['name'],'map':route['map'],'preset':route['preset'],'variants':list(K.VARIANTS)})
            write(out/'REPORT.json',report);print(json.dumps(report['routes'][-1]),flush=True)
        K.exact({str(p.relative_to(source)):K.sha(p) for p in source.rglob('*') if p.is_file()},
            {**manifest['executed_files'],**generated},'complete source/import metadata postflight')
        for name,digest in manifest['executed_files'].items():K.need(K.sha(source/name)==digest,'executed source mutated: '+name)
        K.exact(K.helpers(),preflight_result[-1]['helpers'],'helper mutation during capture')
        report['source_postflight']={'ok':True,'files':len(manifest['executed_files'])}
        report['capture_complete']=True
    except BaseException as exc:
        report['error']=repr(exc);raise
    finally:
        for path in (source,profile,cache):
            if path.exists():shutil.rmtree(path)
        report['cleanup']={'source_import_profile_removed':all(not p.exists() for p in (source,profile,cache)), 'live_cache_untouched':True}
        write(out/'REPORT.json',report)
    finalize_transport(out,report)
    return verify(args,preflight_result)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-templates',action='store_true')
    mode.add_argument('--preflight',action='store_true')
    mode.add_argument('--execute',action='store_true')
    mode.add_argument('--audit',action='store_true')
    parser.add_argument('--candidate');parser.add_argument('--template-commit');parser.add_argument('--baseline-dir',type=Path)
    for name in ('runtime-freeze','runtime-identity','scoring-contract','identity-contract'):
        parser.add_argument('--'+name,type=Path)
    parser.add_argument('--scoring-contract-sha256');parser.add_argument('--identity-contract-sha256')
    parser.add_argument('--out',type=Path)
    args=parser.parse_args(argv)
    try:
        if args.prepare_templates:
            K.need(not any([args.candidate,args.runtime_freeze,args.runtime_identity,args.scoring_contract,args.identity_contract,args.out,args.baseline_dir]),'templates cannot infer/freeze a candidate')
            result=templates(args.template_commit)
        else:
            K.need(args.template_commit is None,'template commit belongs only to engine-free template mode')
            result=preflight(args)
            if args.execute or args.audit:
                K.need(args.out is not None,'explicit future output required')
                result=execute(args,result) if args.execute else verify(args,result)
            else:result={'ok':True,'scope':'read-only preflight; no engine or acceptance','inputs':result[-1]}
        print(json.dumps(result));return 0
    except (K.Refused,P.Rejected,AssertionError,KeyError,ValueError,TypeError,FileNotFoundError) as exc:
        print(json.dumps({'ok':False,'r20_final_gate':'pending','refused':str(exc)}));return 1


if __name__=='__main__':raise SystemExit(main())
