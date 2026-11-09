#!/usr/bin/env python3
"""independent retained-evidence audit and comparator mutation tests.

python3 tests/r19_parity_audit.py --self-test
python3 tests/r19_parity_audit.py /tmp/r19-parity-baseline
"""
import argparse
import copy
import gzip
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
import importlib.util
spec = importlib.util.spec_from_file_location('r19_checker', PROJECT/'tools/check-r19-parity.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


def self_test():
    checks = []
    def check(ok, name):
        checks.append({'ok':bool(ok),'name':name})
    row = {'p':[1.0,2.0,3.0],'v':[4.0,5.0,6.0],'yaw':.25,'pitch':.5,'ducked':False,'grounded':False,
           'motion':{'mode':'air','duck':{'height':1.3}},'stats':{'hops':2},'held':{'jump':True},'input':[{'type':'key','pressed':True}],
           'elapsed':1.0,'checkpoint':1,'physics_hz':128,'physics':{'hull':{'height':1.3}},
           'identity':{'format':'motion-1','map':'breakwater','geometry':'geometry-1','preset':'server128','motor':'source-1','course_key':'time-1'},
           'style':{'score':42},'live_hull':{'box_size_m':[.7,1.3,.7]},'view':{'fov':100.0,'yaw':.25}}
    mutations = {
        'one ULP position':lambda x:x['p'].__setitem__(0,math.nextafter(x['p'][0],math.inf)),
        'velocity':lambda x:x['v'].__setitem__(0,x['v'][0]+1e-6),
        'yaw':lambda x:x.__setitem__('yaw',math.nextafter(x['yaw'],math.inf)),
        'pitch':lambda x:x.__setitem__('pitch',math.nextafter(x['pitch'],math.inf)),
        'duck':lambda x:x.__setitem__('ducked',True),
        'motor':lambda x:x['motion'].__setitem__('mode','ground'),
        'stats':lambda x:x['stats'].__setitem__('hops',3),
        'held input':lambda x:x['held'].__setitem__('jump',False),
        'input delivery':lambda x:x['input'].append({'type':'key','pressed':False}),
        'elapsed':lambda x:x.__setitem__('elapsed',math.nextafter(x['elapsed'],math.inf)),
        'progress':lambda x:x.__setitem__('checkpoint',2),
        'physics rate':lambda x:x.__setitem__('physics_hz',64),
        'hull':lambda x:x['physics']['hull'].__setitem__('height',1.31),
        'actual collision box':lambda x:x['live_hull']['box_size_m'].__setitem__(1,1.31),
        'actual camera FOV':lambda x:x['view'].__setitem__('fov',101.0),
        'unknown identity':lambda x:x['identity'].__setitem__('look','unexpected'),
    }
    for field in row['identity']:
        mutations['identity '+field] = lambda x,k=field:x['identity'].__setitem__(k,'different')
    for name,mutate in mutations.items():
        other = copy.deepcopy(row)
        mutate(other)
        check(C.difference(C.physical(row),C.physical(other)) is not None,'reject '+name)
    other = copy.deepcopy(row)
    other['style']['score'] += 1
    check(C.difference(C.physical(row),C.physical(other)) is None and C.difference(row['style'],other['style']) is not None,
          'score is reported separately from motion')
    e = {'kind':'speed','tick':123,'points':100,'base':100,'mult':1.0,'geo':{'face':'west'},'m':{'mean_ups':400}}
    old = {'events':[{'d':e}]}
    new = copy.deepcopy(old)
    new['events'][0]['d'].update(direction_mult=1.0,combo_mult=1.0)
    check(C.detector_comparison(old,new)['ok'],'forward detector accepts explicit neutral directional multiplier')
    for name,mutate in [('geometry',lambda x:x['events'][0]['d']['geo'].__setitem__('face','east')),
                        ('tick',lambda x:x['events'][0]['d'].__setitem__('tick',124)),
                        ('base',lambda x:x['events'][0]['d'].__setitem__('base',101)),
                        ('forward points',lambda x:x['events'][0]['d'].__setitem__('points',101)),
                        ('unknown event schema',lambda x:x['events'][0]['d'].__setitem__('arbitrary',1)),
                        ('missing detector',lambda x:x.__setitem__('events',[]))]:
        bad = copy.deepcopy(new)
        mutate(bad)
        check(not C.detector_comparison(old,bad)['ok'],'reject changed existing detector '+name)
    directional = copy.deepcopy(new)
    directional['events'][0]['d'].update(direction_mult=2.0,mult=2.0,points=200)
    check(C.detector_comparison(old,directional)['ok'] and len(C.detector_comparison(old,directional)['directional_point_changes']) == 1,
          'directional points remain a separately reported change')
    unknown = copy.deepcopy(new)
    unknown['events'].append({'d':{**e,'kind':'invented_award'}})
    check(not C.detector_comparison(old,unknown)['ok'],'unknown award kind fails')
    for literal,want in [('0.0009599310885968812',0.00095993108859688),
                         ('0.0011609162902459502',0.00116091629024595),
                         ('249.99998474121094',249.99998474121097),('128',128.0),('-0.0',-0.0)]:
        check(C.godot_number(literal) == want,'exact Godot JSON numeric reference '+literal)
    check(C.reader_difference({'n':128},{'n':128.0}) is None,'JSON int/double parser tags normalize without changing value')
    check(C.reader_difference({'n':128},{'n':128.00000000000003}) is not None,'JSON decoded numeric ULP still fails without tolerance')
    # a complete representative header keeps the actual 13-entry identity order.
    identities = {}
    for side,geometry,overlay,key in [('baseline','old-geometry','r16-opportunities-1:old','old-key'),('candidate','new-geometry','r19-breakwater-flow-1:new','new-key')]:
        identity = {'format':'r16-motion-1','map':'breakwater','preset':'server128','course_key':key,'geometry':geometry,'overlay':overlay,
                    'physics_hz':128,'motor':'r15-source-crouch-2','runner':'res://scripts/r15_source_player.gd','timing':'r16-timing-1'}
        ordered = ['r16-timing-1',['breakwater','course','r15-breakwater',1,0],geometry,['Stage one','Stage two'],'server128','source',
                   identity['motor'],identity['runner'],128,'{"air_accelerate":100}','{"height":1.3}','{}',overlay]
        opp = {'version':'r16-opportunities-1' if side=='baseline' else 'r19-breakwater-flow-1','applied':True,
               'reason':'original' if side=='baseline' else 'widen_optional_thread_after_repeated_front_contacts',
               'hash':side+'-hash','base_geometry':geometry,'passages':['RunwayThread']}
        identities[side] = {'identity':identity,'record_identity':ordered,'course_key':key,'map':'breakwater','map_kind':'course','overlay':overlay,
                            'preset':'server128','family':'source','opportunities':opp,'look':{'fov':100.0},'physics':{'hull':{'height':1.3},'fingerprint':{'air_accelerate':100},'mechanics':{}}}
    revision = {'presets':{s:{'server128':{'metadata':m}} for s,m in identities.items()}}
    revisions = {'breakwater':revision}
    def fixture(side):
        return {'header':{'format':'recording-1','metadata':copy.deepcopy(identities[side]),'identity':copy.deepcopy(identities[side]['identity'])},
                'columns':{'tick':[0,1],'p_x':[1.,2.],'elapsed':[0.,1.]},'inputs':{'tick':[0,0],'code':[87,32]},
                'events':[],'seal':{'outcome':{'kind':'finish','style':{}},'counts':{'bytes':10,'events':0}}}
    baseline,candidate = fixture('baseline'),fixture('candidate')
    check(C.geometry_record_guard(baseline,candidate,revisions)['ok'],'exact targeted revision normalizes complete recording')
    changes = {
        'map identity':lambda x:x['header']['metadata']['record_identity'][1].__setitem__(0,'other-map'),
        'level version':lambda x:x['header']['metadata']['record_identity'][1].__setitem__(3,2),
        'level variant':lambda x:x['header']['metadata']['record_identity'][1].__setitem__(4,1),
        'stage titles':lambda x:x['header']['metadata']['record_identity'][3].__setitem__(0,'renamed'),
        'overlay outside revision':lambda x:x['header']['metadata'].__setitem__('overlay','r19-breakwater-flow-2:other'),
        'opportunity passages':lambda x:x['header']['metadata']['opportunities']['passages'].append('new gate'),
        'opportunity applied':lambda x:x['header']['metadata']['opportunities'].__setitem__('applied',False),
        'opportunity unknown key':lambda x:x['header']['metadata']['opportunities'].__setitem__('unknown',1),
        'unknown metadata':lambda x:x['header']['metadata'].__setitem__('unknown',1),
        'hull':lambda x:x['header']['metadata']['physics']['hull'].__setitem__('height',1.31),
        'F2 laws':lambda x:x['header']['metadata']['physics']['fingerprint'].__setitem__('air_accelerate',101),
        'preset':lambda x:x['header']['metadata'].__setitem__('preset','server128_aa1000'),
        'timing':lambda x:x['header']['metadata']['record_identity'].__setitem__(0,'r16-timing-2'),
        'FOV':lambda x:x['header']['metadata']['look'].__setitem__('fov',101.),
        'ordered inputs':lambda x:x['inputs']['code'].reverse(),
        'physical position':lambda x:x['columns']['p_x'].__setitem__(0,math.nextafter(1.,math.inf)),
        'record identity schema':lambda x:x['header']['metadata']['record_identity'].append('unknown'),
        'record format':lambda x:x['header'].__setitem__('format','recording-2'),
    }
    for name,mutate in changes.items():
        bad=copy.deepcopy(candidate);mutate(bad)
        check(not C.geometry_record_guard(baseline,bad,revisions)['ok'],'revision guard rejects '+name)
    # lifecycle records on Movement Lab keep every identity field strict.
    lab_a=fixture('baseline');lab_a['header']['metadata']['map']='experiment'
    lab_a['header']['identity']['map']=lab_a['header']['metadata']['identity']['map']='experiment'
    lab_b=copy.deepcopy(lab_a)
    check(C.geometry_record_guard(lab_a,lab_b,revisions)['ok'],'unrevised lifecycle map stays exact')
    lab_b['header']['metadata']['record_identity'][2]='changed-lab-geometry'
    check(not C.geometry_record_guard(lab_a,lab_b,revisions)['ok'],'unrevised lifecycle geometry cannot normalize')
    # the hash is checked against actual captured Godot identity text, independently of revision normalization.
    header=copy.deepcopy(baseline['header']);meta=header['metadata']
    text=json.dumps(meta['record_identity']);key=hashlib.sha256(text.encode()).hexdigest()[:16]
    header['identity']['course_key']=meta['identity']['course_key']=meta['course_key']=key
    C.validate_record_identity(header,text)
    for name,mutate in [('course key hash',lambda x:x['identity'].__setitem__('course_key','bad-key')),
                        ('ordered map',lambda x:x['metadata']['record_identity'][1].__setitem__(0,'other')),
                        ('own header relation',lambda x:x['identity'].__setitem__('overlay','other'))]:
        bad=copy.deepcopy(header);mutate(bad)
        try:C.validate_record_identity(bad,text);rejected=False
        except (AssertionError,KeyError):rejected=True
        check(rejected,'identity binding rejects '+name)
    f5_a,f5_b=copy.deepcopy(baseline),copy.deepcopy(candidate)
    f5_revision=copy.deepcopy(revisions)
    for side,value in [('baseline',f5_a),('candidate',f5_b)]:
        meta=value['header']['metadata']
        meta['preset']=meta['record_identity'][4]='server128_aa1000'
        meta['physics']['fingerprint']['air_accelerate']=1000
        meta['record_identity'][9]='{"air_accelerate":1000}'
        for identity in [meta['identity'],value['header']['identity']]:
            identity['preset']='server128_aa1000';identity['course_key']=side+'-f5-key'
        meta['course_key']=side+'-f5-key'
        f5_revision['breakwater']['presets'][side]['server128_aa1000']={'metadata':copy.deepcopy(meta)}
    check(C.geometry_record_guard(f5_a,f5_b,f5_revision)['ok'],'F5 lifecycle uses its own revision key and preserves its laws')
    with tempfile.TemporaryDirectory(prefix='r19-guard-mutations-') as directory:
        directory=Path(directory)
        old_row=copy.deepcopy(row);new_row=copy.deepcopy(row)
        old_row['identity']=copy.deepcopy(identities['baseline']['identity']);old_row['course_key']=old_row['identity']['course_key']
        new_row['identity']=copy.deepcopy(identities['candidate']['identity']);new_row['course_key']=new_row['identity']['course_key']
        def trace(path,value):
            with gzip.open(path,'wt') as target:target.write(json.dumps(value)+'\n')
        trace(directory/'old.gz',old_row);trace(directory/'new.gz',new_row)
        check(C.geometry_guard(directory/'old.gz',directory/'new.gz',revisions)['ok'],'off-line trace normalizes only exact identity')
        for name,mutate in {**mutations,'unknown physical field':lambda x:x.__setitem__('unknown',1),
                            'ordered inputs':lambda x:x['input'].append({'type':'mouse','x':1})}.items():
            bad=copy.deepcopy(new_row);mutate(bad);trace(directory/'bad.gz',bad)
            check(not C.geometry_guard(directory/'old.gz',directory/'bad.gz',revisions)['ok'],'off-line revision trace rejects '+name)
    return {'ok':all(c['ok'] for c in checks),'checks':checks}


def audit(folder):
    report = json.loads((folder/'REPORT.json').read_text())
    manifest = json.loads((folder/('source-r18.json' if report['mode']=='baseline-only' else 'source-candidate.json')).read_text())
    checks = self_test()['checks']
    def check(ok, name, detail=None):
        checks.append({'ok':bool(ok),'name':name,'detail':detail})
    check(report['ok'],'driver completed requested routes')
    check(report['baseline_commit'] == C.BASE,'baseline is exact delivered R18 commit')
    check(len(report['routes']) == 16,'all 16 retained routes executed')
    check({r['map'] for r in report['routes']} == {'breakwater','whiteout-relay','sunken-court','rainline','night-shift','practice','overflow','experiment'},
          'all eight retained maps executed')
    check(report['cleanup']['source_import_profile_removed'],'own source/import/profile cleaned')
    check(report['source_postflight']['ok'],'executed source unchanged through matrix')
    for name,digest in report['verification_source_sha256'].items():
        check(C.sha(PROJECT/name) == digest,'executed helper still matches '+name)
    if report['mode'] == 'baseline-only':
        check(manifest['commit'] == C.BASE and manifest['archive']['parent_pinned_files_verified'] == 346,'all 346 parent-pinned R18 sources match Git archive')
        check(report['r19_final_gate'] == 'pending','baseline does not claim final R19 acceptance')
    revisions = report.get('map_revisions',{})
    for revision in revisions.values():
        C.validate_revision(revision)
    if report['mode'] == 'candidate':
        check(C.runtime_freeze_guard(manifest)['ok'],'all frozen runtime files exact with verification-only intervening diff')
        baseline = Path(report['baseline_dir'])
        base_report = json.loads((baseline/'REPORT.json').read_text())
        check(base_report['ok'] and base_report['verification_source_sha256'] == report['verification_source_sha256'],'fresh complete baseline used identical final helpers')
        old_source = json.loads((baseline/'source-r18.json').read_text())
        proof = C.validate_style_fixture(report['scoring_contract'],old_source['executed_files']['scripts/r16_style.gd'],manifest['executed_files']['scripts/r16_style.gd'])
        check(proof['ok'],'style contract binds actual fixture coverage and exact source hashes')
    reader = C.module(PROJECT/'tools/analyze-r16-runs.py','r19_audit_reader')
    check(C.sha(PROJECT/'tools/analyze-r16-runs.py') == report['executed_python_sha256']['tools/analyze-r16-runs.py'],
          'audit independent reader has the executed reader hash')
    metrics = []
    for listed in report['routes']:
        route_dir = folder/listed['name']
        result = json.loads((route_dir/'result.json').read_text())
        route = result['route']
        plan = json.loads((route_dir/'expanded.json').read_text())
        check(C.sha(route_dir/'expanded.json') == result['expanded_sha256'],'expanded tape hash '+route['name'])
        check(C.sha(Path(route['tape'])) == result['tape_sha256'],'retained tape still exact '+route['name'])
        route_metrics = {'name':route['name'],'ticks':result['expected_ticks'],'recordings':0,'input_rows':0,'observed_ticks':0,'style_events':0,
                         'airborne_duck_ticks':0,'lab_counts':{},'lab_events':[]}
        for variant,run in result['runs'].items():
            run_dir = route_dir/variant
            check(run['ok'] and run['exit'] == 0 and not run['engine_errors'],'successful actual host '+route['name']+'/'+variant)
            summary = json.loads((run_dir/'summary.json').read_text())
            check(summary == run['summary'],'retained summary agrees with driver '+route['name']+'/'+variant)
            check(all(c['ok'] for c in summary['checks']),'all adapter checks '+route['name']+'/'+variant)
            check(summary['finish']['finished'] and summary['finish']['finish_kind'] == 'clean' and summary['finish']['respawns'] == 0,
                  'earned clean finish '+route['name']+'/'+variant)
            check(summary['finish']['last_tick']+1 == result['expected_ticks'],'full route duration '+route['name']+'/'+variant)
            if report['mode'] == 'baseline-only':
                check(summary['host_scene'] == 'res://scenes/r17.tscn' and summary['host_script'] == 'res://scripts/r17_main.gd',
                      'delivered R18 configured host '+route['name']+'/'+variant)
            observed,records = C.observation_audit(run_dir,reader)
            check(observed['ok'],'independent recording/observation audit '+route['name']+'/'+variant,observed)
            for k, source in [('recordings','recordings'),('input_rows','inputs'),('observed_ticks','ticks'),('style_events','style_events')]:
                route_metrics[k] += observed[source]
            path = Path(summary['finish']['record_path'])
            rec,_ = C.OLD.recording(path,reader)
            check(C.sha(path) == run['recording']['sha256'],'actual recording bytes '+route['name']+'/'+variant)
            ordered = C.ordered_tape_audit(rec,plan,route['warmup'])
            check(ordered['ok'],'ordered earned input tape '+route['name']+'/'+variant,ordered)
            kinds = {r['seal']['outcome']['kind'] for r in records}
            check({'finish','restart','practice','preset','map','quit'} <= kinds,'all lifecycle attempt endings '+route['name']+'/'+variant,sorted(kinds))
            all_events = {e['k'] for r in records for e in r['events']}
            check({'pause','resume','ghost'} <= all_events,'pause/resume and ghost events '+route['name']+'/'+variant,sorted(all_events))
            if variant == ('r18' if report['mode']=='baseline-only' else 'new'):
                for row in C.stream(run_dir/'evaluator/trace.jsonl.gz'):
                    route_metrics['airborne_duck_ticks'] += int(row['ducked'] and not row['grounded'])
                    experiment = row['motion'].get('experiment',{})
                    for key,value in experiment.get('counts',{}).items():
                        route_metrics['lab_counts'][key] = max(route_metrics['lab_counts'].get(key,0),value)
                    for kind in experiment.get('events',[]):
                        if kind in ['slide_landing','wall_jump','grapple']:
                            route_metrics['lab_events'].append({'kind':kind,'tick':row['tick'],'held':row['held']})
                    if 'jump' in row['motion'].get('events',[]):
                        route_metrics['lab_events'].append({'kind':'hop','tick':row['tick'],'held':row['held']})
        if report['mode'] == 'candidate':
            prior_dir = baseline/route['name']
            prior = json.loads((prior_dir/'result.json').read_text())
            _,old_records = C.observation_audit(prior_dir/'r18',reader)
            check(set(result['runs']) == {'old','new','toggle'},'all three candidate variants '+route['name'])
            for variant,run in result['runs'].items():
                run_dir=route_dir/variant
                _,records=C.observation_audit(run_dir,reader)
                motion=C.geometry_guard(prior_dir/'r18-ghost/evaluator/trace.jsonl.gz',run_dir/'evaluator/trace.jsonl.gz',revisions)
                check(motion['ok'],'independent exact physical/view/input parity '+route['name']+'/'+variant,motion)
                guards=[C.geometry_record_guard(a,b,revisions) for a,b in zip(old_records,records)]
                check(len(old_records)==len(records) and all(g['ok'] for g in guards),'independent complete recording parity '+route['name']+'/'+variant,guards)
                detectors=[C.detector_comparison(C.record_compare_view(a)[1],C.record_compare_view(b)[1]) for a,b in zip(old_records,records)]
                check(all(g['ok'] for g in detectors),'independent existing detector parity '+route['name']+'/'+variant,detectors)
                controls=[]
                for side,summary in [('baseline',prior['runs']['r18-ghost']['summary']),('candidate',run['summary'])]:
                    controls.append([{**r,'game':C.physical(C.revision_state(r['game'],revisions,side))} for r in summary['tour']])
                check(C.difference(*controls) is None,'independent complete lifecycle controls '+route['name']+'/'+variant)
                check(C.difference(prior['runs']['r18-ghost']['summary']['finish']['ghost_probes'],run['summary']['finish']['ghost_probes']) is None,'independent exact ghost pose probes '+route['name']+'/'+variant)
                if route['map'] in revisions and variant == 'old':
                    refused=[c for c in run['summary']['checks'] if c['name'].startswith('old')]
                    check(len(refused)==2 and all(c['ok'] for c in refused),'explicit old revision ghost refusal '+route['name'])
                else:
                    ghost=C.OLD.compare_traces(prior_dir/'r18-ghost/evaluator/ghost.jsonl.gz',run_dir/'evaluator/ghost.jsonl.gz')
                    check(ghost['ok'],'independent every-tick live ghost poses '+route['name']+'/'+variant,ghost)
        else:
            check(set(result['runs']) == {'r18','r18-ghost'},'both baseline plays '+route['name'])
        check(result['ok'] and all(c['ok'] or c.get('informational',False) for v in result['comparisons'].values() for c in v.values()),'driver comparison results '+route['name'])
        if route['name'] == 'r16-whiteout-apron':
            check(route_metrics['airborne_duck_ticks'] > 0,'whiteout route includes actual airborne crouch')
        if route['name'] == 'r16-lab-flow':
            counts = route_metrics['lab_counts']
            check(counts.get('wall_jump',0)>=2 and counts.get('slide_landing',0)>=1 and counts.get('grapple',0)>=1,
                  'actual lab slide, two wall jumps and grapple',counts)
            jumps = [e for e in route_metrics['lab_events'] if e['kind']=='wall_jump']
            check(len(jumps)>=2 and all((e['held'].get('move_left') or e['held'].get('move_right')) and not e['held'].get('move_forward') for e in jumps),
                  'actual wall jumps with A/D held and W released',jumps)
            chain = [e['kind'] for e in route_metrics['lab_events']]
            check('slide_landing' in chain and 'wall_jump' in chain and 'hop' in chain[chain.index('slide_landing')+1:chain.index('wall_jump')]
                  and 'grapple' in chain and chain.index('slide_landing')<chain.index('wall_jump')<chain.index('grapple'),
                  'earned slide to fresh hop to wall jumps to grapple')
        metrics.append(route_metrics)
    output = {'ok':all(c['ok'] for c in checks),'checks':checks,'routes':metrics,
              'totals':{k:sum(r[k] for r in metrics) for k in ['ticks','recordings','input_rows','observed_ticks','style_events']},
              'audit_sha256':C.sha(Path(__file__)), 'r19_final_gate':report['r19_final_gate'],
              'scope':'headless source-only retained evidence; native visual/package/Windows and player enjoyment remain separate'}
    C.write(folder/'AUDIT.json',output)
    print(json.dumps({'ok':output['ok'],'checks':len(checks),'totals':output['totals'],'failures':[c for c in checks if not c['ok']]}))
    return 0 if output['ok'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path,nargs='?')
    parser.add_argument('--self-test',action='store_true')
    args = parser.parse_args()
    if args.self_test:
        result = self_test()
        print(json.dumps(result))
        raise SystemExit(0 if result['ok'] else 1)
    assert args.folder, 'pass an evidence directory or --self-test'
    raise SystemExit(audit(args.folder.resolve()))
