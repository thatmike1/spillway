#!/usr/bin/env python3
"""Audit retained standard-executor contacts without copying or re-rendering routes."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json

P = Path(__file__).resolve().parents[1]
ROOT = Path('/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15')

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    result = {'scope': 'independent reread of retained root standard-executor traces; no fresh execution', 'routes': []}
    cases = [(ROOT/'whiteout-integration/replays'/n, 'whiteout/'+n) for n in
             ['ordinary', 'earned', 'gantry', 'basin_recovery', 'cloud_recovery', 'f5-ordinary', 'f5-earned']]
    cases += [(ROOT/'breakwater-r15-host/pole-fix-final'/n, 'breakwater/'+n) for n in
              ['server128-ordinary', 'server128-earned', 'server128-alley_recovery', 'server128-harbour_recovery', 'server128_aa1000-ordinary']]
    for folder, name in cases:
        trace = folder/'evaluator/trace.jsonl.gz'
        report = json.loads((folder/'evaluator/report.json').read_text())
        assert report['end'] == 'completed' and report['neutral'] and report['cleanup']['clean'] and not report['integrity_flags']
        assert all(report[k]['ok'] for k in ['delivery','rate','order'])
        r = {'case': name, 'path': str(trace), 'trace_sha256': sha(trace), 'ticks': 0, 'side_ticks': 0,
             'blocking_side_ticks': 0, 'side_hits': [], 'landings': [], 'respawns': [], 'duck_events': []}
        last_resp = 0
        with gzip.open(trace, 'rt') as f:
            for line in f:
                row = json.loads(line)
                if row['phase'] != 'tape':
                    continue
                r['ticks'] += 1
                m = row['post']['motion_state']
                assert m['motor_version'] == 'r15-source-crouch-2'
                assert m['cvars']['hull_width'] == 32 and m['cvars']['hull_height'] == 72 and m['cvars']['duck_hull_height'] == 54
                assert m['rate_matches'] and m['physics_hz'] == 128 and m['cvars']['sensitivity'] == 2.5
                assert m['cvars']['sv_airaccelerate'] == (1000 if 'f5-' in name or 'aa1000' in name else 100)
                sides = [c for c in m['contacts'] if abs(c['normal'][1]) < 0.7]
                if sides:
                    r['side_ticks'] += 1
                    r['blocking_side_ticks'] += int(any(c['blocking'] for c in sides))
                    r['side_hits'].append({'tick': row['tick'], 'p': row['post']['p'], 'contacts': sides,
                                          'start_v_m': m['start_velocity'], 'post_v_m': m['post_contact_velocity'], 'ledger': m['ledger']})
                if 'land' in m['events']:
                    r['landings'].append({'tick': row['tick'], 'p': row['post']['p'], 'hop': m['last_hop']})
                if m['duck']['events']:
                    r['duck_events'].append({'tick': row['tick'], 'events': m['duck']['events'], 'p': row['post']['p']})
                if row['game']['respawns'] > last_resp:
                    r['respawns'].append({'tick': row['tick'], 'game': row['game'], 'p': row['post']['p']})
                    last_resp = row['game']['respawns']
                r['last'] = row['game']
                r['settings'] = m['cvars']
        assert r['last']['finished']
        r['executor_checks'] = {k: report[k] for k in ['end', 'delivery', 'rate', 'order', 'neutral', 'cleanup', 'integrity_flags']}
        result['routes'].append(r)
    sources = json.loads((ROOT/'whiteout-integration/SOURCES.json').read_text())
    keys = ['scripts/r15_main.gd', 'scripts/r15_source_player.gd', 'scripts/r15_presets.gd', 'scripts/r15_maps.gd',
            'scripts/r14_source_player.gd', 'scripts/r14_source_motion.gd', 'scripts/r15_whiteout_level.gd',
            'scripts/r15_whiteout_art.gd', 'scripts/r15_breakwater_level.gd', 'scripts/r15_breakwater_art.gd']
    result['source_comparison_with_whiteout_root_manifest'] = {
        k: {'current': sha(P/k), 'retained': sources.get(k), 'equal': sources.get(k) == sha(P/k)} for k in keys}
    result['total_ticks'] = sum(r['ticks'] for r in result['routes'])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'ticks': result['total_ticks'], 'routes': [{'case': r['case'], 'side_ticks': r['side_ticks'], 'finish': r['last']} for r in result['routes']]}, indent=2))

if __name__ == '__main__':
    main()
