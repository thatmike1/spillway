#!/usr/bin/env python3
"""non-engine refusal tests for the independent tether source audit."""
import importlib.util
import json
from pathlib import Path
import tempfile

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('auditor',PROJECT/'tests/r21_tether_audit.py')
audit=importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
run=Path('/tmp/r21-tether-proof')
routes=json.loads((run/'component-routes.json').read_text())
passed=[]
# a component adapter cannot pass production acceptance, even when all physical results are green.
try:
    audit.route_audit(run,routes,production=True)
except AssertionError:
    passed.append('component proof refused as production proof')
else:
    raise AssertionError('synthetic production claim accepted')
# no source fixture, recording or trace is edited: construct one bounded hostile summary outside proof.
with tempfile.TemporaryDirectory(prefix='r21-tether-audit-control-',dir='/tmp') as folder:
    root=Path(folder)
    original=json.loads((Path(routes['classic'])/'summary.json').read_text())
    for key,value in [('pass',False),('respawns',1),('actual_v_mismatches',1),('rate_mismatch_ticks',1)]:
        mutated=dict(original);mutated[key]=value
        (root/'summary.json').write_text(json.dumps(mutated))
        mapping=dict(routes);mapping['classic']=str(root)
        try:
            audit.route_audit(run,mapping)
        except AssertionError:
            passed.append('refused '+key)
        else:
            raise AssertionError('invalid route accepted: '+key)
print(json.dumps({'ok':True,'checks':passed}))
# every model must have its own finder and a distinct, recording-derived open-loop replay.
production=json.loads((run/'production-routes.json').read_text())
audit.route_audit(run,production,production=True)
for label,mapping in [('same execution',dict(production,classic_replay=production['classic'])),
                      ('wrong model',dict(production,classic=production['elastic'],classic_replay=production['elastic_replay'],elastic=production['classic'],elastic_replay=production['classic_replay']))]:
    try:
        audit.route_audit(run,mapping,production=True)
    except AssertionError:
        passed.append('refused '+label)
    else:
        raise AssertionError('substituted model/replay accepted: '+label)
original_read=audit.read
reader=audit.load_reader()
columns={name:[0] for name in reader.COLUMN_NAMES}
for name in ['p_x','yaw']:
    positive=dict(columns);positive[name]=[0.0]
    negative=dict(columns);negative[name]=[-0.0]
    assert audit.binary_columns(reader,positive)!=audit.binary_columns(reader,negative)
    passed.append('binary sign preserved '+name)
inputs={name:[0] for name,_,_ in reader.INPUT_LAYOUT}
opposite=dict(inputs);opposite['x']=[-0.0]
assert audit.binary_columns(reader,inputs,True)!=audit.binary_columns(reader,opposite,True)
passed.append('binary raw input sign preserved')
for label in ['non-replay execution','wrong raw tape','wrong replay argument']:
    def hostile_read(path):
        value=original_read(path)
        path=Path(path)
        if label=='non-replay execution' and path==Path(production['classic_replay'])/'summary.json':
            value['mode']='coordinate-aware input only'
        elif label=='wrong raw tape' and path==run/'classic-production-recorded.tape.json':
            value['events']=value['events'][:-1]
        elif label=='wrong replay argument' and path==run/(Path(production['classic_replay']).name+'.receipt.json'):
            value['argv']=[arg if not arg.startswith('--tape=') else '--tape='+str(run/'elastic-production-recorded.tape.json') for arg in value['argv']]
        return value
    audit.read=hostile_read
    try:
        audit.route_audit(run,production,production=True)
    except AssertionError:
        passed.append('refused '+label)
    else:
        raise AssertionError('bad replay accepted: '+label)
    finally:
        audit.read=original_read
print(json.dumps({'ok':True,'all_checks':passed}))
