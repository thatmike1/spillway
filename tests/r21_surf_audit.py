#!/usr/bin/env python3
"""audit the production F2 route, lossless replay, contacts, recordings and failed departures."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def rows(directory):
    with gzip.open(directory / 'trace.jsonl.gz', 'rt') as stream:
        for line in stream:
            yield json.loads(line)


def audit(base):
    checks = []

    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})

    summary = json.loads((base / 'run/summary.json').read_text())
    geometry = json.loads((base / 'run/geometry.json').read_text())
    integration = json.loads((base / 'integration/integration.json').read_text())
    check(summary['pass'] and summary['finish_kind'] == 'clean' and summary['respawns'] == 0, 'configured production scene clean finish without respawns')
    check(40 <= summary['elapsed'] <= 70, 'continuous F2 line takes 40 to 70 seconds')
    check(summary['configured_scene'] == 'res://scenes/r21.tscn' and summary['configured_main'] == 'res://scripts/r21_main.gd', 'proof uses real R21 scene and main')
    check(summary['runner'] == 'res://scripts/r15_source_player.gd' and summary['physics_hz'] == summary['engine_hz'] == 128, 'unchanged real Source/F2 runner at 128 Hz')
    check(summary['actual_v_mismatches'] == summary['rate_mismatch_ticks'] == 0, 'actual body travel and physics rate agree')
    check(summary['build_label'] == 'Spillway R21' and 'Spillway R21' in summary['window_title'] and summary['startup'].startswith('r21: spillway-2026.11.11-r21;'), 'R21 production identity')
    check(integration['ok'], 'catalog, original-eight local ghost identities, Breakwater gate, old Saltglass rejection, experimental suffix and LookC integration')
    check(geometry['ok'] and geometry['hash'] == summary['geometry_hash'] and len(geometry['pieces']) == summary['piece_count'], 'all actual collision vertices match geometry manifest and identity')
    check(geometry['steep_pieces'] == 16 and geometry['max_extent_m'] <= 32.0001, 'sixteen steep fin prisms with bounded collider extents')
    check(all(x == 1 for x in geometry['flat_exits'].values()) and len(geometry['flat_exits']) == 4, 'both first landing decks are exactly flat')
    check(len(geometry['climbing']) == 9 and all(abs(p['height'] - (7.9 + .9 * i)) < .00001 for i, p in enumerate(geometry['climbing'])), 'nine salt pans climb 7.9 to 15.1 metres before the 15.5 m headrace')
    check(geometry['spawn_stage3_min_plan_gap_m'] > 45, 'the old nearby stage-three bridge is physically absent')

    first = {}
    last = {}
    landing = {}
    contact_pieces = set()
    seam_hits = []
    steep_ground = []
    slow_ticks = 0
    supports = set()
    compact = []
    equal_replay = True
    equal_look = True
    peak_speed = 0.0
    for index, (row, replay, old) in enumerate(itertools.zip_longest(rows(base / 'run'), rows(base / 'replay'), rows(base / 'old-look'))):
        equal_replay &= row is not None and row == replay
        equal_look &= row is not None and row == old
        if row is None:
            continue
        check_tick = row['tick'] == index
        if not check_tick:
            check(False, f'nonconsecutive tick at {index}')
        compact.append({k: row[k] for k in ['tick', 'p', 'reference_p', 'v', 'yaw', 'pitch', 'elapsed', 'checkpoint', 'respawns']})
        peak_speed = max(peak_speed, row['motion']['actual_speed_u'])
        if row['elapsed'] > 1 and row['motion']['actual_speed_u'] < 150:
            slow_ticks += 1
        if row['grounded']:
            supports.add(row['support'])
        if row['surf_contacts'] and row['grounded']:
            steep_ground.append(index)
        for c in row['surf_contacts']:
            fin = 'west' if 'west' in c['body'] else 'east'
            first.setdefault(fin, {'tick': index, 'feet': row['reference_p'], 'actual_feet': row['p'], 'contact': c['position'], 'normal': c['normal']})
            last[fin] = index
            contact_pieces.add(c['body'])
        for fin in ['west', 'east']:
            if fin in first and fin not in landing and row['grounded'] and index > first[fin]['tick']:
                landing[fin] = {'tick': index, 'support': row['support'], 'normal': row['support_normal'], 'feet': row['reference_p']}
        for c in row['motion']['contacts']:
            if c['body'].startswith('Surf_') and abs(c['normal'][2]) > .5 and abs(c['normal'][1]) < .3 and c.get('blocking', True):
                if any(abs(c['position'][2] - seam) < .04 for seam in range(-147, 0, 21)):
                    seam_hits.append(index)
    check(equal_replay, 'every telemetry field at every tick equals the saved ordered-input replay')
    check(equal_look, 'every telemetry field at every tick equals L-off replay')
    check(len(contact_pieces) == 16 and not steep_ground, 'actual contact on every fin piece without treating the face as walkable')
    check(set(first) == {'west', 'east'} and all(v['feet'][1] >= 18 * .8 and v['actual_feet'][1] >= 18 * .8 and v['contact'][1] >= 18 * .8 and .45 < v['normal'][1] < .65 for v in first.values()), 'both actual first surf contacts exceed 80 percent of crest with steep normals')
    check(set(landing) == {'west', 'east'} and all(v['support'].startswith(fin + '_landing_') and v['normal'][1] > .99999 for fin, v in landing.items()), 'first support after each fin is its flat exit deck')
    check(len(summary['seam_losses']) == 14 and all(s['loss_u'] < 20 for s in summary['seam_losses']) and not seam_hits, 'all fourteen internal joins crossed without a blocking end wall or 20 u/s speed kill')
    check(len(summary['hops']) >= 20 and summary['style']['by_kind'].get('gap', {}).get('n', 0) >= 3, 'real hop chains and physical gap events')
    check(slow_ticks == 0, 'no stalls below 150 u/s after the first course second')
    check(not any(s.startswith(('catch_', 'return_')) for s in supports), 'no route support on catch platforms or recovery ramps')

    spec = importlib.util.spec_from_file_location('r16_reader', PROJECT / 'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    path = Path(summary['recordings'][0]['path'])
    rec = reader.read(path)
    check(rec.ok and summary['recordings'][0]['ok'] and summary['recordings'][0]['clean_finish']['ok'], 'original Godot and Python strict readers accept the clean recording')
    c = rec.columns
    offsets = [offset for offset in range(30, 37) if len(c['p_x']) >= len(compact) + offset and all(row['p'] == [c['p_x'][i + offset], c['p_y'][i + offset], c['p_z'][i + offset]] for i, row in enumerate(compact))]
    check(len(offsets) == 1, 'recording aligns uniquely with every observed post-step position')
    if offsets:
        offset = offsets[0]
        aligned = all(row['v'] == [c['v_x'][i + offset], c['v_y'][i + offset], c['v_z'][i + offset]] and row['reference_p'] == [c['reference_p_x'][i + offset], c['reference_p_y'][i + offset], c['reference_p_z'][i + offset]] and row['yaw'] == c['yaw'][i + offset] and row['pitch'] == c['pitch'][i + offset] and row['checkpoint'] == c['checkpoint'][i + offset] and row['respawns'] == c['respawns'][i + offset] for i, row in enumerate(compact))
        check(aligned, 'recorded velocity, reference feet, view, progress and falls align to observations')
    check(all(x == 128 for x in c['physics_hz']) and all(x == 1 / 128 for x in c['dt']) and list(range(len(c['tick']))) == c['tick'], 'recording has consecutive ticks and exact 128 Hz delta')
    check(rec.header['metadata']['build'] == 'spillway-2026.11.11-r21' and rec.header['metadata']['build_label'] == 'Spillway R21', 'recording metadata is R21')
    # raw keyboard/mouse records preserve the applied tape order. action echoes are separate.
    tape = json.loads((base / 'run/events.tape.json').read_text())
    raw_inputs = []
    names = {87: 'w', 65: 'a', 83: 's', 68: 'd', 32: 'space'}
    for i, kind in enumerate(rec.inputs['kind']):
        if kind == 1 and rec.inputs['code'][i] in names:
            raw_inputs.append({'tick': rec.inputs['tick'][i] - 33, 'key': names[rec.inputs['code'][i]], 'edge': 'press' if rec.inputs['flags'][i] & 1 else 'release'})
        elif kind == 3:
            raw_inputs.append({'tick': rec.inputs['tick'][i] - 33, 'mouse': [rec.inputs['x'][i], rec.inputs['y'][i]]})
    expected = [e for e in tape['events'] if e['tick'] < len(compact)]
    check(raw_inputs[:len(expected)] == expected, 'strict reader retains every ordered applied key/mouse input')

    probes = {}
    for name in ['west-bail', 'east-bail', 'turnaround', 'turnaround-diagonal']:
        probe = json.loads((base / name / 'probe.json').read_text())
        probe_summary = json.loads((base / name / 'summary.json').read_text())
        probes[name] = probe
        check(probe['ok'] and probe_summary['pass'] and not probe_summary['finished'] and probe_summary['respawns'] == 1, name + ' physically falls and respawns at the correct checkpoint')
        if 'bail' in name:
            prefix_matches = all(a == b for a, b in itertools.islice(zip(rows(base / 'run'), rows(base / name)), probe['departure_tick']))
            check(prefix_matches, name + ' shares the intended route exactly until controlled early departure')
            check(probe['lowest_y'] < -10 and not probe['reached_stage3'], name + ' has no walkable lower recovery')
        else:
            check(not probe['reached_stage3'] and probe_summary['max_speed_u'] < 400, name + ' cannot cheaply reach the final stage or finish')

    patterns = [r'\bplayer\.(?:position|global_position|velocity|yaw|pitch|transform|global_transform)\s*[+*/-]?=(?!=)', r'\bgame\.(?:checkpoint_index|elapsed|finished|_started|stage_times)\s*[+*/-]?=(?!=)', r'\bplayer\.(?:set|reset_to|apply_settings)\s*\(', r'\bgame\.(?:respawn|restart_run|practise_stage|_finish)\s*\(']
    write_hits = []
    sources = {}
    source_names = ['scripts/r21_surf_level.gd', 'scripts/r21_main.gd', 'scripts/r21_map_catalog.gd', 'scenes/r21.tscn', 'scripts/r19_course_geometry.gd', 'tests/r21_surf_route.gd', 'tests/r21_surf_probes.gd', 'tests/r14_practice_driver.gd', 'scripts/r15_source_player.gd', 'scripts/r14_source_motion.gd']
    for name in source_names:
        file = PROJECT / name
        sources[name] = digest(file)
        for n, line in enumerate(file.read_text().splitlines(), 1):
            if name.startswith('scripts/r15_source') or name.startswith('scripts/r14_source') or line.lstrip().startswith('#'):
                continue
            if any(re.search(pattern, line) for pattern in patterns):
                write_hits.append(f'{name}:{n}:{line}')
    check(not write_hits, 'owned course/main/controller and inherited input controller contain no body/view/progress writes')
    course = (PROJECT / 'scripts/r21_surf_level.gd').read_text()
    check(not re.search(r'func\s+_(?:physics_process|process|input)\b|Area3D\.new|style\.\w+\(', course), 'no authored forces, hidden runtime route or checkpoint triggers')
    checks.append({'ok': True, 'check': 'native visual feel, fastest-human-route and universal skip impossibility are outside this component proof'})
    return {'ok': all(x['ok'] for x in checks), 'checks': checks, 'elapsed_s': summary['elapsed'], 'samples': len(compact), 'recording_offsets': offsets, 'recording_sha256': digest(path), 'input_sha256': digest(base / 'run/events.tape.json'), 'sources_sha256': sources, 'geometry_hash': summary['geometry_hash'], 'first_contacts': first, 'first_support_after_fin': landing, 'hops': len(summary['hops']), 'peak_speed_u': peak_speed, 'slow_ticks': slow_ticks, 'seam_losses': summary['seam_losses'], 'blocking_internal_end_hits': seam_hits, 'write_hits': write_hits, 'probes': probes, 'limits': ['one coordinate-aware input line and exact fixed-input replay, not discovery or a fastest human line', 'representative early departures fall; skilled flings and skips remain possible', 'native presentation, exported packages and release approval belong to parent']}


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
