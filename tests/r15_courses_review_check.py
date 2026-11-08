#!/usr/bin/env python3
"""judge the independent source-course review; never repairs the runtime or traces."""
import argparse
import gzip
import hashlib
import json
import math
import sys
sys.dont_write_bytecode = True
import importlib.util
from pathlib import Path


def read(path):
    if path.exists():
        return json.loads(path.read_text())
    with gzip.open(str(path) + '.gz', 'rt') as stream:
        return json.load(stream)


def rows(path):
    spec = importlib.util.spec_from_file_location('trace_store', Path(__file__).with_name('r15_courses_review_store.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return [json.loads(line) for line in module.read_trace(path).decode().splitlines()]


def finite(value):
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, dict):
        return all(finite(v) for v in value.values())
    if isinstance(value, list):
        return all(finite(v) for v in value)
    return True


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True, type=Path)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    selected = {}
    # later corrected harness trials replace earlier controller/seed failures, never erase them.
    for batch in ['probes02', 'routes03', 'routes04', 'targeted05']:
        for summary in sorted((evidence / batch).glob('*/summary.json*')):
            selected[summary.parent.name] = summary.parent
    excluded = {
        ('routes03', 'sunken-court-arch_return-server128'),
        ('routes03', 'sunken-court-causeway_stand-server128'),
    }
    checks = []
    def check(name, ok, detail=None):
        checks.append({'name': name, 'ok': bool(ok), 'detail': detail})
    total_ticks = 0
    cases = {}
    cached = {}
    for name, path in selected.items():
        if (path.parent.name, name) in excluded:
            continue
        summary = read(path / 'summary.json')
        trace = rows(path)
        cached[name] = trace
        total_ticks += len(trace)
        check(name + ': contiguous finite trace', [r['t'] for r in trace] == list(range(len(trace))) and finite(trace) and len(trace) == summary['ticks'])
        check(name + ': real host and rate', summary['runner'] == 'res://scripts/r15_source_player.gd' and summary['motor_version'] == 'r15-source-crouch-2' and summary['engine_hz'] == 128 and all(r['rate_matches'] for r in trace))
        check(name + ': physical key delivery', all(set(r['held']) == set(r['delivered']) for r in trace))
        check(name + ': no interior hull overlap at 6 mm shrink', summary['interior_overlap_ticks'] == 0)
        fd_max = 0.0
        skipped = []
        for prior, row in zip(trace, trace[1:]):
            if row['game']['attempt'] != prior['game']['attempt'] or row['game']['respawns'] != prior['game']['respawns']:
                skipped.append(row['t'])
                continue
            shift = row['duck']['shift_u']
            error = max(abs((row['p'][i]-prior['p'][i])-shift[i]*0.0254-row['displacement'][i]) for i in range(3))
            fd_max = max(fd_max, error)
        check(name + ': finite-difference travel agrees with reported motor displacement', fd_max < 0.00002, {'max_m': fd_max, 'reset_rows_excluded': skipped})
        check(name + ': actual velocity equals displacement over delta', all(max(abs(r['actual_v_m'][i]/128-r['displacement'][i]) for i in range(3)) < 0.000001 for r in trace))
        side = [r for r in trace if any(abs(c['normal'][1]) < .7 for c in r['contacts'])]
        check(name + ': normals reproduce side count', len(side) == summary['side_contact_ticks_abs_ny_lt_0_7'])
        cases[name] = {'path': str(path.relative_to(evidence)), 'reason': summary['reason'], 'ticks': len(trace), 'setup': summary['setup'], 'final': summary['final'], 'side_ticks': len(side), 'blocked_ticks': summary['stand_blocked_ticks'], 'duck_landings': summary['duck_landings'], 'trace_receipt_sha256': sha(path/('trace.jsonl.gz' if (path/'trace.jsonl.gz').exists() else 'trace-index.json'))}
        case = summary['case']
        if case == 'wrong_deck':
            check(name + ': wrong deck never collects progress', all(r['game']['checkpoint'] == 0 for r in trace))
        if case == 'air_checkpoint':
            first = next((r for r in trace if r['game']['checkpoint'] == 1), None)
            check(name + ': air crouch does not collect; first supported landing does', first is not None and first['g'] and all(r['game']['checkpoint'] == 0 for r in trace[:first['t']]) and any(r['hull']['ducked'] and not r['g'] for r in trace))
        if case in ['side_contact', 'side_open']:
            check(name + ': no seeded profile writes', summary['final']['best'] < 0 and summary['final']['open_best'] < 0)
        if case in ['arch_return', 'east_cistern', 'throat_return', 'causeway_hold', 'causeway_release', 'duct_release', 'hatch_hold', 'hatch_release']:
            check(name + ': normal-spawn input-earned completion', summary['setup']['kind'] == 'normal spawn' and summary['final']['finished'] and summary['final']['kind'] == 'clean' and summary['final']['respawns'] == 0)
        if case in ['duct_release', 'hatch_release']:
            check(name + ': release safely deferred and later standing', summary['stand_blocked_ticks'] > 0 and not trace[-1]['hull']['ducked'] and any(r['duck']['stand_blocked'] and not ('ctrl' in r['delivered']) for r in trace))
        if case == 'practice_finish':
            f = [a for a in summary['actions'] if a.get('key') == 'f']
            check(name + ': F from earned checkpoint stays unrecorded practice', len(f) == 1 and f[0]['before']['checkpoint'] >= 3 and f[0]['after']['practice_stage'] >= 3 and not f[0]['after']['clean'] and summary['final']['kind'] == 'practice' and summary['final']['best'] < 0 and summary['final']['open_best'] < 0)
        if case == 'restart':
            f = next(a for a in summary['actions'] if a.get('key') == 'f')
            r = next(a for a in summary['actions'] if a.get('key') == 'r')
            check(name + ': R restores clean spawn after F', not f['after']['clean'] and r['after']['clean'] and r['after']['checkpoint'] == 0 and r['after']['elapsed'] == 0 and all(t == -1 for t in r['after']['splits']))
    contacts = {}
    for map_id in ['sunken-court','rainline','night-shift']:
        name = map_id + '-side_contact-server128'
        trace = cached[name]
        first = next(r for r in trace if any(c['blocking'] and abs(c['normal'][0]) > .99 for c in r['contacts']))
        control = cached[map_id + '-side_open-server128'][first['t']]
        error = abs(first['v_u'][2]*.0254-first['requested_v_m'][2])
        check(name + ': first contact removes normal speed and preserves tangential speed', abs(first['v_u'][0]) < .01 and error < .00001 and abs(control['v_u'][2]-first['v_u'][2]) < .001 and not control['contacts'])
        contacts[map_id] = {'t': first['t'], 'p':first['p'], 'normals': first['contacts'], 'requested_m_s':first['requested_v_m'], 'post_u_s':first['v_u'], 'actual_m_s':first['actual_v_m'], 'matched_open_m_s':control['requested_v_m'], 'tangent_error_m_s':error}
    key_path = selected['sunken-court-map_keys-server128']
    keys = read(key_path/'summary.json')['actions']
    maps = [a for a in keys if 'menu_map' in a]
    check('map-specific record keys', len({a['after']['key'] for a in maps}) == 3)
    check('map changes reset progress and timer', all(a['after']['checkpoint'] == 0 and a['after']['elapsed'] == 0 and all(t == -1 for t in a['after']['splits']) for a in maps))
    f5 = next(a for a in keys if a.get('key') == 'f5')
    f2 = [a for a in keys if a.get('key') == 'f2'][-1]
    check('F5 identity differs and F2 returns to its map key', f5['after']['key'] != f5['before']['key'] and f2['after']['key'] == maps[-1]['after']['key'])
    profiles = {}
    for batch in ['routes03','routes04','targeted05']:
        result_path = evidence/batch/'RESULTS.json'
        if result_path.exists() or Path(str(result_path)+'.gz').exists():
            result = read(result_path)
            check(batch + ': tracked files unchanged and scratch removed', result['sources_unchanged'] and result['scratch_removed'])
            profiles.update({batch+'/'+k:v for k,v in result.get('profile_files',{}).items()})
    profile_checks = {}
    for name, case in cases.items():
        if case['final']['finished']:
            profile = profiles.get(case['path']+'/review-profile.cfg')
            check(name + ': isolated profile write policy', not (evidence/case['path']/'review-profile.cfg').exists() and ((profile is not None) if case['final']['kind'] == 'clean' else (profile is None)))
            if profile:
                text = profile['text']
                key = case['final']['key']
                if case['final']['kind'] == 'clean':
                    check(name + ': persisted its own map section and integer best', f'[course_{key}]' in text and 'best_ticks=' in text)
                else:
                    check(name + ': practice did not save a course best', f'[course_{key}]' not in text)
                profile_checks[name] = profile['sha256']
    output = {'checks':len(checks),'failed':[c for c in checks if not c['ok']], 'selected_cases':len(cases),'observed_ticks':total_ticks,'cases':cases,'contacts':contacts,'profile_receipts':profile_checks,'all_checks':checks}
    (evidence/'CHECKS.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({k:output[k] for k in ['checks','failed','selected_cases','observed_ticks']},indent=2))
    raise SystemExit(bool(output['failed']))


if __name__ == '__main__':
    main()
