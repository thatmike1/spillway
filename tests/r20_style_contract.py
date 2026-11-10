#!/usr/bin/env python3
"""bind an executed style proof to the parent parity/package integration contract."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

RUNTIME = ['scripts/r16_style.gd', 'scripts/r16_style_panel.gd', 'scripts/r18_style_panel.gd', 'scripts/r20_main.gd']
TESTS = ['tests/r20_style_stack.gd', 'tests/r20_style_ui.gd', 'tests/r20_style_check.py', 'tests/r20_style_audit.py']
BANK_REASONS = ['facing', 'ground_dwell', 'no_motor_jump', 'flight_timeout', 'flight_short', 'travel_short', 'rise_short', 'fall_short', 'efficiency', 'heading', 'novelty', 'finish']
LOSS_REASONS = ['stall', 'inactive', 'respawn', 'teleport', 'auto:teleport', 'auto:tick_gap', 'restart', 'practice', 'map', 'preset', 'loadout', 'quit', 'settings', 'spawn']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def object_schema(properties):
    return {'type': 'object', 'required': list(properties), 'additionalProperties': False, 'properties': properties}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    run, out = args.run.resolve(), args.out.resolve()
    root = Path(__file__).resolve().parents[1]
    result = read(run / 'RESULTS.json')
    assert result['ok'] and not result.get('cases')
    manifest = read(run / 'SOURCE.json')
    proof = read(run / 'stack/summary.json')
    observer = read(run / 'observer/summary.json')
    audit = read(run / 'AUDIT.json')
    assert proof['ok'] and observer['ok'] and audit['ok']
    assert len(proof['fixtures']) >= 29 and proof['forward_samples'] > 1000
    assert proof['identity']['version'] == 'r20-style-stack-1' and proof['identity']['event_format'] == 2
    assert proof['identity'] != proof['baseline_identity']
    for path in RUNTIME + TESTS:
        assert sha(root / path) == manifest['sha256'][path], 'live source differs from executed proof: ' + path
    for path in ['tools/analyze-r16-runs.py']:
        old = subprocess.check_output(['git', 'show', manifest['baseline_commit'] + ':projects/foldrunner/' + path], cwd=root)
        expected = hashlib.sha256(old).hexdigest()
        assert sha(root / path) == manifest['sha256'][path] == expected
        audit['frozen_sources'][path] = expected
    old_project = subprocess.check_output(['git', 'show', '9cca4adf3ec8cb81befbb6d7e518df0634aa6596:projects/foldrunner/project.godot'], cwd=root)
    assert sha(root / 'project.godot') == manifest['sha256']['project.godot'] == hashlib.sha256(old_project).hexdigest()
    assert manifest['sha256']['scripts/r20_main.gd'] == 'a66c96ad75725570dc0ddb36f3f434226ebed60f62d7485d78073005bfb8f2d1'
    number, integer, text = {'type': 'number'}, {'type': 'integer'}, {'type': 'string'}
    one = {'const': 1.0}
    measures = object_schema({
        'direction': {'enum': ['backward_bhop', 'sideways_bhop']}, 'hops': {'type': 'integer', 'minimum': 2},
        'unit': {'enum': [160, 50]}, 'formula': {'const': 'unit*n*(n-1)/2'}, 'reason': {'enum': BANK_REASONS},
        'start_tick': {'type': 'integer', 'minimum': 0}, 'last_hop_tick': {'type': 'integer', 'minimum': 0},
        'end_ups': {'type': 'number', 'minimum': 300}})
    scored = object_schema({
        'v': {'const': 2}, 'kind': {'enum': ['backward_bhop_bank', 'sideways_bhop_bank']},
        'tick': {'type': 'integer', 'minimum': 0}, 'time_s': number, 'elapsed': number,
        'points': {'type': 'integer', 'minimum': 1}, 'base': {'type': 'integer', 'minimum': 1},
        'mult': one, 'direction_mult': one, 'combo_mult': one, 'combo': {'const': 0},
        'label': {'enum': ['Backwards banked', 'Half-sideways banked']}, 'm': measures, 'geo': {'const': {}},
        'p': {'type': 'array', 'items': number, 'minItems': 3, 'maxItems': 3}, 'clean': {'type': 'boolean'}})
    diagnostic = object_schema({
        'record_kind': {'const': 'direction'}, 'v': {'const': 1},
        'kind': {'enum': ['direction_pending', 'direction_banked', 'direction_lost']},
        'reason': {'type': 'string', 'minLength': 1}, 'serial': {'type': 'integer', 'minimum': 1},
        'tick': integer, 'time_s': number, 'direction': {'enum': ['backward_bhop', 'sideways_bhop']},
        'hops': {'type': 'integer', 'minimum': 1}, 'pending': {'type': 'integer', 'minimum': 0},
        'unit': {'enum': [160, 50]}, 'formula': {'const': 'unit*n*(n-1)/2'}, 'm': {'type': 'object'}})
    fixture_results = []
    raw = {}
    for name, fixture in proof['fixtures'].items():
        path = run / 'stack/episodes' / (name + '.json')
        data = read(path)
        for rec in data['recordings']:
            assert rec['header']['metadata']['scoring']['style'] == proof['identity']
            assert 'r20-style' not in json.dumps(rec['header']['identity'])
        fixture_results.append({'name': name, 'samples': fixture['samples'], 'scored_events': fixture['events'], 'banks': fixture['banks'],
                                'solid_geometry_hash': fixture['fixture_sha256'], 'fixture_and_tape_sha256': hashlib.sha256(json.dumps({'fixture': data['fixture'], 'tape': data['tape']}, sort_keys=True, separators=(',', ':')).encode()).hexdigest(),
                                'observations_sha256': sha(path), 'path': str(path)})
        raw[str(path)] = sha(path)
    for item in audit['recordings']:
        raw[item['path']] = item['sha256']
    for name in ['SOURCE.json', 'RESULTS.json', 'AUDIT.json', 'READERS.json', 'stack/summary.json', 'observer/summary.json', 'ui720/summary.json', 'ui1080/summary.json', 'r16/summary.json']:
        raw[str(run / name)] = sha(run / name)
    contract = {
        'format': 'spillway-r20-style-component-1', 'ok': True, 'scope': 'item2 source/headless integration; native appearance and release are parent-owned',
        'identity': proof['identity'], 'identity_key': proof['identity_key'],
        'source_sha256': {p: manifest['sha256'][p] for p in RUNTIME + TESTS},
        'configured_project_sha256': manifest['sha256']['project.godot'], 'configured_project_reference': '9cca4adf3ec8cb81befbb6d7e518df0634aa6596',
        'reference': {'git_commit': manifest['baseline_commit'], 'scorer_sha256': proof['baseline_sha256'], 'identity': proof['baseline_identity']},
        'frozen_sources_sha256': audit['frozen_sources'],
        'formula': {'literal': 'unit*n*(n-1)/2', 'first_hop': 'arms at zero', 'increment': 'unit*(n-1)', 'units': {'backward_bhop': 160, 'sideways_bhop': 50},
                    'examples': {str(n): {'backward_bhop': 160*n*(n-1)//2, 'sideways_bhop': 50*n*(n-1)//2} for n in [1, 6, 12, 20]}, 'game_choice': True, 'gameplay_cap': None},
        'eligibility': {'min_ups': 300, 'back_dot': -.75, 'side_dot_exclusive_abs': .75, 'motor_jump_required': True, 'min_air_s': .18, 'max_air_s': 1.2,
                        'min_track_m': 3, 'min_rise_m': .25, 'min_fall_m': .20, 'min_efficiency': .85, 'min_heading_dot': .5, 'max_ground_s': .06, 'novelty_radius_m': 4,
                        'novelty_survives_discontinuity': True, 'novelty_shared_by_directions': True},
        'bank_reasons': BANK_REASONS, 'known_loss_reasons': LOSS_REASONS, 'other_explicit_discontinuity_reason': 'also loses; never banks',
        'priority': 'low actual speed loses before any normal end or first-inclusive finish can bank',
        'pause': 'suspend sampling and style time; preserve previous actual sample and valid evidence; validate next actual sample; no restoration or synthetic hop',
        'scored_v2_schema': scored, 'diagnostic_v1_schema': diagnostic,
        'semantic_constraints': ['v2 points == base == unit*hops*(hops-1)//2', 'direction/kind/unit/label must agree', 'bank tick equals outer capture tick',
                                 'start_tick < last_hop_tick <= bank tick', 'end_ups matches actual horizontal speed at bank sample',
                                 'v2 bank added exactly once to score and by_kind; diagnostics excluded', 'v1 ordinary direction_mult=1 and mult=combo_mult; legacy bounds unchanged'],
        'wire': {'container_format': 'foldrunner-r16-run', 'container_version': 1, 'scored_outer_kind': 'style', 'diagnostic_outer_kind': 'direction',
                 'diagnostic_sources': ['capture', 'event'], 'diagnostic_tick_rule': 'last observed stack tick may precede outer capture; lifecycle boundary has its own event',
                 'event_order': 'dense q for every event; tally only k=style, not every s=capture', 'seal': 'score and by_kind sum scored events only'},
        'api': {'step': 'returns scored events plus explicit record_kind=direction diagnostics; events field/recent/last/summary are scored only',
                'discard_pending': 'discontinuity then drain all queued diagnostics; host records each before seal', 'drain_diagnostics': 'clears and returns non-scored queue',
                'reset': 'new attempt resets score/pending/novelty/diagnostics', 'discontinuity': 'non-pause loss preserves banked score and novelty; pause/resume suspend'},
        'snapshot_direction': {'kind': 'direction category or empty', 'hops': 'integer', 'pending': 'integer', 'unit': '0/160/50', 'formula': 'literal', 'suspended': 'boolean', 'last': 'empty or bank/loss diagnostic'},
        'snapshot_diag_direction': {'last': 'verdict/tick/optional measurements', 'visited_landings': 'integer', 'flight': 'empty or from:[x,y,z],peak_y,track_m,air_s'},
        'fixtures': fixture_results, 'gates': {'stack': len(proof['checks']), 'forward_identical_samples': proof['forward_samples'],
                                          'r16': read(run / 'r16/summary.json')['gates'], 'ui720': len(read(run / 'ui720/summary.json')['checks']),
                                          'ui1080': len(read(run / 'ui1080/summary.json')['checks']), 'recordings_cross_read': len(audit['recordings']),
                                          'reconstructed_eligible_hops': audit['reconstructed_eligible_hops']},
        'native_observer': {'script': 'res://tests/r20_style_stack.gd', 'args': ['--native', '--size=1280x720', '--out=ABSOLUTE_PARENT_OUTPUT', '--baseline=EXTRACTED_065f7b279_STYLE'],
                            'other_size': '1920x1080', 'headless_markers': observer['native_markers'], 'input': 'same earned key and float32 mouse driver, no staged score',
                            'outputs': ['native_bank-pending.png', 'native_bank-banked.png', 'native_loss-pending.png', 'native_loss-lost.png'], 'native_inspected_by_component': False},
        'contract_builder_sha256': sha(Path(__file__).resolve()), 'documentation_sha256': sha(root / 'docs/r20/STYLE.md'), 'raw_proof_sha256': raw, 'resources': {k: result[k] for k in ['peak_scratch_bytes', 'lowest_home_free_bytes', 'cap_bytes', 'floor_bytes']}}
    out.mkdir(parents=True, exist_ok=True)
    (out / 'CONTRACT.json').write_text(json.dumps(contract, indent=2) + '\n')
    for name in ['SOURCE.json', 'RESULTS.json', 'AUDIT.json', 'READERS.json']:
        shutil.copy2(run / name, out / name)
    (out / 'ACCEPTANCE.json').write_text(json.dumps({'ok': True, 'contract_sha256': sha(out / 'CONTRACT.json'), 'gates': contract['gates'], 'resources': contract['resources'],
                                                    'raw_proof': str(run), 'native_inspection': 'parent pending'}, indent=2) + '\n')
    print(json.dumps({'ok': True, 'contract': str(out / 'CONTRACT.json'), 'sha256': sha(out / 'CONTRACT.json'), 'gates': contract['gates']}))


if __name__ == '__main__':
    main()
