#!/usr/bin/env python3
"""check retained real physics evidence independently of the geometry builder."""
import argparse
import gzip
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    root = args.evidence
    result = read(root / 'RESULTS.json')
    assert result['scratch_removed']
    assert result['peak_checked_scratch_bytes'] <= 300 * 1024**2
    assert result['base_source_unchanged_during_run']
    assert result['owned_source_unchanged_during_run']
    assert result['geometry']['failed'] == 0
    checks = len(result['geometry']['checks'])
    parity = [row for row in result['runs'] if 'exact_movement_parity' in row]
    assert {row['name'] for row in parity} == {'breakwater-basic', 'breakwater-return', 'whiteout-basic', 'whiteout-crouch'}
    assert all(row['exact_movement_parity'] for row in parity)
    assert all(row['contact_differences_are_only_walkable_original_support'] for row in parity)
    checks += len(parity)
    reports = {row['case']: row for row in result['runs'] if 'case' in row}
    for map_id in ['breakwater', 'whiteout']:
        duck = reports[map_id + '-crouch']
        stand = reports[map_id + '-stand']
        assert duck['reason'] == 'passed' and not duck['blocking_contacts']
        assert stand['reason'] == 'blocked' and stand['blocking_contacts']
        assert not stand['opportunity_events']
        assert duck['takeoff']['speed_ups'] >= 240
        assert duck['setup']['movement_writes_after_setup'] == 0
        saves = [event for event in duck['opportunity_events'] if event['kind'] == 'crouch_save']
        assert len(saves) == 1
        event = saves[0]
        assert event['m']['airborne'] and event['m']['standing_intrusion_u'] > 0 and not event['m']['duck_contact']
        assert event['points'] >= 900
        assert event['geo']['obstacle']['path'].endswith('/Lintel')
        # passage occupancy: duck feet clear the sill, the actual head clears the lintel,
        # while the centre-anchored standing head would intersect it at these same poses.
        occupancy = [row for row in duck['crossing'] if abs(row['p'][2] - (-166 if map_id == 'breakwater' else -28)) < (0.28 + 32 * 0.0254) / 2]
        assert occupancy
        assert all(row['ducked'] and not row['grounded'] and row['p'][1] > 1.4 and row['p'][1] + 54 * 0.0254 < 3.05 for row in occupancy)
        assert any(row['p'][1] + (72 - 9) * 0.0254 > 3.05 for row in occupancy)
        # same delivered approach and takeoff inputs in the negative control, differing
        # only in crouch until the first standing collision changes the physical state.
        duck_tape = read(root / (map_id + '-crouch') / 'events.tape.json')['events']
        stand_tape = read(root / (map_id + '-stand') / 'events.tape.json')['events']
        stop = stand['blocking_contacts'][0]['tick']
        before_collision = lambda events: [e for e in events if int(e['tick']) < stop and e.get('key') != 'ctrl']
        assert before_collision(duck_tape) == before_collision(stand_tape)
        normal = reports[map_id + '-normal']
        assert normal['reason'] == 'passed' and not normal['all_overlay_contacts'] and not normal['opportunity_events']
        checks += 15
    thread = reports['breakwater-thread']
    assert thread['reason'] == 'passed' and not thread['all_overlay_contacts']
    assert thread['setup']['kind'] == 'authored stage practice'
    near = [event for event in thread['opportunity_events'] if event['kind'] == 'near_miss']
    assert len(near) == 1 and near[0]['points'] > 0
    assert near[0]['m']['thread'] and near[0]['m']['max_ups'] >= 380
    assert 0 < near[0]['m']['clear_u'] <= 8
    assert 0 < near[0]['m']['track_m'] <= 6
    assert thread['final'][2] < -201
    with gzip.open(root / 'breakwater-thread/trace.jsonl.gz', 'rt') as stream:
        rows = [json.loads(line) for line in stream]
    assert max((row['v'][0]**2 + row['v'][2]**2)**0.5 / 0.0254 for row in rows) > 380
    assert any('a' in row['held'] or 'd' in row['held'] for row in rows)
    checks += 8
    print(json.dumps({'ok': True, 'checks': checks, 'exact_movement_samples': sum(r['ticks_including_warmup'] for r in parity),
                      'full_contact_trace_difference_rows': sum(r['contact_difference_rows'] for r in parity),
                      'crouch_points': [reports[m + '-crouch']['opportunity_events'][0]['points'] for m in ['breakwater', 'whiteout']],
                      'near_miss_points': near[0]['points']}, indent=2))


if __name__ == '__main__':
    main()
