#!/usr/bin/env python3
"""independent evidence audit and numeric negative controls for check-r17-parity.py.

python3 tests/r17_parity_audit.py /absolute/completed/parity/evidence
Reads retained traces/recordings only. Writes AUDIT.json within that evidence directory.
"""
import copy
import gzip
import hashlib
import importlib.util
import json
import math
import struct
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def lines(path):
    with gzip.open(path, 'rt') as stream:
        yield from (json.loads(line) for line in stream)


def audit(folder):
    checker = load(PROJECT/'tools/check-r17-parity.py', 'parity_checker')
    reader = load(PROJECT/'tools/analyze-r16-runs.py', 'parity_independent_reader')
    report = json.loads((folder/'REPORT.json').read_text())
    checks = []
    def check(ok, name, detail=None):
        checks.append({'ok': bool(ok), 'name': name, 'detail': detail})
    check(report.get('ok'), 'driver completed every requested route')
    check(len(report['routes']) == 16, 'all 16 retained delivery routes completed')
    check({r['map'] for r in report['routes']} == {'breakwater','whiteout-relay','sunken-court','rainline','night-shift','practice','overflow','experiment'},
          'all eight playable maps covered')
    check(report['runtime_preservation']['ok'] and report['runtime_preservation']['files'] == 475, 'all 475 delivered runtime/assets retain exact bytes')
    per_route = []
    for result_path in sorted(folder.glob('*/result.json')):
        result = json.loads(result_path.read_text())
        name = result['route']['name']
        check(result['ok'], name+': driver assertions pass')
        variants = result['runs']
        baseline = variants['r16']['summary']
        negatives = []
        first = next(lines(result_path.parent/'r16/evaluator/trace.jsonl.gz'))
        for label, mutate in [
            ('one ULP position', lambda row: row['p'].__setitem__(0, math.nextafter(row['p'][0], math.inf))),
            ('velocity', lambda row: row['v'].__setitem__(0,row['v'][0]+0.000001)),
            ('progress', lambda row: row.__setitem__('checkpoint',row['checkpoint']+1)),
            ('style', lambda row: row['style'].__setitem__('score',row['style']['score']+1)),
            ('look added to identity', lambda row: row['identity'].__setitem__('look','paint')),
        ]:
            changed = copy.deepcopy(first)
            mutate(changed)
            rejected = checker.difference(first,changed) is not None
            check(rejected, name+': comparator rejects '+label)
            negatives.append({'mutation':label,'rejected':rejected})
        metrics = {'name':name,'map':result['route']['map'],'preset':result['route']['preset'],
                   'ticks':result['expected_ticks'],'max_speed_m_s':baseline['finish']['max_speed_m_s'],
                   'max_actual_horizontal_speed_m_s':0.0,'max_measured_displacement_horizontal_speed_m_s':0.0,
                   'airborne_duck_ticks':0,'lab_counts':{},'lab_events':[],'negative_controls':negatives,
                   'input_rows_checked':{},'complete_recordings_validated':0,'recording_semantics':{}}
        previous=None
        for row in lines(result_path.parent/'r16/evaluator/trace.jsonl.gz'):
            if previous is None or not previous['finished']:
                actual=row['motion'].get('actual_velocity',row['actual_v'])
                metrics['max_actual_horizontal_speed_m_s']=max(metrics['max_actual_horizontal_speed_m_s'],math.hypot(actual[0],actual[2]))
                if previous is not None:
                    shift=row['motion'].get('duck_shift',[0.0,0.0,0.0])
                    displacement=math.hypot(row['p'][0]-previous['p'][0]-shift[0],row['p'][2]-previous['p'][2]-shift[2])/row['dt']
                    metrics['max_measured_displacement_horizontal_speed_m_s']=max(metrics['max_measured_displacement_horizontal_speed_m_s'],displacement)
            previous=row
            metrics['airborne_duck_ticks'] += int(row['ducked'] and not row['grounded'])
            experiment=row['motion'].get('experiment',{})
            if 'jump' in row['motion'].get('events',[]):
                metrics['lab_events'].append({'tick':row['tick'],'kind':'hop','held':row['held']})
            for kind in experiment.get('events',[]):
                if kind in ['slide_landing','wall_jump','grapple']:
                    metrics['lab_events'].append({'tick':row['tick'],'kind':kind,'held':row['held']})
            counts = experiment.get('counts',{})
            for key, value in counts.items():
                metrics['lab_counts'][key] = max(metrics['lab_counts'].get(key,0),value)
        plan = json.loads((result_path.parent/'expanded.json').read_text())
        codes={'w':87,'a':65,'s':83,'d':68,'space':32,'ctrl':4194326,'shift':4194325,'e':69}
        baseline_records = None
        for variant in ['r16','r16-ghost','old','new','toggle']:
            run = variants[variant]
            check(run['ok'] and run['summary']['finish']['last_tick']+1 == result['expected_ticks'],name+'/'+variant+': full tape, no early stop')
            record_path = Path(run['summary']['finish']['record_path'])
            rec, semantics = checker.recording(record_path,reader)
            aligned = checker.recording_alignment(rec,result_path.parent/variant/'evaluator/trace.jsonl.gz',result['route']['warmup'])
            check(aligned['ok'],name+'/'+variant+': every recorded frame/input/view/state matches actual trace',aligned)
            metrics['input_rows_checked'][variant]=aligned['input_rows_checked']
            # compare actual raw input rows against the retained tape independently of the session trace.
            observed={}
            ins=rec.inputs
            for j,tick in enumerate(ins['tick']):
                if ins['kind'][j]==1:
                    observed.setdefault(tick-result['route']['warmup'],[]).append(
                        ('key',ins['aux'][j] or ins['code'][j],bool(ins['flags'][j]&1)))
                elif ins['kind'][j]==3:
                    observed.setdefault(tick-result['route']['warmup'],[]).append(('mouse',ins['x'][j],ins['y'][j]))
            expected={}
            for event in plan['events']:
                tick=event['tick']
                if tick+result['route']['warmup']>=len(rec.columns['tick']):
                    continue
                if 'key' in event:
                    expected.setdefault(tick,[]).append(('key',codes[event['key']],event['edge']=='press'))
                else:
                    values=[struct.unpack('<f',struct.pack('<f',v))[0] for v in event['mouse']]
                    expected.setdefault(tick,[]).append(('mouse',*values))
            # the inherited executor delivers same-tick key edges before its mouse stroke.
            for table in [expected,observed]:
                for tick,events in table.items():
                    table[tick]=sorted(events,key=lambda e: 0 if e[0]=='key' else 1)
            check(expected==observed,name+'/'+variant+': retained complete earned input matches recording through finish')
            check(semantics['header']['identity']==baseline['finish']['identity'],name+'/'+variant+': exact R16 ghost identity')
            check('look' not in semantics['header']['identity'],name+'/'+variant+': presentation absent from ghost identity')
            records=[]
            for path in sorted((result_path.parent/variant/'runs').glob('*.r16run*')):
                observed, canonical = checker.recording(path,reader)
                metrics['complete_recordings_validated']+=1
                if path.name != 'golden.r16run':
                    records.append(canonical)
            # attempt boundaries are compared after sorting on semantic metadata, never filename/run id.
            records.sort(key=lambda r: (r['header']['metadata']['attempt'],r['header']['metadata']['map'],r['header']['metadata']['preset'],
                                        r['header']['metadata']['start_reason'],r['seal']['outcome']['kind'],len(r['columns']['tick'])))
            if baseline_records is None:
                baseline_records=records
            found=checker.difference(baseline_records,records)
            check(found is None,name+'/'+variant+': complete R/G/Escape/F/F5/F2/map/quit recordings retain semantics',found)
            metrics['recording_semantics'][variant]={'files':len(records),'ok':found is None,'difference':found}
        if name=='r16-lab-flow':
            counts=metrics['lab_counts']
            check(counts.get('wall_jump',0)>=2 and counts.get('slide_landing',0)>=1,name+': actual lab slide and two wall jumps recorded',counts)
            jumps=[e for e in metrics['lab_events'] if e['kind']=='wall_jump']
            check(len(jumps)>=2 and all((e['held'].get('move_left') or e['held'].get('move_right')) and not e['held'].get('move_forward') for e in jumps),
                  name+': both wall jumps occur with A/D held and W released',jumps)
            check(counts.get('grapple',0)>=1,name+': grapple actually attached, not merely pressed',counts)
            chain=[e['kind'] for e in metrics['lab_events']]
            if 'slide_landing' in chain and 'wall_jump' in chain:
                check('hop' in chain[chain.index('slide_landing')+1:chain.index('wall_jump')],name+': landing slide exits into a fresh hop before wall jumps',chain)
            check('slide_landing' in chain and chain.count('wall_jump')>=2 and 'grapple' in chain
                  and chain.index('slide_landing')<chain.index('wall_jump')<chain.index('grapple'),
                  name+': earned slide to wall jumps to grapple ordering',chain)
            check(any(e.get('key')=='e' and e.get('edge')=='press' for e in json.loads((result_path.parent/'expanded.json').read_text())['events']),
                  name+': retained earned-input grapple press present')
        if name=='r16-whiteout-apron':
            check(metrics['airborne_duck_ticks']>0,name+': actual airborne crouch recorded')
        per_route.append(metrics)
    output={'ok':all(c['ok'] for c in checks),'checks':checks,'routes':per_route,
            'audit_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'scope':'read-only audit of headless frozen source evidence; no visual, packaged or enjoyment acceptance'}
    (folder/'AUDIT.json').write_text(json.dumps(output,indent=1)+'\n')
    print(json.dumps({'ok':output['ok'],'checks':len(checks),'failures':[c for c in checks if not c['ok']]}))
    return 0 if output['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(audit(Path(sys.argv[1]).resolve()))
