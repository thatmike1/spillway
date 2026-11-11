#!/usr/bin/env python3
"""audit matched entries, genuine supports and the two physical lines using both strict readers."""
from __future__ import annotations
import argparse
import gzip
import importlib.util
import itertools
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def rows(path):
    with gzip.open(path / 'trace.jsonl.gz', 'rt') as stream:
        for line in stream:
            yield json.loads(line)


def audit(base):
    checks = []
    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})
    spec = importlib.util.spec_from_file_location('strict', PROJECT / 'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    exits = {}
    for fin in ['west', 'east']:
        trial = {}
        for geo, target in [('r20', '10.0'), ('r21', '10.0'), ('r21', '5.3'), ('r20', '5.3')]:
            name = fin + '-' + geo + '-' + target
            trial[geo + '-' + target] = json.loads((base / name / 'exit.json').read_text())
            check(trial[geo + '-' + target]['ok'], name + ' actual support or expected low-line failure')
        reference = trial['r20-10.0']['first_contact']
        for name, entry in trial.items():
            row = entry['first_contact']
            shift = 0
            check(abs(row['p'][0] - reference['p'][0] - shift) < .003 and abs(row['p'][1] - reference['p'][1]) < .003 and abs(row['p'][2] - reference['p'][2]) < .003 and abs(row['speed_u'] - reference['speed_u']) < 1,
                  fin + ' ' + name + ' starts from the same actual high entry and speed (east tested in common world coordinates)')
        old = trial['r20-10.0']['support']
        new = trial['r21-5.3']['support']
        check(abs(old['surface_point'][1] - 14) < .001 and abs(new['surface_point'][1] - 7) < .001, fin + ' first flat support is seven metres lower')
        check(new['speed_u'] > old['speed_u'] + 100, fin + ' low supported line retains materially more horizontal speed than old high exit line')
        check(trial['r20-5.3']['failure_expected'] and not trial['r20-5.3']['support'], fin + ' identical low steering has no usable old support')
        low_equal = True
        stop = min(trial['r20-5.3']['crossed']['tick'], trial['r21-5.3']['crossed']['tick'])
        for a, b in itertools.islice(zip(rows(base / (fin + '-r20-5.3')), rows(base / (fin + '-r21-5.3'))), stop):
            shift = 0
            low_equal &= all(abs(a['p'][i] + (shift if i == 0 else 0) - b['p'][i]) < .003 for i in range(3)) and all(abs(a['v'][i] - b['v'][i]) < .03 for i in range(3))
        check(low_equal, fin + ' low-line old/new approach remains matched to fin exit; support benefit is geometric')
        exits[fin] = trial
    skill = {mode: json.loads((base / ('skill-' + mode) / 'skill.json').read_text()) for mode in ['safe', 'outside', 'late']}
    safe, outside = skill['safe'], skill['outside']
    for mode, trial in skill.items():
        summary = json.loads((base / ('skill-' + mode) / 'summary.json').read_text())
        check(trial['ok'] and summary['pass'], 'physical ' + mode + ' fixture passes its declared result')
        if mode != 'late':
            check(not summary['failure'] and not summary['respawns'], mode + ' completes without fall or rescue')
        for recording in summary['recordings']:
            rec = reader.read(Path(recording['path']))
            check(rec.ok and recording['ok'], mode + ' recording accepted by original Python and Godot strict readers')
            if mode == 'outside':
                trial['events'] = [e for e in rec.events if e['k'] == 'style']
    check(safe['branch_tick'] == outside['branch_tick'] and all(a == b for a, b in itertools.islice(zip(rows(base / 'skill-safe'), rows(base / 'skill-outside')), safe['branch_tick'])), 'safe/outside share the same earned input prefix to the physical fork')
    check(outside['outside_over_water'] and not outside['store_contact'], 'outside hull passes the solid side over unsupported water, below its roof')
    common_plane = {name: (next(r['tick'] for r in row['rows'] if r['p'][0] >= 225) - row['branch_tick']) / 128 for name, row in [('safe', safe), ('outside', outside)]}
    outside['same_x225_seconds'] = common_plane['outside']
    safe['same_x225_seconds'] = common_plane['safe']
    check(common_plane['outside'] < common_plane['safe'], 'outside is faster at the same downstream x=225 plane')
    check(outside['branch_to_landing_s'] < safe['branch_to_landing_s'], 'outside fixture reaches its real landing sooner than the inland line')
    first_landing = outside['rows'][outside['landing_tick']]
    check(first_landing['support'].startswith('outside_lip_') and first_landing['grounded'], 'outside route lands on the deliberate receiving lip')
    later = outside['rows'][outside['landing_tick'] + 1:]
    check(any(not r['grounded'] for r in later) and any(r['grounded'] and r['p'][0] > 223 for r in later), 'receiving-lip landing flows through a genuine next takeoff and another landing')
    check(outside['style']['by_kind'].get('gap', {}).get('n', 0) > safe['style']['by_kind'].get('gap', {}).get('n', 0), 'outside line earns an additional existing generic gap event')
    check(outside['style']['identity'] == safe['style']['identity'], 'all lines use the same unchanged scorer, no location bonus')
    return {'ok': all(c['ok'] for c in checks), 'checks': checks, 'exits': exits, 'skill': {k: {x: y for x, y in v.items() if x != 'rows'} for k, v in skill.items()}, 'limits': ['high-versus-low speed comparison changes steering as stated; same-low old/new isolates support availability', 'local skill fixture begins at rest on the real quay; full course normal spawn is a separate proof', 'recordings are source/headless evidence, not native presentation or enjoyment']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.base)
    args.out.write_text(json.dumps(result, indent=2) + '\n')
    for row in result['checks']:
        print(('PASS ' if row['ok'] else 'FAIL ') + row['check'])
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
