#!/usr/bin/env python3
"""independently audit the complete exact-R19 source baseline, with no R20 acceptance claim."""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r20_checker',PROJECT/'tools/check-r20-parity.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


def self_test():
    # the inherited comparator's adversarial coverage stays in force; geometry normalization is never called here.
    previous = C.module(PROJECT/'tests/r19_parity_audit.py','r20_prior_audit').self_test()
    checks = previous['checks']
    def rejects(call):
        try:
            call()
            return False
        except (AssertionError,KeyError):
            return True
    for field in ['host_scene','host_script']:
        summary = {'host_scene':'res://scenes/r19.tscn','host_script':'res://scripts/r19_main.gd','checks':[{'ok':True}]}
        summary[field] = 'wrong'
        checks.append({'ok':rejects(lambda:C.host_guard(summary)),'name':'reject wrong configured '+field})
    return {'ok':all(c['ok'] for c in checks),'checks':checks}


def audit(folder):
    report = json.loads((folder/'REPORT.json').read_text())
    manifest = json.loads((folder/'source-r19.json').read_text())
    checks = self_test()['checks']
    def check(ok,name,detail=None):
        checks.append({'ok':bool(ok),'name':name,'detail':detail})
    check(report['ok'],'driver completed all sixteen routes')
    check(report['baseline_commit'] == C.BASE,'exact requested R19 baseline')
    check(C.source_guard(manifest),'exact archive and only trusted adapter injected')
    check(len(report['routes']) == 16 and len(set(r['name'] for r in report['routes'])) == 16,'all sixteen unique routes')
    check({r['map'] for r in report['routes']} == {'breakwater','whiteout-relay','sunken-court','rainline','night-shift','practice','overflow','experiment'},'all eight original maps')
    check(report['r20_final_gate'] == 'pending','final R20 matrix remains pending')
    check(report['cleanup']['source_import_profile_removed'] and report['source_postflight']['ok'],'sources unchanged and own source/import/profile cleaned')
    for name,digest in report['verification_source_sha256'].items():
        check(C.sha(PROJECT/name) == digest,'executed helper hash '+name)
    for name,digest in report['F2_pins_from_exact_R19'].items():
        check(manifest['archive_files'][name] == digest,'F2 exact R19 pin '+name)
    reader = C.module(PROJECT/'tools/analyze-r16-runs.py','r20_audit_reader')
    metrics = []
    for listed in report['routes']:
        directory = folder/listed['name']
        result = json.loads((directory/'result.json').read_text())
        route = result['route']
        plan = json.loads((directory/'expanded.json').read_text())
        check(C.sha(directory/'expanded.json') == result['expanded_sha256'] and C.sha(Path(route['tape'])) == result['tape_sha256'],'complete tape hashes '+route['name'])
        check(set(result['runs']) == {'r19','r19-ghost'},'both fresh baseline plays '+route['name'])
        totals = dict(name=route['name'],ticks=result['expected_ticks'],recordings=0,input_rows=0,observed_ticks=0,style_events=0,airborne_duck_ticks=0,lab_counts={},lab_events=[])
        decoded = {}
        for variant,run in result['runs'].items():
            run_dir = directory/variant
            C.complete_guard(run,plan)
            summary = json.loads((run_dir/'summary.json').read_text())
            check(summary == run['summary'],'actual summary retained '+route['name']+'/'+variant)
            observed,records = C.observation_audit(run_dir,reader)
            decoded[variant] = records
            check(observed['ok'],'both independent readers and every actual sample '+route['name']+'/'+variant,observed)
            for target,key in [('recordings','recordings'),('input_rows','inputs'),('observed_ticks','ticks'),('style_events','style_events')]:
                totals[target] += observed[key]
            rec,_ = C.OLD.recording(Path(summary['finish']['record_path']),reader)
            check(C.ordered_tape_audit(rec,plan,route['warmup'])['ok'],'ordered full route input '+route['name']+'/'+variant)
            check(C.OLD.recording_alignment(rec,run_dir/'evaluator/trace.jsonl.gz',route['warmup'])['ok'],'recording aligns with physical trace '+route['name']+'/'+variant)
            kinds = {r['seal']['outcome']['kind'] for r in records}
            check({'finish','restart','practice','preset','map','quit'} <= kinds,'all lifecycle endings '+route['name']+'/'+variant,sorted(kinds))
            events = {e['k'] for r in records for e in r['events']}
            check({'pause','resume','ghost'} <= events,'pause resume and ghost lifecycle '+route['name']+'/'+variant)
            check(summary['identity_rejections'] and all(r['ok'] for r in summary['identity_rejections']), 'actual ghost rejects every identity field '+route['name']+'/'+variant)
            for name,receipt in run['trace_compression']['receipts'].items():
                path = run_dir/'evaluator'/(name+'.gz')
                digest = hashlib.sha256()
                length = 0
                with gzip.open(path,'rb') as raw:
                    for block in iter(lambda:raw.read(65536),b''):
                        digest.update(block);length += len(block)
                check(digest.hexdigest() == receipt['raw_sha256'] and length == receipt['raw_bytes'] and C.sha(path) == receipt['gzip_sha256'],'lossless decompressed trace hash '+route['name']+'/'+variant+'/'+name)
            check(run['owned_scratch_peak_bytes'] <= C.CAP and run['minimum_home_free_bytes'] >= C.MIN_FREE,'scratch and HOME limits '+route['name']+'/'+variant)
            if variant == 'r19':
                for row in C.stream(run_dir/'evaluator/trace.jsonl.gz'):
                    totals['airborne_duck_ticks'] += int(row['ducked'] and not row['grounded'])
                    experiment = row['motion'].get('experiment',{})
                    for key,value in experiment.get('counts',{}).items():
                        totals['lab_counts'][key] = max(totals['lab_counts'].get(key,0),value)
                    for kind in experiment.get('events',[]):
                        if kind in ['slide_landing','wall_jump','grapple']:
                            totals['lab_events'].append({'kind':kind,'tick':row['tick'],'held':row['held']})
                    if 'jump' in row['motion'].get('events',[]):
                        totals['lab_events'].append({'kind':'hop','tick':row['tick'],'held':row['held']})
        check(C.compare_traces(directory/'r19/evaluator/trace.jsonl.gz',directory/'r19-ghost/evaluator/trace.jsonl.gz')['ok'],'independent exact repeat motion '+route['name'])
        check(C.difference(decoded['r19'],decoded['r19-ghost']) is None,'independent complete repeat recordings '+route['name'])
        a,b = [result['runs'][v]['summary'] for v in ['r19','r19-ghost']]
        check(C.difference(a['tour'],b['tour']) is None and C.difference(a['finish']['ghost_probes'],b['finish']['ghost_probes']) is None,'independent lifecycle and ghost probes '+route['name'])
        if route['name'] == 'r16-whiteout-apron':
            check(totals['airborne_duck_ticks'] > 0,'actual airborne crouch')
        if route['name'] == 'r16-lab-flow':
            counts = totals['lab_counts']
            check(counts.get('wall_jump',0)>=2 and counts.get('slide_landing',0)>=1 and counts.get('grapple',0)>=1,'actual slide two wall jumps and grapple',counts)
            jumps = [e for e in totals['lab_events'] if e['kind']=='wall_jump']
            check(len(jumps)>=2 and all((e['held'].get('move_left') or e['held'].get('move_right')) and not e['held'].get('move_forward') for e in jumps),'wall jumps with A/D and no W',jumps)
            chain = [e['kind'] for e in totals['lab_events']]
            check('slide_landing' in chain and 'wall_jump' in chain and 'hop' in chain[chain.index('slide_landing')+1:chain.index('wall_jump')] and 'grapple' in chain and chain.index('slide_landing')<chain.index('wall_jump')<chain.index('grapple'),'earned slide hop wall grapple chain')
        metrics.append(totals)
    output = {'ok':all(c['ok'] for c in checks),'checks':checks,'routes':metrics,
              'totals':{k:sum(r[k] for r in metrics) for k in ['ticks','recordings','input_rows','observed_ticks','style_events']},
              'r20_final_gate':'pending','audit_sha256':C.sha(Path(__file__))}
    C.write(folder/'AUDIT.json',output)
    print(json.dumps({'ok':output['ok'],'checks':len(checks),'totals':output['totals'],'failures':[c for c in checks if not c['ok']]}))
    return 0 if output['ok'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path,nargs='?')
    parser.add_argument('--self-test',action='store_true')
    args = parser.parse_args()
    if args.self_test:
        result = self_test(); print(json.dumps(result))
        raise SystemExit(0 if result['ok'] else 1)
    assert args.folder
    raise SystemExit(audit(args.folder.resolve()))
