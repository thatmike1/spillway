#!/usr/bin/env python3
"""bind the source-only Through Line acceptance to hashes and compact review evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    run, raw, out = args.run.resolve(), args.raw.resolve(), args.out.resolve()
    assert read(run / 'AUDIT.json')['ok']
    out.mkdir(parents=True, exist_ok=True)
    source = read(run / 'SOURCE.json')
    files = [PROJECT / ('scripts/' + name) for name in ['r20_main.gd', 'r20_map_catalog.gd', 'r20_hud.gd']]
    files += list(PROJECT.glob('scripts/r20_through*')) + list(PROJECT.glob('tests/r20_through*'))
    files.append(PROJECT / 'docs/r20/THROUGH-LINE.md')
    owned = {str(p.relative_to(PROJECT)): sha(p) for p in files if p.is_file()}
    assert all(source['sha256'].get(name) == digest for name, digest in owned.items()), 'final owned source differs from executed snapshot'
    receipts = ['SOURCE.json', 'AUDIT.json', 'ROUTES.json', 'READERS.json', 'ATTEMPTS.json', 'RESOURCES.json', 'PRESERVATION.json', 'LIVE-PRESERVATION.json']
    for name in receipts:
        shutil.copy2(run / name, out / name)
    assertions = {}
    for label in ['component', 'ordinary', 'quit', 'ghosts', 'source-motion', 'source-player', 'crouch', 'record-format', 'format-python']:
        summary = read(run / label / 'summary.json')
        assert summary.get('ok', True) and summary.get('failed', 0) == 0
        rows = summary.get('checks', [])
        assertions[label] = len(rows) if isinstance(rows, list) else rows
        shutil.copy2(run / label / 'summary.json', out / (label + '.json'))
    cue = out / 'launch-cue.wav'
    shutil.copy2(run / 'fast/launch-cue.wav', cue)
    classification = {
        'fast01': 'rejected: initial snapshot omitted nested look resources; one GDScript inferred-bool parse error',
        'fast02': 'superseded exploration: earlier 0.9 lift coefficient',
        'slow01': 'rejected despite engine exit 0: inherited flight-stat dictionary lacked ticks after a grounded launch',
        'fast03': 'superseded exploration: corrected lift and flight stats, before final diagnostic and presentation state',
        'slow02': 'superseded exploration: corrected slow route, before final diagnostic and presentation state',
        'component01': 'rejected: cue frame timing and zero-velocity reset fixture assumptions were wrong',
        'component02': 'rejected: unchanged failed fixture rerun after a test-edit path typo',
        'component03': 'passing predecessor fixture coverage; final suite extends it',
        'ordinary01': 'passing predecessor ordinary pairing; final suite repeats it',
        'quit01': 'passing predecessor real quit; final suite repeats it',
        'final-fast': 'passing route exploration before final motion-report/presentation changes',
        'final-slow': 'passing route exploration before final motion-report/presentation changes',
        'accepted01': 'rejected final audit: snapshot manifest omitted UID and historical look paths; gameplay/readers passed',
        'accepted02': 'rejected final audit: snapshot still omitted historical root look paths; gameplay/readers/ghosts passed',
        'accepted03': 'passing full predecessor; final test comments and native frame receipts added afterward',
        run.name: 'authoritative final full source acceptance'
    }
    write(out / 'ATTEMPT-CLASSIFICATION.json', classification)
    raw_files = {str(p.relative_to(raw)): {'bytes': p.stat().st_size, 'sha256': sha(p)} for p in raw.rglob('*') if p.is_file() and not any(part in {'source', 'profiles', 'profiles-final', '__pycache__'} for part in p.relative_to(raw).parts)}
    write(out / 'RAW.json', raw_files)
    routes = read(run / 'ROUTES.json')
    mechanics = read(run / 'fast/summary.json')['mechanics']
    resource = read(run / 'RESOURCES.json')
    contract = {'schema': 1, 'component': 'R20 item5 Through Line', 'ok': True, 'scope': 'source-only production scene, headless Godot and Dummy activation',
        'source_parent': source['parent'], 'source_sha256': owned, 'engine': source['engine'], 'engine_sha256': source['engine_sha256'],
        'mechanics': mechanics, 'identity': routes['fast']['identity'], 'routes': routes, 'checks': len(read(run / 'AUDIT.json')['checks']),
        'recordings_both_readers': len(read(run / 'READERS.json')), 'assertions': assertions, 'raw': str(raw), 'accepted_run': str(run),
        'commands': {'full': f'python3 -I tests/r20_through_check.py --out={run} --scratch={raw} --keep-source',
            'contract': f'python3 -I tests/r20_through_contract.py --run={run} --raw={raw} --out={out}',
            'engines': read(run / 'ATTEMPTS.json')},
        'cue': {'wav': str(cue), 'wav_sha256': sha(cue), 'pcm_sha256': routes['fast']['launch']['cue']['pcm_sha256'], 'actual_activation': routes['fast']['launch']['cue']},
        'native_seam': {'script': 'tests/r20_through_native.gd', 'input_tape': str(run / 'fast-recorded.tape.json'),
            'frames': ['first-run.png', 'launch.png', 'flight.png', 'apex.png', 'landing.png', 'continued-run.png'], 'receipt': 'frames.json',
            'state': 'same saved-input route verified headlessly only; parent supplies private native display and inspects captures', 'instructions': 'docs/r20/THROUGH-LINE.md'},
        'resources': resource, 'limits': [
            'simulation continuity is proven on these two earned F2 routes; native seamless feel, appearance, listening and discoverability are unproven',
            'no native display, desktop input or speakers were opened; no actual rendered frame is claimed',
            'negative/lifecycle cases use explicitly labelled collision/initial-condition/recross fixtures; whole routes use inputs only from authored spawn',
            'ordinary original-map check is 242 input ticks per map, plus all original full identities and byte preservation; final full-course release parity stays with parent',
            'two static trajectory examples are teaching hints; arbitrary faster entries/steering can overshoot the landing court',
            'no agent was started; independent parent review, packed/native/Windows verification and promotion remain parent work',
            'earlier exploratory source snapshots were reused; retained logs/recordings classify their failures, final runtime has the complete source hash manifest'
        ], 'ownership': 'only new r20_through scripts/tests, THROUGH-LINE.md and narrow R20 main/catalog/HUD integration; no old gameplay/readers/scoring/packaging edits'}
    write(out / 'CONTRACT.json', contract)
    write(out / 'SHA256.json', {str(p.relative_to(out)): sha(p) for p in out.rglob('*') if p.is_file() and p.name != 'SHA256.json'})
    print('CONTRACT', sha(out / 'CONTRACT.json'), 'checks', contract['checks'], 'recordings', contract['recordings_both_readers'])


if __name__ == '__main__':
    main()
