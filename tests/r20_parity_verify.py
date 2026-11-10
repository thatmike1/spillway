#!/usr/bin/env python3
"""run all post-capture audits under the same scratch and HOME bounds."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r20_verify_checker',PROJECT/'tools/check-r20-parity.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    args = parser.parse_args()
    folder = args.folder.resolve()
    assert folder == C.SCRATCH
    report = json.loads((folder/'REPORT.json').read_text())
    assert report['ok'] and report['cleanup']['source_import_profile_removed']
    logs = folder/'verification-logs'
    logs.mkdir()
    assert not (folder/'negative-controls').exists(), 'existing mutation output requires inspection'
    env = {**os.environ,'PYTHONDONTWRITEBYTECODE':'1'}
    stages = []
    steps = [
        ('transport',['tests/r20_parity_canonicalize.py',str(folder)]),
        ('audit',['tests/r20_parity_audit.py',str(folder)]),
        ('mutations',['tests/r20_parity_mutations.py',str(folder),'--out',str(folder/'negative-controls')]),
        ('provenance',['tests/r20_parity_provenance.py',str(folder)]),
    ]
    for name,arguments in steps:
        result = C.bounded([sys.executable,'-B',*arguments],env,PROJECT,logs/(name+'.log'),folder,timeout=600)
        # this process is Python; the driver uses the same resource monitor as engine execution.
        result['python_rss_peak_bytes'] = result.pop('engine_rss_peak_bytes')
        result['python_anonymous_peak_bytes'] = result.pop('engine_anonymous_peak_bytes')
        result['stage'] = name
        stages.append(result)
        C.write(folder/'VERIFICATION-STAGES.json',{'ok':all(r['exit']==0 for r in stages),'stages':stages,
                'script_sha256':C.sha(Path(__file__)),'r20_final_gate':'pending'})
        print(json.dumps({'stage':name,'exit':result['exit'],'owned_scratch_peak_bytes':result['owned_scratch_peak_bytes']}),flush=True)
        assert result['exit'] == 0, ('verification failed; inspect same retained state before restarting',name)
    C.write(folder/'MANIFEST.json',{str(p.relative_to(folder)):C.sha(p) for p in sorted(folder.rglob('*'))
                                  if p.is_file() and p != folder/'MANIFEST.json'})
    print(json.dumps({'ok':True,'r20_final_gate':'pending','manifest_sha256':C.sha(folder/'MANIFEST.json')}),flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
