#!/usr/bin/env python3
"""audit earned Saltglass telemetry, original reader bytes and fixed-input replay.

python3 -I tests/r19_surf_audit.py --run DIR --replay DIR --out FILE
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def trace(path):
    with gzip.open(path / 'trace.jsonl.gz', 'rt') as stream:
        return [json.loads(line) for line in stream]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--replay', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    checks = []

    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})

    summary = json.loads((args.run / 'summary.json').read_text())
    geometry = json.loads((args.run / 'geometry.json').read_text())
    rows = trace(args.run)
    replay = trace(args.replay)
    check(summary['pass'] and summary['finish_kind'] == 'clean', 'actual host clean course finish')
    check(40 <= summary['elapsed'] <= 70 and summary['respawns'] == 0, '40–70s continuous route without respawns')
    check(summary['runner'] == 'res://scripts/r15_source_player.gd' and summary['physics_hz'] == summary['engine_hz'] == 128,
          'real frozen source runner, F2 at exact 128 Hz')
    check(summary['rate_mismatch_ticks'] == summary['actual_v_mismatches'] == 0, 'no rate or body-travel mismatch')
    check(geometry['ok'] and geometry['hash'] == summary['geometry_hash'] and len(geometry['pieces']) == summary['piece_count'],
          'every physical convex matches the hashed manifest and size bound')
    check(geometry['steep_pieces'] == 8 and geometry['max_extent_m'] <= 32, 'all steep pieces real and all pieces at most32m per axis')
    check(len(rows) == len(replay) and all(a == b for a, b in zip(rows, replay)), 'every telemetry field equals fixed-input replay at every tick')
    check(all(row['tick'] == i for i, row in enumerate(rows)), 'one observation per consecutive driver tick')
    contact = [row for row in rows if row['surf_contacts']]
    check(all(not row['grounded'] for row in contact), 'steep-plane contact never treated as walkable ground')
    check(all(.45 < c['normal'][1] < .65 for row in contact for c in row['surf_contacts']), 'actual contact normals steeper than walkable')
    check(all(row['loss_u'] < 20 for row in summary['seam_losses']) and len(summary['seam_losses']) == 6, 'all six fin seams crossed without a20u/s speed kill')
    seam_end_hits = []
    nonblocking_end_hits = []
    for row in rows:
        for c in row['motion']['contacts']:
            if c['body'].startswith('Surf_') and abs(c['normal'][2]) > .5 and abs(c['normal'][1]) < .3:
                # the outer entry/exit faces are reported separately from the internal joins.
                z = c['position'][2]
                if any(abs(z - seam) < .04 for seam in [-63, -42, -21]):
                    (seam_end_hits if c.get('blocking', True) else nonblocking_end_hits).append(row['tick'])
    check(not seam_end_hits, 'no blocking internal vertical fin-end collision on the route')
    check(len(summary['hops']) >= 12 and summary['style']['by_kind'].get('gap', {}).get('n', 0) >= 8,
          'meaningful hop chain and natural gap style events')
    # scan the owned controller/map code for direct body, view, progress or physics writes.
    patterns = [r'\bplayer\.(?:position|global_position|velocity|yaw|pitch|transform|global_transform)\s*(?:[+*/-]?=)(?!=)',
                r'\bgame\.(?:checkpoint_index|elapsed|finished|_started|stage_times)\s*(?:[+*/-]?=)(?!=)',
                r'\bplayer\.(?:set|reset_to|apply_settings)\s*\(',
                r'\bgame\.(?:respawn|restart_run|practise_stage|_finish)\s*\(']
    write_hits = []
    sources = {}
    for name in ['scripts/r19_surf_level.gd', 'scripts/r19_course_geometry.gd', 'tests/r19_surf_driver.gd',
                 'tests/r19_surf_route.gd', 'tests/r19_surf_host.gd', 'tests/r19_surf_recovery.gd',
                 'tests/r14_practice_driver.gd']:
        path = PROJECT / name
        sources[name] = digest(path)
        for n, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith('#'):
                continue
            if any(re.search(pattern, line) for pattern in patterns):
                write_hits.append(f'{name}:{n}:{line}')
    check(not write_hits, 'owned scripts and inherited controller contain no direct body/view/progress writes')
    map_text = (PROJECT / 'scripts/r19_surf_level.gd').read_text()
    check(not re.search(r'func\s+_(?:physics_process|process|input)\b|Area3D\.new|style\.\w+\(', map_text),
          'course has no runtime movement callback, hidden trigger or authored score call')
    spec = importlib.util.spec_from_file_location('original_r16_reader', PROJECT / 'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    record_path = Path(summary['recordings'][0]['path'])
    rec = reader.read(record_path)
    check(rec.ok and summary['recordings'][0]['ok'] and summary['recordings'][0]['clean_finish']['ok'], 'both original Python and Godot readers accept clean complete recording')
    columns = rec.columns
    check(all(hz == 128 for hz in columns['physics_hz']) and all(dt == 1 / 128 for dt in columns['dt']), 'recorded per-tick rate and delta are exactly128Hz')
    check(all(i == tick for i, tick in enumerate(columns['tick'])), 'recording has every tick from normal spawn')
    check(rec.header['identity']['map'] == 'saltglass' and rec.header['identity']['preset'] == 'server128', 'independent map and F2 recording identity')
    # align on the first earned horizontal movement, after the documented33-tick settle.
    offsets = []
    for offset in range(30, 37):
        count = min(len(rows), len(columns['p_x']) - offset)
        if count == len(rows) and all(rows[i]['p'] == [columns['p_x'][i + offset], columns['p_y'][i + offset], columns['p_z'][i + offset]] for i in range(count)):
            offsets.append(offset)
    check(bool(offsets), 'recorded positions exactly equal all retained post-step telemetry')
    speeds = [row['motion']['actual_speed_u'] for row in rows]
    # initial acceleration and settling are excluded; no input waits are inserted on course.
    slow_ticks = sum(speed < 150 for row, speed in zip(rows, speeds) if row['elapsed'] > 1)
    check(slow_ticks == 0, 'no on-course waiting or speed stalls below150u/s after initial acceleration')
    surf = {}
    for fin in ['west', 'east']:
        samples = [row for row in contact if any(fin in c['body'] for c in row['surf_contacts'])]
        surf[fin] = {'contact_ticks': len(samples), 'entry_speed_u': samples[0]['motion']['actual_speed_u'],
                     'exit_speed_u': samples[-1]['motion']['actual_speed_u'], 'entry': samples[0]['p'], 'exit': samples[-1]['p'],
                     'contact_travel_m': abs(samples[-1]['p'][2] - samples[0]['p'][2])}
    result = {'ok': all(c['ok'] for c in checks), 'checks': checks, 'elapsed_s': summary['elapsed'],
              'samples': len(rows), 'recorded_ticks': len(columns['tick']), 'recording_offset': offsets,
              'recording_sha256': digest(record_path), 'sources_sha256': sources,
              'geometry_hash': summary['geometry_hash'], 'surf': surf, 'hops': len(summary['hops']),
              'peak_speed_u': max(speeds), 'slow_ticks_after_first_second': slow_ticks, 'style': summary['style'],
              'seam_losses': summary['seam_losses'], 'internal_end_collision_ticks': seam_end_hits, 'nonblocking_internal_end_contact_ticks': nonblocking_end_hits, 'write_hits': write_hits,
              'limits': ['coordinate-aware controller proves one line, not discovery or enjoyment',
                         'headless verification does not prove native rendering or Windows execution',
                         'regex source-write scan is supplemented by the actual travel mismatch check and source inspection']}
    args.out.write_text(json.dumps(result, indent=1) + '\n')
    for c in checks:
        print(('PASS ' if c['ok'] else 'FAIL ') + c['check'])
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
