#!/usr/bin/env python3
"""publish a bounded truthful component packet; production acceptance requires actual host/UI proof."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[1]
MODELS=['classic','pendulum','elastic','elastic-soft','elastic-firm','elastic-arc']


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def write(path,value):
    Path(path).write_text(json.dumps(value,indent=2)+'\n')


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec)
    sys.modules[name]=result
    spec.loader.exec_module(result)
    return result


def readers(run, label):
    # use the unchanged cross-reader comparator, independently of the route summary's ok flags.
    original=module('r20_tether_cross_reader',PROJECT/'tests/r20_tether_check.py')
    index=read(run/label/'index.json')
    original.READER_WIRES={row['path']:row for row in index}
    reader=original.load_reader(PROJECT)
    records=[]
    for wire in index:
        original.cross_reader(reader,wire,records)
    assert records
    return dict(ok=True,records=records,scope='both unchanged strict readers; all header/seal/events/inputs/physical columns',numeric_json_tolerance=1e-13,python_reader_sha256=sha(PROJECT/'tools/analyze-r16-runs.py'),godot_reader_sha256=sha(PROJECT/'scripts/r16_run_reader.gd'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--component',default='component-final-e')
    parser.add_argument('--readers',default='readers-component')
    parser.add_argument('--production-routes',type=Path)
    parser.add_argument('--boundaries')
    parser.add_argument('--reload')
    args=parser.parse_args()
    run=args.run.resolve();out=args.out.resolve()
    out.mkdir(parents=True,exist_ok=True)
    audit=module('r21_tether_auditor',PROJECT/'tests/r21_tether_audit.py')
    component=read(run/args.component/'summary.json')
    assert component['ok'] and all(row['ok'] for row in component['checks'])
    assert read(run/'geometry-final/summary.json')['ok']
    assert all(row['detected'] and row['exit']==1 for row in read(run/'MUTATIONS.json'))
    result=dict(ok=True,component_checks=component['checks'],applied_arc_probes=component['applied_arc_probes'],stresses=component['stresses'],human_replays=audit.human_audit(run),component_routes=audit.route_audit(run,read(run/'component-routes.json')),mutations=read(run/'MUTATIONS.json'),geometry=read(run/'geometry-final/summary.json'))
    production_ok=False
    if args.production_routes:
        assert args.boundaries and args.reload
        result['production_routes']=audit.route_audit(run,read(args.production_routes),production=True)
        boundaries=read(run/args.boundaries/'summary.json')
        assert boundaries['ok'] and all(row['ok'] for row in boundaries['checks'])
        assert read(run/args.reload/'summary.json')['ok']
        result['production_boundaries']=boundaries['checks']
        production_ok=True
    read_proof=readers(run,args.readers)
    # per-run receipts bind what really ran; accepted gameplay cannot borrow a later source hash.
    receipts={p.name:dict(sha256=sha(p),ok=read(p)['ok'],exit=read(p)['exit'],failure=read(p)['failure'],mutation=read(p).get('mutation')) for p in run.glob('*.receipt.json')}
    owned=[*PROJECT.glob('scripts/r21_tether*'),*PROJECT.glob('tests/r21_tether*'),PROJECT/'docs/r21/TETHER.md']
    sources={str(p.relative_to(PROJECT)):sha(p) for p in owned if p.is_file()}
    runtime={key:value for key,value in sources.items() if key.startswith('scripts/') and key.endswith('.gd')}
    executed=read(run/(args.component+'.receipt.json'))['source_sha256']
    assert all(executed.get(name)==value for name,value in runtime.items()),'final runtime differs from accepted component'
    if args.production_routes:
        for name in MODELS:
            folder=Path(read(args.production_routes)[name])
            receipt=read(run/(folder.name+'.receipt.json'))
            assert receipt['scope']=='production snapshot'
            assert all(receipt['source_sha256'].get(path)==value for path,value in runtime.items())
    source=dict(baseline=audit.BASE,engine_sha256=read(run/(args.component+'.receipt.json'))['engine_sha256'],final_owned_sha256=sources,runtime_sha256=runtime,receipts=receipts,source_receipts='each raw *.receipt.json contains the complete executed source hash inventory; failed mutations retain their changed inventory')
    raw={str(p.relative_to(run)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in run.rglob('*') if p.is_file() and not {'source','profiles'} & set(p.relative_to(run).parts)}
    # publish actual JSON projections used by the delivery observer as well as Godot law/identity hashes.
    rules={}
    for name,identity in component['identities'].items():
        projection=dict(classic=identity['classic'],alternative=identity['alternative'],controls=identity['controls'],effective_reel_ups=identity['reel_ups'])
        rules[name]=dict(projection=projection,python_canonical_sha256=hashlib.sha256(json.dumps(projection,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest(),godot_law_sha256=component['rules_hashes'][name],godot_identity_sha256=component['identity_hashes'][name])
    remaining=['parent independent GPT review','parent native screenshots/listening/feel','package adapter/exact packed controls and recorded-input replays','portable Linux/Windows verification and promotion']
    if not production_ok:
        remaining.insert(0,'actual configured R21 production host/UI six-model routes, recordings, lifecycle, reload and ghost checks after Saltglass gate and parent wiring')
    acceptance=dict(component_ok=True,production_host_ok=production_ok,release_ok=False,remaining=remaining)
    result['supplemental_production_routes']=read(run/'SUPPLEMENTAL.json') if (run/'SUPPLEMENTAL.json').exists() else []
    result['attempts']=read(run/'ATTEMPTS.json')
    result['preservation']=read(run/'PRESERVATION.json')
    assert result['preservation']['ok'] and result['preservation']['baseline_file_count']==1404
    write(out/'ACCEPTANCE.json',acceptance)
    write(out/'AUDIT.json',result)
    write(out/'READERS.json',read_proof)
    write(out/'SOURCE.json',source)
    write(out/'RAW.json',raw)
    cleanup=read(run/'CLEANUP.json') if (run/'CLEANUP.json').exists() else dict(done=False,reason='private source/import/profile snapshot retained until actual production proof')
    write(out/'CLEANUP.json',cleanup)
    packet=dict(schema=1,status='production host verified; parent delivery gates pending' if production_ok else 'component verified; production host gate pending',acceptance=acceptance,models=MODELS,model_rules=rules,geometry=result['geometry'],source=runtime,raw_root=str(run),raw_inventory='RAW.json',feature_tapes={name:{'path':str(run/(name+'-production-recorded.tape.json')),'sha256':sha(run/(name+'-production-recorded.tape.json'))} for name in MODELS} if production_ok else {},apis=['configure_tether(model,automatic)','configure_anchor_assist(bool)','r21_acquisition_snapshot()','r21_law_rules()','r21_law_sha256()','r21_rules_sha256()'],evidence={name:sha(out/name) for name in ['ACCEPTANCE.json','AUDIT.json','READERS.json','SOURCE.json','RAW.json','CLEANUP.json']})
    write(out/'CONTRACT.json',packet)
    assert sum(p.stat().st_size for p in out.rglob('*') if p.is_file())<=10*2**20
    print(packet['status'])

if __name__=='__main__':
    main()
