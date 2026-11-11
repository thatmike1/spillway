#!/usr/bin/env python3
"""independent binary/source audit; production completion cannot be inferred from component adapters."""
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
BASE='e6baa995da84d380abc8b8d6a3769b33e771945e'
MODELS=['classic','pendulum','elastic','elastic-soft','elastic-firm','elastic-arc']


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def load_reader():
    spec=importlib.util.spec_from_file_location('original_tether_reader',PROJECT/'tools/analyze-r16-runs.py')
    module=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=module
    spec.loader.exec_module(module)
    return module


def trace(root):
    with gzip.open(Path(root)/'trace.jsonl.gz','rt') as stream:
        return [json.loads(line) for line in stream]


def human_audit(run):
    reader=load_reader()
    fixtures=[('first-transfer-manual','human-first-d','human-revised-first',371,'transfer_1_0_0'),('dispatch-manual','human-dispatch-manual','human-isolated-dispatch-manual',1146,'transfer_3_0_0'),('dispatch-automatic','human-dispatch-automatic','human-isolated-dispatch-automatic',1528,'transfer_3_0_0')]
    results=[]
    for name,baseline,corrected,contact_tick,body in fixtures:
        folder=Path('/tmp/r21-recorded-clips-02')/name
        provenance=read(folder/'provenance.json')
        original=Path(provenance['source_recording'])
        assert sha(original)==provenance['source_sha256']
        rec=reader.read(original)
        assert rec.ok,rec.errors
        before=trace(run/baseline)
        after=trace(run/corrected)
        assert len(before)==len(rec.columns['tick'])==len(after)
        for i,row in enumerate(before):
            for key in ['p','v']:
                assert row[key]==[rec.columns[key+'_'+axis][i] for axis in 'xyz'],(name,i,key)
            for key in ['yaw','pitch']:
                assert row[key]==rec.columns[key][i],(name,i,key)
        # the three causal probes must match every sample before the actual offending contact.
        for i in range(contact_tick):
            for key in ['p','v','yaw','pitch']:
                assert before[i][key]==after[i][key],(name,'pre-contact drift',i,key)
        assert any(c['body']==body and c['normal']==[0.0,0.0,1.0] and c['blocking'] for c in before[contact_tick]['motion']['contacts'])
        window=provenance['window_inclusive']
        blocking=[(r['tick'],c) for r in after[window[0]:window[1]+1] for c in r['motion']['contacts'] if c['body']==body and c['normal']==[0.0,0.0,1.0] and c['blocking']]
        assert not blocking,(name,'corrected front still blocks',blocking[:1])
        assert before[contact_tick]['p']!=after[contact_tick]['p']
        # all raw input fields, including unscaled screen_relative and derived action audit rows, remain pinned.
        tape=read(folder/'inputs.tape.json')
        expected=[{key:column[i] for key,column in rec.inputs.items()} for i,kind in enumerate(rec.inputs['kind']) if kind in {1,2,3}]
        assert [event['raw'] for event in tape['events']]==expected
        results.append(dict(fixture=name,source_sha256=sha(original),samples=len(before),all_positions_velocities_yaw_pitch_exact=True,first_geometry_divergence_tick=contact_tick,confirmed_body=body,normal=[0,0,1],corrected_front_contacts=0,correction_scope='full revised production geometry' if name.startswith('first') else 'labelled geometry-only dispatch support probe in frozen host',recording_unchanged=sha(original)==provenance['source_sha256']))
    return results


def route_audit(run, routes, production=False):
    reader=load_reader()
    results=[]
    for model in MODELS:
        folder=Path(routes[model]); replay=Path(routes[model+'_replay'])
        a=read(folder/'summary.json');b=read(replay/'summary.json')
        for summary in [a,b]:
            assert summary['pass'] and summary['finished'] and summary['finish_kind']=='clean' and summary['respawns']==0
            assert summary['anchors'].keys()=={'Transfer 1','Transfer 2','Transfer 3'}
            assert summary['actual_v_mismatches']==0 and summary['rate_mismatch_ticks']==0
            if production:
                assert summary['scope']=='actual production host/UI'
        def recording(summary):
            wire=next(row for row in summary['recordings'] if row['clean_finish'].get('ok'))
            rec=reader.read(Path(wire['path']))
            assert rec.ok,rec.errors
            return rec,wire
        ra,wa=recording(a);rb,wb=recording(b)
        assert ra.columns==rb.columns,(model,'binary physics differs')
        assert ra.inputs==rb.inputs,(model,'full ordered raw/action inputs differ')
        at,bt=trace(folder),trace(replay)
        assert len(at)==len(bt)
        for i,(x,y) in enumerate(zip(at,bt)):
            for key in ['p','reference_p','v','yaw','pitch','grounded','checkpoint','elapsed','respawns','style']:
                assert x[key]==y[key],(model,i,key)
        results.append(dict(model=model,scope=a['scope'],ticks=a['ticks'],elapsed_s=a['elapsed'],geometry=a['geometry_hash'],recording_sha256=sha(wa['path']),replay_sha256=sha(wb['path']),binary_columns_exact=True,full_raw_and_action_input_columns_exact=True,trace_rows=len(at),route=str(folder),replay=str(replay)))
    return results


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',type=Path,required=True)
    parser.add_argument('--routes',type=Path)
    parser.add_argument('--production',action='store_true')
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    result=dict(ok=True,scope='production' if args.production else 'component audit; final host pending',human_replays=human_audit(args.run),routes=route_audit(args.run,read(args.routes),args.production) if args.routes else [])
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print('audit passed',len(result['human_replays']),'human comparisons,',len(result['routes']),'earned model replay pairs')

if __name__=='__main__':
    main()
