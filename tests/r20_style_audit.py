#!/usr/bin/env python3
"""independently audit earned directional observations, wire events and frozen source hashes."""
import argparse
from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import subprocess
import sys

BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def equivalent(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(equivalent(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(equivalent(x, y) for x, y in zip(a, b))
    if type(a) in (int, float) and type(b) in (int, float):
        # godot JSON text rounds a double to 14 significant digits; binary tick columns stay frozen.
        return math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-13)
    return a == b


def audit(root, out, repo):
    reader = module(root / 'tools/analyze-r16-runs.py', 'r20_strict_reader')
    analysis = module(root / 'tools/analyze-r20-playtest.py', 'r20_direction_reference')
    raw = (out / 'r19_style.gd').read_text()
    rule_text = re.search(r'"direction":\s*\{([^}]+)\}', raw).group(1)
    rules = {k: float(v) for k, v in re.findall(r'"([a-z_]+)":\s*(-?\d+(?:\.\d+)?)', rule_text)}
    checks = []
    recordings = []
    reconstructed = 0
    for path in sorted((out / 'stack/episodes').glob('*.json')):
        fixture = json.loads(path.read_text())
        name = path.stem
        rows = fixture['observations']
        for record in fixture['recordings']:
            rec = reader.read(Path(record['path']))
            assert rec.ok, rec.errors
            assert equivalent(rec.header, record['header']), 'cross-reader header ' + name
            assert equivalent(rec.seal, record['seal']), 'cross-reader seal ' + name
            assert equivalent(rec.events, record['events']), 'cross-reader events ' + name
            assert [e['q'] for e in rec.events] == list(range(len(rec.events)))
            assert rec.seal['counts']['events'] == len(rec.events)
            scored = [e['d'] for e in rec.events if e['k'] == 'style']
            diag = [e['d'] for e in rec.events if e['k'] == 'direction']
            kinds = {}
            for event in scored:
                if event['v'] == 2:
                    m = event['m']
                    unit = 160 if event['kind'] == 'backward_bhop_bank' else 50
                    assert event['kind'] in {'backward_bhop_bank', 'sideways_bhop_bank'}
                    assert event['points'] == event['base'] == unit * m['hops'] * (m['hops'] - 1) // 2
                    assert m['unit'] == unit and m['formula'] == 'unit*n*(n-1)/2'
                    assert event['mult'] == event['combo_mult'] == event['direction_mult'] == 1 and event['combo'] == 0
                    assert m['end_ups'] >= 300 and m['start_tick'] < m['last_hop_tick'] <= event['tick']
                    index = rec.columns['tick'].index(event['tick'])
                    assert math.hypot(rec.columns['actual_v_x'][index], rec.columns['actual_v_z'][index]) / reader.U >= 300
                else:
                    assert event['v'] == 1 and event['kind'] in {'speed', 'sync', 'gap', 'edge', 'near_miss', 'crouch_save'}
                    assert event['direction_mult'] == 1 and event['mult'] == event['combo_mult']
                    # preserve the original v1 limits; dedicated v2 banks never pass this branch.
                    assert type(event['base']) is int and 0 < event['base'] <= 1500
                    assert type(event['points']) is int and 0 < event['points'] <= 18000
                row = kinds.setdefault(event['kind'], {'n': 0, 'points': 0})
                row['n'] += 1
                row['points'] += event['points']
            assert sum(e['points'] for e in scored) == rec.seal['outcome']['style']['score']
            assert kinds == rec.seal['outcome']['style']['by_kind']
            for d in diag:
                assert d['record_kind'] == 'direction' and 'points' not in d and 'base' not in d and 'mult' not in d
                unit = 160 if d['direction'] == 'backward_bhop' else 50
                assert d['pending'] == unit * d['hops'] * (d['hops'] - 1) // 2
                if d['kind'] == 'direction_lost':
                    if d['reason'] == 'stall':
                        index = rec.columns['tick'].index(d['tick'])
                        speed = math.hypot(rec.columns['actual_v_x'][index], rec.columns['actual_v_z'][index]) / reader.U
                        assert speed < 300, ('stall diagnostic above actual threshold', name, d['tick'], speed)
                        assert not any(e['v'] == 2 and e['tick'] == d['tick'] for e in scored)
                    elif d['reason'] in {'restart', 'practice', 'respawn', 'settings', 'map', 'preset', 'loadout', 'quit'}:
                        assert any(e['k'] == d['reason'] and e['t'] == d['tick'] for e in rec.events), ('loss lacks actual lifecycle edge', name, d)
                if d['kind'] == 'direction_banked' and d['pending'] > 0:
                    assert sum(e['v'] == 2 and e['tick'] == d['tick'] and e['points'] == d['pending'] and e['m']['reason'] == d['reason'] for e in scored) == 1
            # pure observation episodes have no pre-sample lifecycle placement/settings edge.
            if name in {'long_back', 'long_side', 'facing', 'ground', 'stall', 'loop', 'heading', 'forward', 'idle', 'walk', 'tiny', 'finish'}:
                observed = analysis.direction(rec, reader, rules)
                expected = [(r['sample']['tick'], r['kind'], r['chain']) for r in observed['timeline'] if r['event'] == 'landing' and r['valid']]
                actual = [(d['tick'], d['direction'], d['hops']) for d in diag if d['kind'] == 'direction_pending']
                assert actual == expected, ('R19 eligibility reconstruction differs', name, actual, expected)
                reconstructed += len(actual)
            recordings.append({'path': str(rec.path), 'sha256': digest(rec.path), 'ticks': len(rec.columns['tick']), 'style_events': len(scored),
                               'direction_diagnostics': len(diag), 'score': rec.seal['outcome']['style']['score']})
        assert all(row['score'] == row['event_total'] for row in rows), 'live score includes unbanked points'
        checks.append({'fixture': name, 'ok': True, 'samples': len(rows), 'input_ticks': len(fixture['tape'])})
    frozen = {}
    for pattern in ['r14_*.gd', 'r15_*.gd', 'spillway_*.gd', 'momentum_*.gd', 'r16_run_*.gd', 'r16_ghost.gd', 'r16_experiment_player.gd']:
        for path in (root / 'scripts').glob(pattern):
            old = subprocess.check_output(['git', 'show', BASE + ':projects/foldrunner/scripts/' + path.name], cwd=repo)
            assert hashlib.sha256(old).hexdigest() == digest(path), 'frozen source changed: ' + path.name
            frozen['scripts/' + path.name] = digest(path)
    assert reconstructed >= 40
    return {'ok': True, 'fixtures': checks, 'recordings': recordings, 'reconstructed_eligible_hops': reconstructed, 'frozen_sources': frozen,
            'reference_scorer_sha256': digest(out / 'r19_style.gd'), 'source_reference_commit': BASE,
            'limits': 'float32 observation reconstruction proves recorded eligibility, not replay determinism or native GPU appearance'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--repo', type=Path, default=Path.cwd())
    args = parser.parse_args()
    result = audit(args.source, args.run, args.repo)
    (args.run / 'AUDIT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'ok': result['ok'], 'fixtures': len(result['fixtures']), 'recordings': len(result['recordings']), 'reconstructed_eligible_hops': result['reconstructed_eligible_hops']}))


if __name__ == '__main__':
    main()
