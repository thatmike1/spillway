#!/usr/bin/env python3
"""negative controls on private copies of actual candidate data; never rewrite the baseline."""
import copy
import json
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import r20_candidate_core as K


def audit(folder, scoring):
    M=K.module('r20_candidate_original_mutations',K.PROJECT/'tests/r20_parity_mutations.py')
    directory=folder/'breakwater-basic/new'
    summary=K.load(directory/'summary.json')
    record_path=Path(summary['finish']['record_path'])
    record,canonical=K.C.OLD.recording(record_path,K.A)
    baseline_result=K.load(K.BASELINE/'breakwater-basic/result.json')
    old_path=Path(baseline_result['runs']['r19-ghost']['summary']['finish']['record_path'])
    _,old=K.C.OLD.recording(old_path,K.A)
    checks=[]
    def rejects(name,call):
        try:
            outcome=call()
            refused=isinstance(outcome,dict) and outcome.get('ok') is False
        except (K.Refused,K.P.Rejected,AssertionError,KeyError,ValueError,TypeError):
            refused=True
        else:
            if not isinstance(outcome,dict):refused=False
        checks.append({'name':name,'refused':refused})
    scratch=folder/'mutation-working';K.need(not scratch.exists(),'mutation scratch exists');scratch.mkdir()
    try:
        data=record_path.read_bytes()
        for group,names in [('columns',K.A.COLUMN_NAMES),('inputs',[n for n,_,_ in K.A.INPUT_LAYOUT])]:
            for name in names:
                path=scratch/'mutant.r16run';path.write_bytes(M.rewrite(data,M.column_edit(group,name)))
                rec=K.A.read(path)
                if not rec.ok:
                    checks.append({'name':'valid-chain '+group+'.'+name,'refused':True,'reader_errors':rec.errors})
                else:
                    wanted=K.C.packed_columns(getattr(record,group),group=='columns')
                    got=K.C.packed_columns(getattr(rec,group),group=='columns')
                    checks.append({'name':'valid-chain '+group+'.'+name,'refused':K.C.difference(wanted,got) is not None})
        for name in K.META_KEYS:
            bad=copy.deepcopy(canonical);bad['header']['metadata'][name]={'unreviewed':name}
            rejects('every metadata field '+name,lambda b=bad:K.record_compare(old,b,scoring))
        for name in K.IDENTITY_KEYS:
            bad=copy.deepcopy(canonical);bad['header']['identity'][name]='unreviewed'
            rejects('every identity field '+name,lambda b=bad:K.record_compare(old,b,scoring))
        bad=copy.deepcopy(canonical);bad['header']['metadata']['unknown']=1
        rejects('unknown metadata',lambda:K.record_compare(old,bad,scoring))
        observations=list(K.C.stream(directory/'evaluator/observations.jsonl.gz'))
        by_id={}
        for row in observations:by_id.setdefault(row['run_id'],[]).append(row)
        bank_checks=diagnostic_checks=0
        for engine in K.load(directory/'readers.json'):
            rec=K.A.read(directory/'runs'/engine['file']);rows=by_id[rec.header['run_id']]
            K.P.audit_style_stream(rec,rows)
            examples=[('score seal',lambda r,s:r.seal['outcome']['style'].update(score=-1)),
                ('missing actual live sample',lambda r,s:s.pop()),
                ('unknown capture',lambda r,s:r.events.append({'q':len(r.events),'s':'capture','k':'unknown','t':0,'d':{}}))]
            if any(e['k']=='style' for e in rec.events):
                examples.append(('missing live scored event',lambda r,s:next(row for row in s if row['style_events']).update(style_events=[])))
            if any(e['k']=='style' and e['d']['v']==2 for e in rec.events):
                bank_checks+=1
                def bank(r):return next(e['d'] for e in r.events if e['k']=='style' and e['d']['v']==2)
                examples.extend([('bank speed',lambda r,s:bank(r)['m'].update(end_ups=9999.)),
                    ('bank points',lambda r,s:bank(r).update(points=1)),('bank label',lambda r,s:bank(r).update(label='Speed'))])
            if any(e['k']=='direction' for e in rec.events):
                diagnostic_checks+=1
                examples.extend([('diagnostic non-scored',lambda r,s:next(e['d'] for e in r.events if e['k']=='direction').update(points=1)),
                    ('diagnostic serial',lambda r,s:next(e['d'] for e in r.events if e['k']=='direction').update(serial=999))])
            for name,edit in examples:
                r,s=copy.deepcopy((rec,rows));edit(r,s)
                rejects(engine['file']+'/'+name,lambda r=r,s=s:K.P.audit_style_stream(r,s))
        return {'ok':all(c['refused'] for c in checks),'checks':checks,'seed_sha256':K.sha(record_path),
            'actual_bank_recordings_challenged':bank_checks,'actual_diagnostic_recordings_challenged':diagnostic_checks,
            'scope':'only actually present banks/diagnostics are challenged; synthetic coverage is separate'}
    finally:
        shutil.rmtree(scratch)
