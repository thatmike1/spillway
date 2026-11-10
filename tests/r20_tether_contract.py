#!/usr/bin/env python3
"""bind the accepted Tether component to actual sources, raw attempts and parent seams."""
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    run = args.run.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = read(run / 'SOURCE.json')
    audit = read(run / 'AUDIT.json')
    assert audit['ok']
    owned = {name: digest for name, digest in source['sha256'].items()
             if (name in {'scripts/r20_main.gd', 'scripts/r20_map_catalog.gd', 'scenes/r20.tscn'}
             or name.startswith(('scripts/r20_tether', 'scripts/r20_hud.', 'tests/r20_tether'))) and not name.endswith('.uid')}
    for name, digest in owned.items():
        assert sha(PROJECT / name) == digest, 'accepted source differs from final checkout: ' + name
    # the full baseline comparison is against the actual executed snapshot, including every
    # old project path. accepted pre-component exceptions must still match committed HEAD.
    spec = importlib.util.spec_from_file_location('tether_preservation', PROJECT / 'tools/check-r20-preservation.py')
    preservation = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(preservation)
    repo = PROJECT.parents[1]
    old = preservation.archive_manifest(repo, BASE)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    parent = preservation.archive_manifest(repo, head)
    intentional = {name: parent[name] for name in preservation.ALLOWED if name in old and parent[name] != old[name]}
    protected = preservation.compare(old, source['sha256'], intentional)
    assert protected['ok'], protected
    protected.update(baseline=BASE, accepted_parent_commit=head, intentional_sha256=intentional)
    write(out / 'PRESERVATION.json', protected)
    cues = {}
    for label in ['ground_timeout', 'obstructed', 'range', 'controls']:
        episode = json.loads(gzip.decompress((run / 'component' / (label + '.json.gz')).read_bytes()))
        for row in episode['observations']:
            experiment = row['motion']['experiment']
            if 'grapple_release' in experiment['events']:
                cue = experiment['tether']['last_cue']
                if cue:
                    assert cue['active'] and len(cue['pcm_sha256']) == 64
                    cues[cue['reason']] = cue
    assert set(cues) >= {'time', 'range', 'obstructed', 'released'}
    assert len({cues[k]['pcm_sha256'] for k in ['time', 'range', 'obstructed', 'released']}) == 4
    routes = {name: read(run / name / 'summary.json') for name in ['classic', 'pendulum', 'elastic', 'automatic', 'old_e']}
    route_proof = {name: {key: result[key] for key in ['pass', 'elapsed', 'ticks', 'attached_ticks', 'pull_ticks', 'rope_ticks', 'releases', 'identity', 'mechanics', 'geometry_hash', 'respawns']}
                   for name, result in routes.items()}
    write(out / 'ROUTES.json', route_proof)
    logs = []
    for path in sorted(run.parent.rglob('*.log')):
        if 'source' in path.parts or 'profiles' in path.parts:
            continue
        text = path.read_text(errors='replace')
        logs.append({'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size,
                     'failure_lines': [line for line in text.splitlines() if re.search(r'FAIL|SCRIPT ERROR:|ERROR:|AssertionError|RuntimeError|pass=false', line)][:15]})
    write(out / 'ATTEMPTS.json', {'logs': logs, 'classifications': [
        'component-01: test local Vector3 inference parse error; corrected before any acceptance',
        'component-02: overly strict slack assertion, wrong LOS fixture height and mistaken maxspeed pin; actual Tether section visibility bug fixed',
        'component-03/component-04/failed-suite01: range stress initially stayed under threshold or respawned against cached old kill bounds; fixed labelled initial geometry/bounds only',
        'failed-suite02: physical saved-input replay already exact, but raw relative column was re-scaled by the default tiny headless window; use configured 1280x720 window and compare all columns',
        'failed-suite03 and pendulum trials 01-03: first route entered finish before checkpoint contact or missed final deck; changed earned approach/release inputs, not geometry',
        'elastic trials 01-02: soft spring missed transfer decks; finalized explicit bounded 90/10/1800 tuning, then proved the three-anchor route',
        'failed-final04: all behavior checks passed but a test-only flat floor lacked surface metadata and emitted engine errors; corrected fixture metadata',
        'audit-01: an observer export stringified Godot packed Vector3 columns; the added original-reader sidecar exports JSON-safe vectors and now checks every reconstructed column without changing recorder/readers',
        'record_format: all 59 inherited checks passed; wrapper initially rejected the five intentional negative-test errors, then a narrow five-error classifier and clean rerun accepted them',
        'final accepted run additionally proves immediate first-frame fresh acquisition after clearing released inputs; held-button boundary lock remains'
    ], 'limits': 'early exploratory logs preserve failures; final SOURCE and source manifests retained for full suite attempts, not a claim of exact source reconstruction for every early edit'})
    raw = {}
    for path in sorted(run.parent.rglob('*')):
        if not path.is_file() or 'source' in path.parts or 'profiles' in path.parts:
            continue
        raw[str(path)] = {'sha256': sha(path), 'bytes': path.stat().st_size}
    write(out / 'RAW.json', raw)
    for name in ['AUDIT.json', 'SOURCE.json', 'RUNNING.json', 'RESOURCES.json']:
        shutil.copy2(run / name, out / name)
    contract = {
        'component': 'r20-tether-mouse-1', 'scope': 'R20 item 3 only, configured production scene and headless component acceptance',
        'accepted': True, 'baseline': BASE, 'reference_sha256': source['baseline_sha256'], 'engine_sha256': source['engine_sha256'],
        'source_sha256': owned, 'executed_owned_sha256': {name: digest for name, digest in owned.items() if name != 'tests/r20_tether_native.gd'}, 'document_sha256': sha(PROJECT / 'docs/r20/TETHER.md'),
        'contract_generator_sha256': sha(Path(__file__)),
        'controls': {'attach_hold': 'LMB', 'release': 'LMB up at next motor step', 'reel': 'RMB while attached', 'E': 'unchanged Movement Lab only',
                     'fresh_press': 'automatic detach retains old latch; boundaries block buttons already held, released inputs accept a fresh gameplay press immediately'},
        'settings': {'section': 'settings', 'profile': 'existing spillway_r16.cfg', 'tether_model': {'default': 'classic', 'values': ['classic', 'pendulum', 'elastic']}, 'tether_auto_reel': {'default': False, 'type': 'boolean'},
                     'change': 'actual R18 pause controls, persisted normal startup reload, pre-seal directional discard, new identity and restart; paused menu stays open'},
        'models': {name: routes[name]['mechanics'][-1] for name in ['classic', 'pendulum', 'elastic']},
        'identity': {'version': 'r20-tether-mouse-1', 'where': 'mechanics append complete tether_identity; inherited record_identity/course_key/motion_identity',
                     'compatibility': 'different model or automatic preference, and actual delivered R19 E ghost, rejected by unchanged loader; original eight full identities unchanged'},
        'diagnostics': {'recorder_kind': 'tether', 'source': 'event', 'v': 1, 'kinds': ['attach', 'release'], 'scored': False,
                        'fields': ['v', 'kind', 'reason', 'model', 'automatic_reel', 'attached', 'length_u', 'ticks'],
                        'release_fields': ['attached_ticks', 'anchor', 'cue'], 'cue_fields': ['serial', 'reason', 'active', 'pcm_sha256'],
                        'cue_active_meaning': 'AudioStreamPlayer.playing immediately after play()',
                        'motion_path': 'get_motion_state().experiment.tether', 'motion_fields': ['model', 'automatic_reel', 'reeling', 'blocked_until_release', 'armed', 'left_s', 'last_cue'],
                        'automatic_reasons': ['time', 'range', 'obstructed'], 'manual_reason': 'released',
                        'lifecycle_clears': ['pause', 'restart', 'practice', 'respawn', 'map', 'preset', 'model', 'automatic_reel', 'quit']},
        'cues': cues, 'routes': {name: {key: route_proof[name][key] for key in ['elapsed', 'ticks', 'attached_ticks', 'pull_ticks', 'rope_ticks']} for name in route_proof},
        'verification': {'checks': len(audit['checks']), 'cross_reader_recordings': len(audit['recordings']), 'inherited_godot_record_checks': 59, 'inherited_python_format_checks': read(run / 'format-python/summary.json')['checks'],
                         'headless_command': 'python3 -I tests/r20_tether_check.py --out=ABS_FRESH_DIR',
                         'contract_command': 'python3 -I tests/r20_tether_contract.py --run=ABS_ACCEPTED_DIR --out=ABS_COMPACT_DIR',
                         'exact_replay': 'all tick columns, complete ordered raw key/button/action/motion input tables, physical/motion/style observations',
                         'classic_pair': 'physical motion and exact per-cause impulses against extracted frozen R19 E, route plus immediate/ground/jump/timeout/minimum/LOS/range fixtures'},
        'native_observer': {'route_script': 'res://tests/r20_tether_native.gd', 'route_args': '--out=ABS_DIR --model=classic|pendulum|elastic --size=1280x720|1920x1080 --tape=ABS_RECORDED_TAPE',
                            'menu_script': 'res://tests/r20_tether_boundaries.gd', 'menu_args': '--out=ABS_ROUTE_ROOT/boundaries-native --native --size=1280x720|1920x1080',
                            'host_flags': '--windowed --resolution WxH --fixed-fps 128 --path ABS_SOURCE',
                            'audio_files': [str(run / 'boundaries' / ('cue-' + reason + '.wav')) for reason in ['time', 'range', 'obstructed', 'released']],
                            'pending': ['private native rendering, HUD/menu screenshots and legibility', 'listening to actual generated cues', 'human feel', 'full all-map parity and release/package/Windows acceptance']},
        'raw_root': str(run.parent), 'accepted_root': str(run), 'resources': read(run / 'RESOURCES.json'),
        'limitations': audit['limits'], 'doc': 'docs/r20/TETHER.md'}
    write(out / 'CONTRACT.json', contract)
    print(json.dumps({'accepted': True, 'checks': len(audit['checks']), 'recordings': len(audit['recordings']), 'contract_sha256': sha(out / 'CONTRACT.json')}))


if __name__ == '__main__':
    main()
