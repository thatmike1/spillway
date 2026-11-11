#!/usr/bin/env python3
"""analyse R20 observations for R21, one strict recording at a time; never run the game."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path
import shutil
import statistics
import subprocess
import sys

sys.dont_write_bytecode = True
BASELINE = 'e6baa995da84d380abc8b8d6a3769b33e771945e'
EXPECTED = {'breakwater': 14, 'saltglass': 2, 'tether-yard': 16, 'through-line': 1}
SOURCES = ['r15_breakwater_level.gd', 'r15_breakwater_art.gd', 'r16_style_opportunities.gd',
           'r19_course_revisions.gd', 'r16_style.gd', 'r20_surf_level.gd', 'r19_course_geometry.gd',
           'r19_tether_level.gd', 'r20_tether_level.gd', 'r20_tether_player.gd',
           'r19_tether_player.gd', 'r15_experiment_player.gd', 'r15_source_player.gd',
           'r16_run_recorder.gd', 'r16_run_session.gd', 'r20_main.gd', 'r20_through_player.gd']


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(65536), b''):
            h.update(block)
    return h.hexdigest()


def inventory(root):
    return {str(p.relative_to(root)): {'bytes': p.stat().st_size, 'sha256': digest(p)}
            for p in sorted(root.rglob('*')) if p.is_file()}


def module(name):
    path = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def peak_rss_bytes():
    # /proc resets VmHWM at exec; getrusage can inherit the launching shell high-water mark.
    return int(next(x.split()[1] for x in Path("/proc/self/status").read_text().splitlines() if x.startswith("VmHWM:"))) * 1024


def guard():
    free = shutil.disk_usage(Path.home()).free
    if free < 15_000_000_000:
        raise RuntimeError(f'HOME free {free} < 15000000000; parent owns cleanup')
    if peak_rss_bytes() > 100 * 1024**2:
        raise RuntimeError('analysis RSS exceeded 100 MiB')
    return free


def sample(rec, i, reader):
    c = rec.columns
    i = max(0, min(i, len(c['tick']) - 1))
    v = [c[f'v_{a}'][i] for a in 'xyz']
    av = [c[f'actual_v_{a}'][i] for a in 'xyz']
    return {'tick': c['tick'][i], 'sim_s': sum(c['dt'][:i + 1]), 'elapsed': c['elapsed'][i],
            'p_m': [c[f'p_{a}'][i] for a in 'xyz'],
            'reference_p_m': [c[f'reference_p_{a}'][i] for a in 'xyz'],
            'v_ms': v, 'actual_v_ms': av, 'horizontal_ups': math.hypot(av[0], av[2]) / reader.U,
            'stored_horizontal_ups': math.hypot(v[0], v[2]) / reader.U,
            'total_ups': math.sqrt(sum(x*x for x in v)) / reader.U,
            'yaw': c['yaw'][i], 'pitch': c['pitch'][i], 'grounded': bool(c['flags'][i] & 8),
            'ducked': bool(c['flags'][i] & 16), 'checkpoint': c['checkpoint'][i]}


def window(rec, lo, hi, reader, stride=1):
    c = rec.columns
    return {'from_tick': lo, 'to_tick': hi, 'stride': stride,
            'samples': [sample(rec, i, reader) for i, t in enumerate(c['tick'])
                        if lo <= t <= hi and (t-lo) % stride == 0],
            'events': [e for e in rec.events if lo <= e['t'] <= hi]}


def flights(rec, reader):
    c = rec.columns
    out, start = [], None
    breaks = {d['index'] for d in reader.discontinuities(c, rec.events)
              if d['kind'] in {'respawn', 'lifecycle', 'unexplained'}}
    for i in range(1, len(c['tick'])):
        if i in breaks:
            start = None
        elif c['flags'][i-1] & 8 and not c['flags'][i] & 8:
            start = i
        elif start is not None and c['flags'][i] & 8:
            if i-start >= 4:
                indices = range(start, i+1)
                out.append({'takeoff_ground': sample(rec, start-1, reader),
                            'takeoff_air': sample(rec, start, reader), 'landing': sample(rec, i, reader),
                            'peak': sample(rec, max(indices, key=lambda j: c['p_y'][j]), reader),
                            'air_s': sum(c['dt'][start:i]),
                            'xz_min': [min(c[f'p_{a}'][j] for j in indices) for a in 'xz'],
                            'xz_max': [max(c[f'p_{a}'][j] for j in indices) for a in 'xz']})
            start = None
    return out


def tether(rec, reader):
    c = rec.columns
    identity = next(x for x in rec.header['metadata']['physics']['mechanics'] if 'model' in x)
    ins = rec.inputs
    edges = defaultdict(list)
    for i,t in enumerate(ins['tick']):
        if ins['kind'][i] == 2:
            edges[t].append({'button': ins['code'][i], 'pressed': bool(ins['flags'][i]&1)})
    right = False
    right_by_tick = {}
    for t in c['tick']:
        for e in edges[t]:
            if e['button'] == 2:
                right = e['pressed']
        right_by_tick[t] = right
    index = {t:i for i,t in enumerate(c['tick'])}
    episodes, active = [], None
    for e in rec.events:
        if e['k'] != 'tether':
            continue
        t, d = e['t'], e['d']
        if d['kind'] == 'attach':
            active = {'attach': e, 'at_attach': sample(rec, index[t], reader)}
            episodes.append(active)
        elif d['kind'] == 'release' and active:
            lo, hi = active['attach']['t'], t
            js = [i for i,x in enumerate(c['tick']) if lo <= x <= hi]
            reeling = [j for j in js if identity['automatic_reel'] or right_by_tick[c['tick'][j]]]
            active.update({'release': e, 'before_release': sample(rec,index.get(t,len(c['tick']))-1,reader),
                           'at_release': sample(rec,index.get(t,len(c['tick'])-1),reader),
                           'reel_input_s_inclusive': sum(c['dt'][j] for j in reeling),
                           'endpoint_shortening_u': active['attach']['d']['length_u']-d['length_u'],
                           'peak_horizontal_ups': max(sample(rec,j,reader)['horizontal_ups'] for j in js),
                           'trace': window(rec,lo,hi,reader,16)})
            anchor = {'Transfer 1':[0,12,-8], 'Transfer 2':[10,12,-38], 'Transfer 3':[-2,12,-68]}.get(d.get('anchor'))
            if anchor:
                active['anchor_m'] = anchor
                # diagnostic is emitted before the current motor step; use the previous physical feet.
                before = active['before_release']
                height = (54 if before['ducked'] else 72)*reader.U
                centre = before['p_m'].copy(); centre[1] += height/2
                distance = math.dist(centre,anchor)/reader.U
                active['release_previous_sample_distance_u'] = distance
                active['release_previous_sample_distance_minus_length_u'] = distance-d['length_u']
            active = None
    misses = [e for e in rec.events if e['k']=='motion' and 'grapple_miss' in e['d'].get('events',[])]
    return {'identity':identity, 'episodes':episodes, 'misses':misses,
            'left_presses':sum(e['pressed'] and e['button']==1 for rows in edges.values() for e in rows),
            'right_presses':sum(e['pressed'] and e['button']==2 for rows in edges.values() for e in rows),
            'unknown':'no per-tick rope length/tension/force, target state, contact normals/body or audio perception; input state begins released after menu arming, endpoint stretch uses prior feet and nominal hull'}


def geometry_excerpt(sources):
    """derive only the straight chicane solids from the pinned original manifest builder."""
    source = sources['projects/foldrunner/scripts/r15_breakwater_level.gd']['source']
    values = {k: float(re.search(r'const '+k+r' := ([0-9.]+)',source)[1])
              for k in ['CW','CH','L20','L10']}
    cw,ch,l20,l10 = (values[k] for k in ['CW','CH','L20','L10'])
    assert '[-46.0, -46.0 - 2.0 * CW, QUAY_S + L20 + L10, QUAY_S]' in source
    assert '_container("s2_chicane_%d_%d_%d"' in source
    assert 'bottom + tiers * CH' in source and 'manifest.append' in source
    south = -72.366-(8+2*3.5*cw)
    z = south+l20+l10
    solids=[]
    for j,length in enumerate([l20,l10]):
        for k in range(2):
            x=-46-k*cw
            solids.append({'name':f's2_chicane_2_{j+1}_{k+1}', 'role':'wall', 'kind':'container',
                           'stage':-1, 'min_m':[x-cw,0,z-length], 'max_m':[x,2*ch,z]})
        z-=length
    return {'source':'r15_breakwater_level.gd::_crane_line/_container/_solid',
            'scope':'partial manifest reconstruction only; not a recomputed complete geometry hash',
            'constants':values, 'solids':solids, 'quay_south_z':south,
            'quay_b':{'min_m':[-56.533,-8,south],'max_m':[-36.533,0,-80.366]}}


def outside_lines(rec, reader, geometry):
    rows=[]; c=rec.columns
    for flight in flights(rec,reader):
        lo,hi=flight['takeoff_ground']['tick'],flight['landing']['tick']
        if not (-45<flight['takeoff_ground']['p_m'][0]<-39 and flight['xz_min'][1]<-98):continue
        samples=window(rec,lo,hi,reader)['samples']
        half=16*reader.U; south=geometry['quay_south_z']
        def clearance(x):
            px,_,pz=x['p_m']
            dx=max(-50.876-px,px+46,0)-half
            dz=max(south-pz,pz+88.383,0)-half
            return math.hypot(max(dx,0),max(dz,0)) if dx>0 or dz>0 else max(dx,dz)
        crossed=[x for x in samples if -50.876-half<=x['p_m'][0]<=-46+half]
        if not crossed:continue
        closest=min(samples,key=clearance)
        rows.append({'flight':flight,'cross_stack_ticks':[crossed[0]['tick'],crossed[-1]['tick']],
                     'minimum_hull_clearance_xz_m':clearance(closest),'closest_sample':closest,
                     'minimum_south_face_clearance_during_x_overlap_m':min(south-x['p_m'][2]-half for x in crossed),
                     'awards':[e for e in rec.events if e['k']=='style' and lo<e['t']<=hi],
                     'inference':'axis-aligned box-to-box horizontal separation using nominal hull; no contact normal or swept clearance proof'})
    return rows


def tether_summary(runs):
    out={}
    for model,automatic in [('classic',False),('pendulum',False),('elastic',False),('elastic',True)]:
        rows=[r for r in runs if r['map']=='tether-yard' and (r['tether']['identity']['model'],r['tether']['identity']['automatic_reel'])==(model,automatic)]
        eps=[e for r in rows for e in r['tether']['episodes'] if 'release' in e]
        out[model+('/auto' if automatic else '/manual')]={
            'attempts':len(rows),'timer_started_attempts':sum(r['timer_start_tick'] is not None for r in rows),
            'attempts_with_attach':sum(bool(r['tether']['episodes']) for r in rows),
            'outcomes':dict(Counter(r['ended_by'] for r in rows)), 'attachments':len(eps),
            'miss_events':sum(len(r['tether']['misses']) for r in rows),
            'recorded_left_presses':sum(r['tether']['left_presses'] for r in rows),
            'peak_horizontal_ups':max((r['peak_sample']['horizontal_ups'] for r in rows),default=0),
            'median_attachment_s':statistics.median(e['release']['d']['attached_ticks']/128 for e in eps) if eps else None,
            'median_episode_peak_ups':statistics.median(e['peak_horizontal_ups'] for e in eps) if eps else None,
            'median_release_ups':statistics.median(e['at_release']['horizontal_ups'] for e in eps) if eps else None,
            'endpoint_shortening_u_sum':sum(e['endpoint_shortening_u'] for e in eps),
            'reel_input_s_inclusive_sum':sum(e['reel_input_s_inclusive'] for e in eps),
            'median_release_distance_minus_rope_u':statistics.median(e['release_previous_sample_distance_minus_length_u'] for e in eps) if eps else None,
            'release_reasons':dict(Counter(e['release']['d']['reason'] for e in eps))}
    return out


def direction_audit(rec):
    """check recorded accounting and bank formulas without reconstructing hidden collision state."""
    scored=[e['d'] for e in rec.events if e['k']=='style']
    checks={'seal_score_matches':sum(e['points'] for e in scored)==rec.seal['outcome']['style']['score'],
            'bank_formula_matches':True, 'pending_formula_matches':True, 'bank_diagnostic_pairs':True}
    for e in scored:
        if e['v']==2:
            m=e['m']; unit=160 if e['kind']=='backward_bhop_bank' else 50
            checks['bank_formula_matches'] &= e['points']==e['base']==unit*m['hops']*(m['hops']-1)//2
    for outer in rec.events:
        if outer['k']!='direction':continue
        e=outer['d']; unit=160 if e['direction']=='backward_bhop' else 50
        checks['pending_formula_matches'] &= e['pending']==unit*e['hops']*(e['hops']-1)//2
        if e['kind']=='direction_banked' and e['pending']>0:
            checks['bank_diagnostic_pairs'] &= sum(x['v']==2 and x['tick']==e['tick'] and x['points']==e['pending'] for x in scored)==1
    return checks


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('recordings',type=Path)
    p.add_argument('--exclude',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--manifest',type=Path,required=True)
    p.add_argument('--baseline',default=BASELINE)
    args=p.parse_args()
    args.recordings=args.recordings.resolve(); args.exclude=args.exclude.resolve()
    user=args.recordings.parent
    if args.output.resolve()==args.manifest.resolve():
        p.error('output and manifest must differ')
    for path in [args.output.resolve(),args.manifest.resolve()]:
        if path.is_relative_to(user) or path.is_relative_to(args.exclude):
            p.error('outputs must be outside both input trees')
    guard()
    before=inventory(user); old_before=inventory(args.exclude)
    prior=defaultdict(list)
    for n,v in old_before.items():
        if n.endswith('.r16run'): prior[v['sha256']].append(n)
    names={n:v for n,v in before.items() if n.startswith(args.recordings.name+'/')}
    inherited={n:prior[v['sha256']] for n,v in names.items() if v['sha256'] in prior}
    selected=[n for n in names if n.endswith('.r16run') and n not in inherited]
    reader=module('analyze-r16-runs.py'); stop=module('analyze-r19-playtest.py')
    root=Path(__file__).resolve().parents[1]
    reader_baseline=subprocess.check_output(['git','show',args.baseline+':projects/foldrunner/tools/analyze-r16-runs.py'],cwd=root)
    if hashlib.sha256(reader_baseline).hexdigest()!=digest(Path(reader.__file__)):
        raise RuntimeError('strict reader differs from pinned baseline')
    sources={}
    for name in SOURCES:
        path='projects/foldrunner/scripts/'+name
        raw=subprocess.check_output(['git','show',args.baseline+':'+path],cwd=root)
        sources[path]={'sha256':hashlib.sha256(raw).hexdigest(),'source':raw.decode()}
    runs=[]; failures=[]
    for name in names:
        if not name.endswith(('.r16run','.part','.aborted')): continue
        rec=reader.read(user/name)
        if not rec.ok:
            failures.append({'name':name,'errors':rec.errors,'status':rec.status})
            continue
        if name in inherited: continue
        r=reader.analyse(rec,.75); c=rec.columns
        r['sha256']=names[name]['sha256']; r['metadata']=rec.header['metadata']
        r['stopped_spans']=stop.stopped_spans(rec,reader)
        r['style_events']=[e for e in rec.events if e['k']=='style']
        r['direction_events']=[e for e in rec.events if e['k']=='direction']
        r['direction_audit']=direction_audit(rec)
        r['motion_events']=dict(Counter(n for e in rec.events if e['k']=='motion' for n in e['d'].get('events',[])))
        r['flights']=flights(rec,reader)
        r['last_sample']=sample(rec,len(c['tick'])-1,reader)
        r['peak_sample']=sample(rec,max(range(len(c['tick'])),key=lambda j:math.hypot(c['actual_v_x'][j],c['actual_v_z'][j])),reader)
        r['abrupt_losses']=[{'drop_ups':sample(rec,i-1,reader)['horizontal_ups']-sample(rec,i,reader)['horizontal_ups'],
                            'before':sample(rec,i-1,reader),'after':sample(rec,i,reader)}
                           for i in range(1,len(c['tick']))
                           if math.hypot(c['actual_v_x'][i-1],c['actual_v_z'][i-1])-math.hypot(c['actual_v_x'][i],c['actual_v_z'][i])>=100*reader.U
                           and c['respawns'][i]==c['respawns'][i-1]]
        if r['map']=='saltglass':
            r['salt_trace']=window(rec,0,c['tick'][-1],reader,16)
            r['fin_end_crossings']=[]
            for i in range(1,len(c['tick'])):
                z0,z=c['p_z'][i-1],c['p_z'][i]
                fin='west' if z0>-168>=z else 'east' if z0<0<=z and c['checkpoint'][i]>=2 else None
                if fin:r['fin_end_crossings'].append({'fin':fin,'before':sample(rec,i-1,reader),'after':sample(rec,i,reader)})
            r['fin_exit_windows']=[window(rec,max(0,x['after']['tick']-220),min(c['tick'][-1],x['after']['tick']+180),reader) for x in r['fin_end_crossings']]
        if r['map']=='breakwater':
            ids=[i for i in range(len(c['tick'])) if -56<c['p_x'][i]<-38 and -102<c['p_z'][i]<-78]
            if ids:r['chicane_window']=window(rec,max(0,c['tick'][ids[0]]-100),min(c['tick'][-1],c['tick'][ids[-1]]+100),reader)
        if r['map']=='breakwater':r['outside_lines']=outside_lines(rec,reader,geometry_excerpt(sources))
        if r['map']=='tether-yard':
            r['tether']=tether(rec,reader)
            r['clip_windows']=[window(rec,max(0,x['after']['tick']-20),min(c['tick'][-1],x['after']['tick']+20),reader) for x in r['abrupt_losses']]
            r['miss_windows']=[window(rec,max(0,x['t']-8),min(c['tick'][-1],x['t']+12),reader) for x in r['tether']['misses']]
        if r['map']=='through-line':r['through_events']=[e for e in rec.events if e['k']=='through']
        runs.append(r)
        del rec
        guard()
    counts=dict(Counter(r['map'] for r in runs)); maps={}
    for mp in counts:
        rows=[r for r in runs if r['map']==mp]; style=defaultdict(lambda:{'count':0,'points':0})
        for r in rows:
            for k,v in r['style']['by_kind'].items():
                for field in ('count','points'):style[k][field]+=v[field]
        maps[mp]={'attempts':len(rows),'sim_seconds':sum(r['sim_seconds'] for r in rows),
                  'ended_by':dict(Counter(r['ended_by'] for r in rows)), 'respawns':sum(r['falls'] for r in rows),
                  'stalls':sum(len(r['stopped_spans']) for r in rows),'stall_s':sum(s['seconds'] for r in rows for s in r['stopped_spans']),
                  'style':dict(style)}
    after=inventory(user);old_after=inventory(args.exclude)
    cohort_ok=counts==EXPECTED and len(selected)==33 and len({names[n]['sha256'] for n in selected})==33
    identities_ok=all(r['preset']=='server128' and r['physics_hz']==[128] and r['metadata']['build']=='spillway-2026.11.10-r20' for r in runs)
    unchanged=before==after and old_before==old_after
    helpers={x.name:digest(x) for x in [Path(__file__),Path(reader.__file__),Path(stop.__file__)]}
    report={'baseline':args.baseline,'helper_sha256':helpers,'source_rules':sources,
            'geometry_excerpt':geometry_excerpt(sources),'tether_comparison':tether_summary(runs),
            'scope':{'strict_complete_reads':len([n for n in names if n.endswith('.r16run')])-len(failures),'files':len(names),'fresh':len(selected),'inherited':len(inherited),'expected':EXPECTED,'actual':counts},
            'strict_failures':failures,'cohort_ok':cohort_ok,'identities_ok':identities_ok,
            'input_hashes_unchanged':unchanged,'direction_audit_ok':all(all(r['direction_audit'].values()) for r in runs),'maps':maps,'runs':runs,
            'method':{'loss':'strict reader drawdowns >=0.75 m/s, largest 12/run; separate all >=100u/s single-tick losses',
                      'stall':'actual horizontal <25u/s >=0.5s started unfinished, split at discontinuities',
                      'contacts':'not serialized; geometric side overlap and loss coincide only as inference',
                      'time':'tick attempt-local; elapsed course clock; sim_s includes pre-start waits but excludes pauses',
                      'clearance':'axis-aligned 32u hull from header; geometry evaluated against pinned R20 source, no engine query',
                      'style':'all actual scored and non-scored direction events retained; no synthetic bonuses',
                      'limits':'one strict recording in memory at a time; no Godot, display, capture or replay'}}
    manifest={'before':before,'after':after,'exclude_before':old_before,'exclude_after':old_after,
              'recordings':str(args.recordings),'exclude':str(args.exclude),'inherited_exact_hash_matches':inherited,
              'fresh_names':selected,'unchanged':unchanged,'helper_sha256':helpers,
              'source_sha256':{k:v['sha256'] for k,v in sources.items()},'baseline':args.baseline,
              'home_free_bytes_after':guard(),'peak_rss_bytes':peak_rss_bytes()}
    for path,data in [(args.output,report),(args.manifest,manifest)]:
        raw=(json.dumps(data,indent=1,allow_nan=False)+'\n').encode()
        if len(raw)>19*1024**2:raise RuntimeError('derived evidence too large')
        path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    guard()
    print(json.dumps({'maps':maps,'failures':failures,'scope':report['scope'],'unchanged':unchanged,
                      'identities_ok':identities_ok,'cohort_ok':cohort_ok,'peak_rss_bytes':manifest['peak_rss_bytes']},indent=2))
    if failures or not cohort_ok or not identities_ok or not unchanged or not report['direction_audit_ok']:raise SystemExit(1)


if __name__=='__main__':
    main()
