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


def execution_receipt(run, folder, summary, model, replay):
    receipt = read(run / (folder.name + '.receipt.json'))
    assert receipt['ok'] is True and receipt['exit'] == 0 and not receipt['failure']
    assert receipt['log_sha256'] == sha(run / (folder.name + '.log'))
    assert receipt['engine_sha256'] == '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
    argv = receipt['argv']
    assert argv.count('--script') == 1 and argv[argv.index('--script') + 1] == 'res://tests/r21_tether_route.gd'
    assert '--model=' + model in argv and '--out=' + str(folder) in argv
    if summary['scope'] == 'actual production host/UI':
        assert receipt['scope'] == 'production snapshot' and '--production=1' in argv
    assert summary['options']['model'] == model
    assert summary['mode'] == ('open-loop saved input' if replay else 'coordinate-aware input only')
    assert any(arg.startswith('--tape=') for arg in argv) == replay
    return receipt


def route_binding(record, summary, model):
    assert record.header['identity'] == summary['identity']
    identity = record.header['identity']
    assert identity['runner'] == 'res://scripts/r21_tether_player.gd' and identity['map'] == 'tether-yard'
    assert identity['preset'] == 'server128' and identity['physics_hz'] == summary['physics_hz'] == 128
    assert identity['geometry'] == summary['geometry_hash'] == '93f8593e156dd29a1f907e7af219e74d3ff666fee82423bc722270274b43dba6'
    mechanics = record.header['metadata']['physics']['mechanics']
    law = [entry for entry in mechanics if entry.get('version') == 'r21-tether-elastic-1']
    assert len(law) == 1 and law[0]['model'] == model and law[0]['automatic_reel'] is False
    assert not summary['options'].get('auto', False) and not summary['options'].get('assist-off', False)
    assert law[0]['acquisition']['law'] == ('r20-original-aim' if model in ('classic', 'pendulum') else 'r21-anchor-assist-1')
    return identity


def route_audit(run, routes, production=False):
    reader=load_reader()
    results=[]
    selected = [Path(routes[model + suffix]).resolve() for model in MODELS for suffix in ('', '_replay')]
    assert len(set(selected)) == 12, 'each model and replay requires a distinct execution'
    sources = None
    keys = set()
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
        assert Path(wa['path']).resolve().parent == (folder / 'recordings').resolve()
        assert Path(wb['path']).resolve().parent == (replay / 'recordings').resolve()
        assert Path(wa['path']).resolve() != Path(wb['path']).resolve()
        identity = route_binding(ra, a, model)
        assert route_binding(rb, b, model) == identity
        assert identity['course_key'] not in keys, 'model identities must differ'
        keys.add(identity['course_key'])
        ea = execution_receipt(run, folder, a, model, False)
        eb = execution_receipt(run, replay, b, model, True)
        def executed_sources(receipt):
            return {name: value for name, value in receipt['source_sha256'].items()
                    if name.startswith(('scripts/', 'scenes/', 'assets/', 'data/')) or name in
                    ('project.godot', 'tests/r21_tether_route.gd', 'tests/r21_tether_adapter.gd',
                     'tests/r14_practice_driver.gd', 'tests/r19_tether_geometry.gd')}
        pins = executed_sources(ea)
        assert all(name in pins for name in ('scripts/r21_tether_player.gd', 'scripts/r21_tether_level.gd', 'tests/r21_tether_route.gd'))
        assert pins == executed_sources(eb), 'finder and replay executed different runtime/driver sources'
        assert sources is None or sources == pins, 'models executed different runtime/driver sources'
        sources = pins
        tape_args = [arg.split('=', 1)[1] for arg in eb['argv'] if arg.startswith('--tape=')]
        assert len(tape_args) == 1 and b['options']['tape'] == tape_args[0]
        tape = read(tape_args[0])
        assert tape['version'] == 2 and tape['physics_hz'] == 128 and tape['duration_ticks'] == a['ticks'] == b['ticks']
        warmup = int(a['options'].get('warmup', 33))
        raw = [{key: column[i] for key, column in ra.inputs.items()} for i, kind in enumerate(ra.inputs['kind']) if kind in (1, 2, 3)]
        assert tape['events'] == [{'tick': int(row['tick']) - warmup, 'raw': row} for row in raw]
        for first, second, label in [(ra.columns, rb.columns, 'physics'), (ra.inputs, rb.inputs, 'ordered raw/action inputs')]:
            assert first.keys() == second.keys(), (model, label, 'column membership')
            for name in first:
                assert first[name].typecode == second[name].typecode and first[name].tobytes() == second[name].tobytes(), (model, label, name)
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
