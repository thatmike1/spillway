#!/usr/bin/env python3
"""Judge the selected independent review attempts, including negative controls."""
from pathlib import Path
import argparse
import configparser
import gzip
import hashlib
import json

SELECTION = [
    ('full03', 'whiteout-relay', 'gantry', 'server128'),
    ('full03', 'whiteout-relay', 'basin_recovery', 'server128'),
    ('gantry04', 'whiteout-relay', 'gantry_stand', 'server128'),
    ('gantry04', 'whiteout-relay', 'gantry_practice', 'server128'),
    *[('attempt02', 'whiteout-relay', n, 'server128') for n in
      ['under_pylon_release', 'under_pylon_release_open', 'under_pylon_hold', 'under_pylon_hold_open']],
    *[('routes05', 'whiteout-relay', n, 'server128') for n in
      ['chasm_miss', 'cloud_recovery', 'practice_finish', 'preset_taint', 'map_reset']],
    ('routes05', 'whiteout-relay', 'ordinary', 'server128_aa1000'),
    *[('routes05', 'breakwater', n, 'server128') for n in
      ['alley_recovery', 'harbour_recovery', 'crown_contact', 'crown_open']],
    ('routes05', 'breakwater', 'ordinary', 'server128_aa1000'),
]

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--evidence', type=Path, required=True)
    ap.add_argument('--seal-profiles', action='store_true', help='retain record receipts, then remove owned test profiles')
    args = ap.parse_args()
    checks = []
    loaded = {}
    def check(name, value, detail=None):
        checks.append({'check': name, 'ok': bool(value), 'detail': detail})
    for attempt, map_id, case, preset in SELECTION:
        name = f'{map_id}-{case}-{preset}'
        folder = args.evidence/attempt/name
        s = json.loads((folder/'summary.json').read_text())
        with gzip.open(folder/'trace.jsonl.gz', 'rt') as f:
            rows = [json.loads(l) for l in f]
        loaded[(map_id, case, preset)] = (s, rows, folder)
        check(name+' rate and hull', all(r['rate_matches'] and r['hull']['width_u'] == 32 and r['hull']['height_u'] in (54,72) for r in rows))
        check(name+' no interior overlap', s['interior_overlap_ticks'] == 0)
        check(name+' exact trace length', len(rows) == s['ticks'] and [r['t'] for r in rows] == list(range(len(rows))))
        check(name+' actual engine and AA', s['engine_hz'] == 128 and s['actual_settings']['sv_airaccelerate'] == (1000 if preset.endswith('aa1000') else 100))
        profile = folder/'review-profile.cfg'
        c = configparser.ConfigParser(interpolation=None, strict=True)
        if profile.exists():
            c.read(profile)
        receipt_path = folder/'record-evidence.json'
        if receipt_path.exists() and not profile.exists():
            receipt = json.loads(receipt_path.read_text())
        else:
            receipt = {'profile_existed': profile.exists(),
                       'profile_sha256': hashlib.sha256(profile.read_bytes()).hexdigest() if profile.exists() else None,
                       'course_sections': {section: dict(c[section]) for section in c.sections() if section.startswith('course_')}}
            if args.seal_profiles:
                receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
                profile.unlink(missing_ok=True)
        records = {section: int(values['clean_best_ticks']) for section,values in receipt['course_sections'].items()}
        if s['final']['kind'] == 'practice':
            check(name+' no clean or open record', s['final']['best'] < 0 and s['final']['open_best'] < 0 and not records, records)
        elif s['final']['kind'] == 'clean':
            ticks = round(s['final']['elapsed'] * 128)
            check(name+' complete clean record persisted', s['final']['clean'] and all(t >= 0 for t in s['final']['splits'])
                  and records == {'course_'+s['final']['key']: ticks}, records)
    def get(case, map_id='whiteout-relay', preset='server128'):
        return loaded[(map_id,case,preset)]
    for case in ['gantry','basin_recovery']:
        s, rows, _ = get(case)
        check(case+' normal spawn clean with all stages', s['setup']['kind'] == 'normal spawn' and s['final']['kind'] == 'clean' and s['final']['checkpoint'] == 4)
    s, rows, _ = get('basin_recovery')
    names = {c['body'] for r in rows for c in r['contacts'] if abs(c['normal'][1]) < .7}
    check('basin all nine physical stair faces', all('s1_stair_'+str(n) in names for n in range(1,10)), sorted(names))
    check('basin 10 side ticks and no respawn', s['side_contact_ticks_abs_ny_lt_0_7'] == 10 and s['final']['respawns'] == 0)
    for case, cp in [('chasm_miss',2),('cloud_recovery',3)]:
        s, rows, _ = get(case)
        check(case+' one authored checkpoint return', len(s['respawn_events']) == 1 and s['respawn_events'][0]['checkpoint'] == cp
              and s['final']['respawns'] == 1 and s['final']['kind'] == 'practice', s['respawn_events'])
    for case in ['under_pylon_release','under_pylon_release_open']:
        s, rows, _ = get(case)
        expected = 0 if case.endswith('open') else 24
        check(case+' refusal control', s['stand_blocked_ticks'] == expected)
        check(case+' stands safely before landing', any('unduck_air' in r['e'] for r in rows) and any('land' in r['e'] and r['hull']['height_u'] == 72 for r in rows))
    for case in ['under_pylon_hold','under_pylon_hold_open']:
        s, rows, _ = get(case)
        check(case+' actual crouched landing', s['duck_landings'] == 1 and any('land' in r['e'] and r['hull']['height_u'] == 54 for r in rows))
    positive, prows, _ = get('gantry_practice')
    negative, nrows, _ = get('gantry_stand')
    check('gantry matched takeoff', positive['ducks'][0] == negative['ducks'][0])
    start = positive['ducks'][0]['tick']
    check('gantry matched input prefix and states', all(p['p'] == n['p'] and p['v_u'] == n['v_u'] and p['yaw'] == n['yaw'] for p,n in zip(prows[:start+1],nrows[:start+1])))
    check('gantry crouch enables landing', positive['ducks'][1]['landed_on_gantry'] and not negative['ducks'][1]['landed_on_gantry'])
    hit = next(r for r in nrows if any(c['body'] == 's4_gantry_a' and abs(c['normal'][1]) < .7 for c in r['contacts']))
    check('gantry standing loses normal speed, preserves tangent', hit['v_u'][2] == 0 and abs(hit['v_u'][0] - hit['start_v_m'][0]/.0254) < .001
          and abs(hit['start_v_m'][2]/.0254) > 200, {'tick':hit['t'],'start_m_s':hit['start_v_m'],'post_u_s':hit['v_u']})
    check('gantry crouched landing and free stand', positive['duck_landings'] >= 1 and positive['stand_blocked_ticks'] == 0 and any('unduck' in r['e'] for r in prows))
    s, rows, _ = get('preset_taint')
    switches = [a for a in s['actions'] if a['tick'] >= 0]
    check('preset switch and switch back stay practice', len(switches) == 2 and all(not a['after']['clean'] and a['after']['reason'] == 'preset' for a in switches)
          and s['final']['kind'] == 'practice', switches)
    s, rows, _ = get('map_reset')
    a = next(a for a in s['actions'] if 'menu' in a)
    check('map changes start fresh attempts and distinct keys', not a['before']['clean'] and a['other']['attempt'] == a['before']['attempt']+1
          and a['after']['attempt'] == a['before']['attempt']+2 and a['other']['key'] != a['after']['key']
          and all(a[k]['checkpoint'] == 0 and a[k]['elapsed'] == 0 and a[k]['splits'] == [-1]*5 for k in ['other','after']), a)
    for map_id in ['whiteout-relay','breakwater']:
        s, rows, _ = get('ordinary', map_id, 'server128_aa1000')
        check(map_id+' actual F5 from untouched spawn may record', s['actions'][0]['key'] == 'f5' and s['actions'][0]['after']['clean'] and s['final']['kind'] == 'clean')
    s, rows, _ = get('alley_recovery','breakwater')
    check('breakwater alley physical recovery clean', s['side_contact_ticks_abs_ny_lt_0_7'] == 18 and s['final']['respawns'] == 0 and s['final']['kind'] == 'clean')
    s, rows, _ = get('harbour_recovery','breakwater')
    check('breakwater harbour checkpoint practice', len(s['respawn_events']) == 1 and s['respawn_events'][0]['checkpoint'] == 2 and s['final']['kind'] == 'practice',s['respawn_events'])
    s, rows, _ = get('crown_contact','breakwater')
    hit = next(r for r in rows if any(abs(c['normal'][1]) < .7 for c in r['contacts']))
    check('crown clips into-face speed and preserves tangent', abs(hit['v_u'][0]) < .001 and abs(hit['v_u'][2] - hit['requested_v_m'][2]/.0254) < .001, hit)
    control, crows, _ = get('crown_open','breakwater')
    check('crown open negative control no side contact', control['side_contact_ticks_abs_ny_lt_0_7'] == 0 and abs(crows[hit['t']]['v_u'][0] - hit['requested_v_m'][0]/.0254) < .001)
    result = {'checks':len(checks),'failed':sum(not c['ok'] for c in checks),'checks_detail':checks,
              'selected_runs':[{'attempt':a,'map':m,'case':c,'preset':p} for a,m,c,p in SELECTION],
              'selected_ticks':sum(len(v[1]) for v in loaded.values()),
              'excluded':['attempt01: seed inside pier and before warmup', 'full03 gantry practice/stand: first waypoint skipped due to controller node_from origin; cancelled before completion of batch']}
    (args.evidence/'CHECKS.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'checks':result['checks'],'failed':result['failed'],'failed_details':[c for c in checks if not c['ok']]},indent=2))
    raise SystemExit(1 if result['failed'] else 0)

if __name__ == '__main__':
    main()
