#!/usr/bin/env python3
"""strict contracts and lossless comparisons for the future R20 original-map matrix."""
import copy
import gzip
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import importlib.util


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


B = module('r20_candidate_baseline', PROJECT / 'tools/check-r20-parity.py')
C = B.C
P = module('r20_candidate_package', PROJECT / 'tools/package-r20.py')
A = module('r20_candidate_reader', PROJECT / 'tools/analyze-r16-runs.py')
BASELINE = Path('/tmp/r20-parity-baseline')
PREP = Path('/tmp/r20-candidate-prep')
FINAL = Path('/tmp/r20-candidate-parity')
RECEIPTS = B.OUTER / 'look/evidence/r20-baseline-acceptance'
COMPONENT = B.OUTER / 'look/evidence/r20-style-component/CONTRACT.json'
COMPONENT_SHA = '30d9b5faca12505430f874a6aee7824ea5c42cb14cd517cede936138fdd45105'
BASELINE_MANIFEST_SHA = 'f939eba5f2fbbcb13f6833f3f1067e961795685fbac1c6987dfb6a7bedb7fffb'
RECEIPT_SHA = '109e1f0dc3ef973fec7a94399ec2ce46808991884d1dc07d7d11af1115662b4e'
ARCHIVE_SHA = '13d61f62129e452ea2418552dd56f93ca06b16350fefadeb533793b195331b95'
STYLE_ID = {'event_format': 2, 'rules_sha256': 'b133b80f118247cf944f1c48bbe9f1a65e2b71653adff52d41563904be661688', 'version': 'r20-style-stack-1'}
STYLE_KEY = 'r20-style-stack-1/2/b133b80f118247cf9'
VARIANTS = ('old', 'new', 'toggle')
IDENTITY_KEYS = {'course_key','format','geometry','map','motor','overlay','physics_hz','preset','runner','timing'}
META_KEYS = {'attempt','build','build_label','clean_at_start','course_key','elapsed_at_start','family','held_actions','identity','lab','laws','look','map','map_kind','map_name','opportunities','overlay','paused_at_start','physics','practice_reason','practice_stage','preset','preset_label','record_identity','sample','scoring','start_reason','timer_running_at_start'}
HEADER_KEYS = {'created_unix','created_utc','engine','format','identity','metadata','os','run_id','units','vector_precision','version'}
STYLE_FIELDS = {'v','kind','tick','time_s','elapsed','points','base','mult','direction_mult','combo_mult','combo','label','m','geo','p','clean'}
ORDINARY = {'speed','sync','gap','edge','near_miss','crouch_save'}
DIRECTIONS = {'backward_bhop','sideways_bhop'}


class Refused(ValueError):
    pass


def need(ok, reason):
    if not ok:
        raise Refused(reason)


def exact(a, b, reason):
    found = C.difference(a, b)
    need(found is None, reason + ': ' + repr(found))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode()


def load(path):
    def pairs(items):
        result = {}
        for k,v in items:
            need(k not in result, 'duplicate JSON key: ' + k)
            result[k] = v
        return result
    return json.loads(Path(path).read_text(), object_pairs_hook=pairs,
        parse_constant=lambda value: (_ for _ in ()).throw(Refused('non-finite JSON: ' + value)))


def keys(value, expected, label):
    need(type(value) is dict and set(value) == set(expected), 'unknown/missing ' + label + ' fields')


def sha(path):
    with Path(path).open('rb') as incoming:
        return hashlib.file_digest(incoming, 'sha256').hexdigest()


def checked_json(path, digest):
    need(type(digest) is str and re.fullmatch('[0-9a-f]{64}', digest), 'expected explicit SHA256')
    need(sha(path) == digest, 'reviewed hash mismatch: ' + str(path))
    return load(path)


def helpers():
    # pin every project-local Python dependency actually imported, plus future entry points and GDScript chain.
    import types
    paths = set()
    pending = [B,C,P,A]
    visited = set()
    while pending:
        current = pending.pop()
        if id(current) in visited: continue
        visited.add(id(current))
        file = getattr(current,'__file__',None)
        if not file or not Path(file).resolve().is_relative_to(PROJECT): continue
        paths.add(str(Path(file).resolve().relative_to(PROJECT)))
        pending.extend(v for v in vars(current).values() if isinstance(v,types.ModuleType))
    paths.update(['tools/check-r20-candidate-parity.py', 'tools/r20_candidate_core.py',
        'tests/r20_candidate_parity.gd', 'tests/r20_candidate_reference.gd', 'tests/r20_candidate_r19_style.gd', 'tests/r20_candidate_observations.py',
        'tests/r20_candidate_check.py', 'tests/r20_candidate_mutations.py',
        'tests/r19_parity.gd', 'tests/r17_parity.gd', 'tools/momentum-tape.gd',
        'tests/r20_parity.gd', 'tests/r20_parity_audit.py', 'tests/r20_parity_mutations.py',
        'tests/r20_parity_canonicalize.py', 'tests/r20_parity_provenance.py', 'tests/r20_parity_verify.py',
        'tests/r19_parity_audit.py'])
    return {p:sha(PROJECT/p) for p in sorted(paths)}


def routes():
    return load(B.OUTER/'delivery/spillway-r16/VERIFICATION.json')['routes']


def baseline_guard(full=True):
    need(BASELINE.is_dir(), 'exact retained raw baseline is required; never substitute old delivery plays')
    checked_json(RECEIPTS/'FILES.json', RECEIPT_SHA)
    archive = checked_json(RECEIPTS/'ARCHIVE.json', ARCHIVE_SHA)
    need(archive['all_members_verified'] is True and archive['remote_sha_verified'] is True,
        'remote archive receipt is not verified')
    manifest = checked_json(BASELINE/'MANIFEST.json', BASELINE_MANIFEST_SHA)
    receipt = load(RECEIPTS/'FILES.json')
    need(receipt['MANIFEST.json']['sha256'] == BASELINE_MANIFEST_SHA, 'baseline archive/member mismatch')
    for name in ['REPORT.json','source-r19.json','AUDIT.json','PROVENANCE.json','TRANSPORT.json','VERIFICATION-STAGES.json']:
        need(sha(BASELINE/name) == receipt[name]['sha256'], 'baseline compact/raw receipt mismatch: '+name)
    if full:
        # only the root manifest excludes itself; nested manifests are ordinary proof files.
        found = {str(p.relative_to(BASELINE)) for p in BASELINE.rglob('*') if p.is_file() and p != BASELINE/'MANIFEST.json'}
        exact(sorted(found), sorted(manifest), 'baseline member inventory')
        for name,digest in manifest.items():
            need(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe baseline member')
            need(sha(BASELINE/name) == digest, 'baseline member changed: '+name)
    report = load(BASELINE/'REPORT.json')
    need(report['ok'] is True and report['baseline_commit'] == B.BASE and report['mode'] == 'baseline-only'
        and report['r20_final_gate'] == 'pending', 'baseline report identity')
    exact(report['requested_routes'], [r['name'] for r in routes()], 'baseline route inventory')
    need(len(report['routes']) == 16 and len({r['map'] for r in report['routes']}) == 8, 'incomplete baseline')
    for name,digest in report['verification_source_sha256'].items():
        need(sha(PROJECT/name) == digest, 'mutable baseline helper: '+name)
    source = load(BASELINE/'source-r19.json')
    B.source_guard(source)
    for name,count in [('AUDIT.json',551),('PROVENANCE.json',169)]:
        proof = load(BASELINE/name)
        need(proof['ok'] is True and len(proof['checks']) == count and all(c['ok'] for c in proof['checks']), 'baseline proof incomplete')
    negative = load(BASELINE/'negative-controls/SUMMARY.json')
    need(negative['ok'] is True and len(negative['checks']) == 56 and all(c['ok'] for c in negative['checks']), 'original negatives missing')
    return {'manifest_sha256':BASELINE_MANIFEST_SHA, 'remote_archive':archive, 'members':len(manifest)}


def identity_policy():
    # derive exact policy only from retained actual headers, not candidate working-tree claims.
    identities = {}
    for route in routes():
        result = load(BASELINE/route['name']/'result.json')
        for variant in ('r19','r19-ghost'):
            for row in load(BASELINE/route['name']/variant/'readers.json'):
                h = row['header']; keys(h,HEADER_KEYS,'baseline header'); keys(h['metadata'],META_KEYS,'baseline metadata')
                identity = h['identity']; keys(identity,IDENTITY_KEYS,'motion identity')
                at = identity['map'] + '/' + identity['preset']
                if at in identities:
                    exact(identities[at], identity, 'inconsistent baseline map/preset identity')
                identities[at] = identity
        need(set(result['runs']) == {'r19','r19-ghost'}, 'baseline plays missing')
    need(set(k.split('/')[0] for k in identities) == set(P.ORIGINAL_MAPS), 'incomplete original-map identities')
    delivered = P.baseline_identity()
    return {'header_fields':sorted(HEADER_KEYS), 'metadata_fields':sorted(META_KEYS),
        'motion_fields':sorted(IDENTITY_KEYS), 'identities':identities,
        'original_identity':{k:delivered[k] for k in ('maps','keys','registry')}}


def freeze_guard(value, commit):
    keys(value, {'schema','runtime_frozen','source_commit','identity_sha256','new_maps','required_maps',
        'experimental_maps','reached_items','intentional_changes'}, 'runtime freeze')
    P.validate_freeze(value, commit)
    exact(value['reached_items'], [1,2,3,4,5,6], 'complete R20 required before final parity')
    return value


def reviewed(value, kind):
    need(value['schema'] == 1 and type(value['schema']) is int and value['kind'] == kind,
        'unsupported contract version/kind')
    need(value['status'] == 'REVIEWED' and type(value['reviewed_by']) is str and bool(value['reviewed_by'].strip()),
        'contract is UNFINALIZED or has no parent review')
    exact(value['baseline_manifest_sha256'], BASELINE_MANIFEST_SHA, 'baseline substitution')


def runtime_files(files):
    return {k:v for k,v in files.items() if k.split('/')[0] in
        ('assets','scripts','shaders','scenes','project.godot','export_presets.cfg')}


def contracts(freeze, scoring, identity, commit, observed_identity, files):
    freeze_guard(freeze,commit)
    keys(identity, {'schema','kind','status','reviewed_by','baseline_manifest_sha256','policy'}, 'identity contract')
    reviewed(identity,'r20-original-map-identity')
    exact(identity['policy'], identity_policy(), 'unreviewed or incomplete original-map policy')
    keys(scoring, {'schema','kind','status','reviewed_by','baseline_manifest_sha256','component_sha256',
        'candidate_commit','runtime_sources','verification_helpers','old_metadata','new_metadata'}, 'scoring contract')
    reviewed(scoring,'r20-direction-stack-parity')
    need(scoring['candidate_commit'] == commit, 'scoring review is for a different final host')
    exact(scoring['runtime_sources'], runtime_files(files), 'final runtime source hashes')
    need('scripts/r20_main.gd' in scoring['runtime_sources'] and 'scenes/r20.tscn' in scoring['runtime_sources'], 'missing final host freeze')
    exact(scoring['verification_helpers'], helpers(), 'mutable verification helper')
    for path,digest in scoring['verification_helpers'].items():
        need(files.get(path) == digest, 'executed helper differs from committed final source: '+path)
    component = checked_json(COMPONENT,COMPONENT_SHA)
    exact(scoring['component_sha256'], COMPONENT_SHA, 'unreviewed style component')
    exact(component['identity'], STYLE_ID, 'accepted style version')
    need(files.get('tests/r20_candidate_r19_style.gd') == load(BASELINE/'source-r19.json')['archive_files']['scripts/r16_style.gd'],
        'observational R19 reference is not byte-exact baseline source')
    for name in ('scripts/r16_style.gd','scripts/r16_style_panel.gd','scripts/r18_style_panel.gd'):
        need(files.get(name) == component['source_sha256'][name], 'accepted scoring component changed: '+name)
    first = load(BASELINE/'breakwater-basic/r19/readers.json')[0]
    seed = A.read(BASELINE/'breakwater-basic/r19/runs'/first['file']).header['metadata']
    expected_old = {k:seed[k] for k in ('scoring','build','build_label')}
    exact(scoring['old_metadata'], expected_old, 'old scoring/build labels')
    expected_new = {'build':'spillway-2026.11.10-r20','build_label':'Spillway R20',
        'scoring':{'style':STYLE_ID,'style_key':STYLE_KEY,'timing':'r16-timing-1'}}
    exact(scoring['new_metadata'], expected_new, 'new scoring/build labels')
    P.preservation(commit, B.PREFIX, freeze['intentional_changes'])
    P.identity_boundary(observed_identity,freeze,P.baseline_identity())
    need('run/main_scene="res://scenes/r20.tscn"' in subprocess.check_output(
        ['git','show',commit+':'+B.PREFIX+'project.godot'],cwd=B.REPO,text=True), 'wrong configured scene')
    return True


def all_differences(a,b,path='$'):
    if type(a) is not type(b):
        yield {'path':path,'old':a,'new':b}
    elif isinstance(a,dict):
        for key in sorted(a.keys() | b.keys()):
            if key not in a or key not in b:
                yield {'path':path+'.'+key, 'old_present':key in a,'new_present':key in b,
                    'old':a.get(key),'new':b.get(key)}
            else:
                yield from all_differences(a[key],b[key],path+'.'+key)
    elif isinstance(a,list):
        if len(a) != len(b):
            yield {'path':path,'old':a,'new':b}
        else:
            for i,(x,y) in enumerate(zip(a,b)):
                yield from all_differences(x,y,path+f'[{i}]')
    elif a != b:
        yield {'path':path,'old':a,'new':b}


def compare_rows(old, new, output, separate_style=False):
    mismatches = rows = 0
    for rows,(a,b) in enumerate(itertools.zip_longest(old,new),1):
        if separate_style and a is not None and b is not None:
            for found in all_differences(a.get('style'),b.get('style')):
                output({'row':rows-1,'section':'scoring',**found})
            a,b = C.physical(a),C.physical(b)
        for found in all_differences(a,b):
            output({'row':rows-1,'section':'exact',**found}); mismatches += 1
    return {'ok':mismatches == 0,'rows':rows,'raw_mismatches':mismatches}


def strict_event(value, legacy=False):
    keys(value,STYLE_FIELDS,'scored event')
    if legacy:
        need(value['v'] == 1 and type(value['v']) is int, 'unknown legacy scored schema')
        P.strict_legacy_style(value,value['tick'])
    else:
        P.strict_style(value,value['tick'])


def detector_compare(old, new):
    old_scored = [e['d'] for e in old if e['s']=='capture' and e['k']=='style']
    new_scored = [e['d'] for e in new if e['s']=='capture' and e['k']=='style']
    for v in old_scored: strict_event(v,True)
    for v in new_scored: strict_event(v)
    a = [e for e in old_scored if e['kind'] in ORDINARY]
    b = [e for e in new_scored if e['kind'] in ORDINARY]
    need(len(a) == len(b),'missing or additional ordinary detector')
    changes = []
    for x,y in zip(a,b):
        # only the old direction product and its rounded points may differ.
        want = copy.deepcopy(x)
        want['direction_mult'] = 1.0
        want['mult'] = x['combo_mult']
        # exact unrounded point arithmetic is checked separately against the live R19 reference.
        if x['direction_mult'] != 1:
            want['points'] = y['points']
        exact(want,y,'ordinary detector changed beyond removed direction multiplier')
        if x != y: changes.append({'old':x,'new':y})
    return {'ordinary':len(a), 'removed_immediate':[e for e in old_scored if e['kind'] in DIRECTIONS],
        'new_banks':[e for e in new_scored if e['v']==2],
        'diagnostics':[e for e in new if e['k']=='direction'], 'ordinary_changes':changes}


def record_view(record, scoring, side):
    value = copy.deepcopy(record)
    h = value['header']; keys(h,HEADER_KEYS-{'run_id','created_unix','created_utc'},'canonical header')
    meta = h['metadata']; keys(meta,META_KEYS,'metadata'); keys(h['identity'],IDENTITY_KEYS,'motion identity')
    allowed = {k:meta[k] for k in ('scoring','build','build_label')}
    exact(allowed, scoring[side+'_metadata'], 'explicit '+side+' scoring/build labels')
    for k in allowed: del meta[k]
    separate = {'metadata':allowed,'events':[], 'style':value['seal']['outcome'].pop('style'),
        'storage':{k:value['seal']['counts'].pop(k) for k in ('bytes','events')}}
    events = []
    for e in value['events']:
        keys(e,{'q','s','k','t','d'},'event envelope')
        if e['s']=='capture' and e['k']=='style':
            strict_event(e['d'], side=='old')
            separate['events'].append(e)
        elif e['k']=='direction':
            need(side=='new' and e['s'] in ('capture','event'),'unknown direction event source/version')
            P.strict_direction(e['d'],e['d']['tick'])
            separate['events'].append(e)
        else:
            need(e['s'] != 'capture','unknown capture event')
            events.append(e)
    value['events'] = events
    for i,e in enumerate(events): e['q'] = i
    return value,separate


def _record_compare(old,new,scoring):
    a,sa = record_view(old,scoring,'old'); b,sb = record_view(new,scoring,'new')
    found = list(all_differences(a,b))
    detector = detector_compare(sa['events'],sb['events'])
    return {'ok':not found,'physical_differences':found,'old':sa,'new':sb,'detectors':detector}


def record_compare(old,new,scoring):
    try:
        return _record_compare(old,new,scoring)
    except (Refused,P.Rejected,AssertionError,KeyError,ValueError,TypeError) as exc:
        # retain the complete raw values on schema/detector refusal, not just its first mismatch.
        return {'ok':False,'error':str(exc),'old_raw':old,'new_raw':new}



def observation_view(row):
    # only the new explicitly named scorer observations are separated; unknown data survives comparison.
    row = copy.deepcopy(row)
    row.pop('run_id')
    separate = {k:row.pop(k) for k in ('style_events','style_score','style_time_s','style_direction',
        'style_direction_verdict','ordinary_reference','ordinary_snapshot') if k in row}
    separate['snapshot'] = row['actual'].pop('style')
    return row,separate


def state_view(value):
    result = copy.deepcopy(value)
    style = result.pop('style')
    return result,style


def complete_guard(run, plan, route, variant):
    need(run['ok'] is True and run['exit'] == 0 and not run['engine_errors'], 'unsuccessful candidate engine play')
    summary = run['summary']
    B.host_guard(summary,'res://scenes/r20.tscn','res://scripts/r20_main.gd')
    need(summary['variant'] == variant, 'wrong look variant')
    finish = summary['finish']
    need(finish['last_tick']+1 == plan['duration_ticks'] and finish['finished'] is True
        and finish['finish_kind'] == 'clean' and finish['respawns'] == 0, 'incomplete or unearned route')
    need(finish['map'] == route['map'] and finish['preset'] == route['preset'], 'route substitution')
    keys(finish['identity'],IDENTITY_KEYS,'actual identity')
    expected_identity=load(BASELINE/route['name']/'result.json')['runs']['r19-ghost']['summary']['finish']['identity']
    exact(finish['identity'],expected_identity,'actual original-map motion/version identity')
    rejected = summary['identity_rejections']
    exact(sorted(r['field'] for r in rejected), sorted(IDENTITY_KEYS), 'incomplete identity refusal coverage')
    need(all(r['ok'] is True and bool(r['error']) for r in rejected), 'identity refusal failed')
    need(any(c['name']=='same golden ghost discovered before moving tape' and c['ok'] for c in summary['checks']),
        'baseline golden must load before first movement')
    if variant == 'toggle':
        need(any(t['label']=='paused' for t in summary['toggles']), 'actual paused L missing')
        need(any(t['speed_m_s']>.1 and not t['finished'] for t in summary['toggles']), 'actual moving L missing')


def matrix_guard(report):
    need(report['mode'] == 'candidate' and report['baseline_commit'] == B.BASE, 'wrong matrix mode/baseline')
    exact([(r['name'],r['map'],r['preset']) for r in report['routes']],
        [(r['name'],r['map'],r['preset']) for r in routes()], 'incomplete/reordered/substituted matrix')
    for route in report['routes']:
        exact(route['variants'], list(VARIANTS), 'all three ordered variants required')
    need(sum(len(r['variants']) for r in report['routes']) == 48,'48 fresh candidate plays required')


def transport(source, target, chunk=65536):
    need(not target.exists(),'transport scratch already exists')
    raw = hashlib.sha256(); length = 0
    with gzip.open(source,'rb') as incoming, target.open('wb') as packed:
        with gzip.GzipFile(filename='',mode='wb',fileobj=packed,mtime=0,compresslevel=6) as output:
            for block in iter(lambda:incoming.read(chunk),b''):
                output.write(block); raw.update(block); length += len(block)
                B.gate()
                need(B.allocated_footprint(FINAL) <= B.CAP,'final scratch cap')
    return {'raw_sha256':raw.hexdigest(),'raw_bytes':length,'gzip_sha256':sha(target)}


def style_snapshots(rows):
    fields = {'version','identity_key','score','combo','mult','direction','combo_left_s','combo_window_s',
        'last_combo','recent','last','by_kind','clean','finished','sealed','best_eligible','time_s','context','diag'}
    diag_fields = {'speed','sync','direction','flight','gap','edge','near','crouch','verdicts','farm_blocked','discontinuities','auto_breaks'}
    cumulative=[]; total=0; tally={}
    for row in rows:
        snap=row['actual']['style'];ref=row['ordinary_snapshot']
        keys(snap,fields,'style snapshot');keys(ref,fields,'reference snapshot')
        keys(snap['diag'],diag_fields,'style diagnostics');keys(ref['diag'],diag_fields-{'direction'},'reference diagnostics')
        need(snap['version']==STYLE_ID['version'] and snap['identity_key']==STYLE_KEY,'unknown live scoring identity')
        exact(snap['direction'],row['style_direction'],'direction live observer/snapshot')
        exact(snap['diag']['direction']['last'],row['style_direction_verdict'],'direction verdict observer/snapshot')
        keys(snap['diag']['direction'],{'last','visited_landings','flight'},'direction detector snapshot')
        for event in row['style_events']:
            strict_event(event);cumulative.append(event);total+=event['points']
            value=tally.setdefault(event['kind'],{'n':0,'points':0});value['n']+=1;value['points']+=event['points']
        exact(snap['recent'],cumulative[-6:],'scored recent snapshot')
        exact(snap['last'],cumulative[-1] if cumulative else {},'scored last snapshot')
        exact(snap['by_kind'],tally,'actual live by-kind')
        need(type(snap['score']) is int and snap['score']==total==row['style_score'],'actual live score includes pending or differs')
        for key in fields-{'version','identity_key','score','direction','recent','last','by_kind','diag'}:
            exact(snap[key],ref[key],'ordinary reference snapshot '+key)
        for key in diag_fields-{'direction','farm_blocked'}:
            exact(snap['diag'][key],ref['diag'][key],'ordinary detector live diagnostics '+key)
        for side in (snap,ref):
            count=side['diag']['farm_blocked'].get('direction',0)
            need(type(count) is int and count>=0,'direction anti-farm counter')
        exact({k:v for k,v in snap['diag']['farm_blocked'].items() if k!='direction'},
            {k:v for k,v in ref['diag']['farm_blocked'].items() if k!='direction'},'ordinary anti-farm counters')


def lab_guard(rows):
    counts={};events=[]
    for row in rows:
        experiment=row['motion'].get('experiment',{})
        for key,value in experiment.get('counts',{}).items():counts[key]=max(counts.get(key,0),value)
        for kind in experiment.get('events',[]):
            if kind in ('slide_landing','wall_jump','grapple'):events.append((kind,row['tick'],row['held']))
        if 'jump' in row['motion'].get('events',[]):events.append(('hop',row['tick'],row['held']))
    need(counts.get('wall_jump',0)>=2 and counts.get('slide_landing',0)>=1 and counts.get('grapple',0)>=1,
        'original Lab slide/two wall jumps/grapple missing')
    jumps=[e for e in events if e[0]=='wall_jump']
    need(len(jumps)>=2 and all((e[2].get('move_left') or e[2].get('move_right')) and not e[2].get('move_forward') for e in jumps),
        'Lab wall jump must keep A/D without W')
    chain=[e[0] for e in events]
    need('hop' in chain[chain.index('slide_landing')+1:chain.index('wall_jump')] and
        chain.index('slide_landing')<chain.index('wall_jump')<chain.index('grapple'),'original Lab slide/hop/wall/grapple order')
    return {'ok':True,'counts':counts,'sequence':events}
