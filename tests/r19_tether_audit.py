#!/usr/bin/env python3
"""audit Tether Yard inputs, exact replay, original recording readers and isolation evidence."""
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


def read_json(path):
    return json.loads(path.read_text())


def trace(path):
    with gzip.open(path / 'trace.jsonl.gz', 'rt') as stream:
        return [json.loads(row) for row in stream]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    args = parser.parse_args()
    root = args.root
    summary = read_json(root / 'final/summary.json')
    replay_summary = read_json(root / 'replay/summary.json')
    geometry = read_json(root / 'final/geometry.json')
    lifecycle = read_json(root / 'final-lifecycle/summary.json')
    recovery = read_json(root / 'recovery/summary.json')
    rows, replay = trace(root / 'final'), trace(root / 'replay')
    checks = []

    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})

    check(summary['pass'] and replay_summary['pass'] and summary['finish_kind'] == replay_summary['finish_kind'] == 'clean', 'earned and fixed-input replay both finish cleanly in actual R19 host/session')
    check(summary['elapsed'] == replay_summary['elapsed'] and summary['respawns'] == replay_summary['respawns'] == 0, 'same elapsed time and no respawns')
    check(rows == replay and len(rows) > 1280, 'every telemetry field matches at every fixed-input replay tick')
    check(all(row['tick'] == i for i, row in enumerate(rows)), 'one observation per consecutive driver tick')
    check(summary['identity'] == replay_summary['identity'] and summary['identity']['map'] == 'tether-yard' and summary['identity']['preset'] == 'server128', 'same independent map, runner, mechanics and geometry identity')
    check(summary['runner'] == 'res://scripts/r19_tether_player.gd' and summary['physics_hz'] == 128, 'actual new runner at F2 128Hz')
    check(summary['actual_v_mismatches'] == summary['rate_mismatch_ticks'] == 0, 'no travel-observation or simulation-rate mismatch')
    check(geometry['ok'] and geometry['hash'] == summary['geometry_hash'] and len(geometry['anchors']) == 3 and geometry['max_extent_m'] <= 32.0001, 'all real convex vertices and three anchors match identity data')
    check(len(summary['anchors']) == 3 and min(summary['anchors'].values()) >= 128, 'each distinct anchor actually holds for at least one second')
    check(summary['pull_ticks'] > 128 and summary['rope_ticks'] > 0, 'actual spring pull and radial rope correction observed')
    check(len(summary['releases']) == 3 and all(row['reason'] == 'released' for row in summary['releases']), 'three explicit E releases, without obstruction/time/range breaks')
    check(all(not r['motion']['experiment']['enabled']['slide'] and not r['motion']['experiment']['enabled']['wall_jump'] and r['motion']['experiment']['counts']['slide'] == 0 and r['motion']['experiment']['counts']['wall_jump'] == 0 for r in rows), 'slide and wall jump stay disabled through full earned run')
    check(lifecycle['pass'] and lifecycle['lifecycle_done'] and lifecycle['frozen_ticks'] >= 20 and all(c['ok'] for c in lifecycle['checks']), 'actual restart, pause/resume, toggle prevention and map-exit isolation pass')
    check(recovery['pass'] and recovery['recovery']['recovered'] and recovery['respawns'] == 0 and 'return_ramp_0' in recovery['recovery']['supports'], 'actual early release, catch court and walked return ramp with no respawn')
    check(summary['geometry_hash'] == recovery['geometry_hash'] == lifecycle['geometry_hash'], 'finish, recovery and lifecycle use the same final map identity')

    spec = importlib.util.spec_from_file_location('original_r16_reader', PROJECT / 'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    records = []
    for folder in ['final', 'replay', 'recovery', 'final-lifecycle']:
        for path in sorted((root / folder / 'recordings').glob('*.r16run')):
            rec = reader.read(path)
            records.append({'path': str(path), 'ok': rec.ok, 'status': rec.status, 'errors': rec.errors, 'sha256': digest(path)})
    check(bool(records) and all(r['ok'] for r in records), 'original Python reader accepts all final recordings after actual normal Quit exits')
    check(summary['recordings'] and all(r['ok'] and r['clean_finish']['ok'] for r in summary['recordings']), 'original Godot reader accepts full clean finish')
    rec = reader.read(Path(summary['recordings'][0]['path']))
    columns = rec.columns
    offsets = []
    for offset in range(30, 37):
        if offset + len(rows) > len(columns['tick']):
            continue
        if all(rows[i]['p'] == [columns[f'p_{axis}'][i + offset] for axis in 'xyz'] for i in range(len(rows))):
            offsets.append(offset)
    check(len(offsets) == 1, 'recorded positions exactly match every retained physics observation after settle')
    if offsets:
        offset = offsets[0]
        check(all(rows[i]['v'] == [columns[f'v_{axis}'][i + offset] for axis in 'xyz'] and rows[i]['yaw'] == columns['yaw'][i + offset] and rows[i]['pitch'] == columns['pitch'][i + offset] and rows[i]['elapsed'] == columns['elapsed'][i + offset] and rows[i]['checkpoint'] == columns['checkpoint'][i + offset] for i in range(len(rows))), 'recorded velocity/view/time/checkpoint exactly match all physics observations')
    check(all(hz == 128 for hz in columns['physics_hz']) and all(dt == 1 / 128 for dt in columns['dt']), 'recording rate and dt are exactly 128Hz')
    input_kinds = rec.inputs['kind']
    check(1 in input_kinds and 3 in input_kinds and 69 in rec.inputs['code'], 'recording contains real keys, mouse motion and E input')

    sources = {}
    write_hits = []
    patterns = [r'\bplayer\.(?:position|global_position|velocity|yaw|pitch|transform|global_transform)\s*(?:[+*/-]?=)(?!=)', r'\bgame\.(?:checkpoint_index|elapsed|finished|_started|stage_times)\s*(?:[+*/-]?=)(?!=)', r'\bplayer\.(?:set|reset_to|apply_settings)\s*\(']
    owned = [*PROJECT.glob('scripts/r19_tether*.gd'), *PROJECT.glob('tests/r19_tether*.gd'), PROJECT / 'tests/r14_practice_driver.gd']
    for path in owned:
        sources[str(path.relative_to(PROJECT))] = digest(path)
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith('#'):
                continue
            if any(re.search(pattern, line) for pattern in patterns):
                write_hits.append(f'{path.name}:{line_number}:{line}')
    check(not write_hits, 'no direct test body, velocity, camera or progress writes')
    course = (PROJECT / 'scripts/r19_tether_level.gd').read_text()
    check(not re.search(r'func\s+_(?:physics_process|process|input)\b|Area3D\.new|style\.\w+\(', course), 'level has no runtime movement callback, hidden trigger or score call')
    before = read_json(root / 'preservation-before.json')
    preservation = {name: {'before': sha, 'after': digest(PROJECT / name)} for name, sha in before.items()}
    check(all(v['before'] == v['after'] for v in preservation.values()), 'protected R15/R16 bodies and shared Source law stay byte-identical')
    logs = {folder: (root / f'{folder}.log').read_text() for folder in ['final', 'replay', 'recovery', 'final-lifecycle']}
    check(all(not re.search(r'SCRIPT ERROR|ERROR:|WARNING:.*ObjectDB', text) for text in logs.values()), 'final headless runs have no script errors or cleanup warnings')
    result = {'ok': all(c['ok'] for c in checks), 'checks': checks, 'elapsed_s': summary['elapsed'], 'samples': len(rows), 'recorded_ticks': len(columns['tick']), 'recording_offset': offsets, 'attached_ticks': summary['attached_ticks'], 'pull_ticks': summary['pull_ticks'], 'rope_ticks': summary['rope_ticks'], 'releases': summary['releases'], 'geometry_hash': summary['geometry_hash'], 'recordings': records, 'source_sha256': sources, 'preservation': preservation, 'write_hits': write_hits, 'limits': ['coordinate-aware input route finding proves a line, not player discovery or enjoyment', 'headless component evidence; native rendering, final production integration and packages belong to parent', 'write scan supplements source review and actual travel checks; it is not a general proof against malicious code']}
    (root / 'AUDIT.json').write_text(json.dumps(result, indent=1) + '\n')
    for row in checks:
        print(('PASS ' if row['ok'] else 'FAIL ') + row['check'])
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
