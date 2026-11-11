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
