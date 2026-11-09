#!/usr/bin/env python3
"""compare actual-host compact native/headless traces and sealed input recordings."""
import argparse
import gzip
import hashlib
import importlib.util
import json
import sys

sys.dont_write_bytecode = True
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def rows(path):
    with gzip.open(path, 'rt') as stream:
        return [json.loads(line) for line in stream if line.strip()]


def equivalent(a, b, keys):
    bad = []
    for x, y in zip(a, b):
        different = [k for k in keys if x.get(k) != y.get(k)]
        if different:
            bad.append({'tick': x.get('tick'), 'fields': different})
    return {'ok': len(a) == len(b) and not bad, 'ticks_a': len(a), 'ticks_b': len(b), 'differing_ticks': len(bad), 'first': bad[:3]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--headless', type=Path)
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--native', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    report = {}
    traces = {}
    folders = ([('headless', args.headless)] if args.headless else []) + [('native', args.native)]
    for label, folder in folders:
        traces[label] = rows(folder / 'run/evaluator/trace.jsonl.gz')
    keys = ['tick', 'p', 'v', 'yaw', 'pitch', 'grounded', 'ducked', 'elapsed', 'checkpoint', 'finished', 'finish_kind', 'respawns', 'held', 'motion_events']
    if args.headless:
        report['native_headless'] = equivalent(traces['headless'], traces['native'], keys)
        report['score_native_headless'] = equivalent([{'tick': r['tick'], 'score': r['style']['score'], 'combo': r['style']['combo']} for r in traces['headless']],
                                                    [{'tick': r['tick'], 'score': r['style']['score'], 'combo': r['style']['combo']} for r in traces['native']], ['tick', 'score', 'combo'])
    run_meta = json.loads((args.native / 'run.json').read_text())
    route = run_meta.get('accepted_route')
    if route or args.reference:
        reference_path = args.reference or Path(route['reference'])
        report['reference'] = {'path': str(reference_path), 'sha256': hashlib.sha256(reference_path.read_bytes()).hexdigest()}
        reference = [r for r in rows(reference_path) if r.get('phase') == 'tape']
        translated = [{'tick': r['tick'], **{k: r['post'][k] for k in ['p', 'v', 'yaw', 'pitch', 'grounded']},
                       **{k: r['game'][k] for k in ['elapsed', 'checkpoint', 'finished', 'finish_kind', 'respawns']}} for r in reference]
        report['reference_motion'] = equivalent(traces['native'], translated,
            ['tick', 'p', 'v', 'yaw', 'pitch', 'grounded', 'elapsed', 'checkpoint', 'finished', 'finish_kind', 'respawns'])
    tape_checks = module(PROJECT / 'tests/test_r16_loop_tapes.py', 'acceptance_loop_check')
    report['recordings'] = {}
    for label, folder in folders:
        transformed = [{'post': {'p': r['p'], 'v': r['v'], 'yaw': r['yaw']}, 'game': {'elapsed': r['elapsed'], 'finished': r['finished']},
                        'keys': r.get('keys', []), 'mouse': r.get('mouse', {})} for r in traces[label]]
        result = tape_checks.check_recordings(folder / 'run/runs', transformed, PROJECT)
        if not any(r.get('keys') for r in traces[label]):
            result['input_trace_note'] = 'baseline harness did not retain delivery fields; recorded inputs are not asserted against this compact trace'
            result['ok_without_input_alignment'] = result.get('first_difference') is None and result.get('style', {}).get('ok') is True
        report['recordings'][label] = result
    summary = json.loads((args.native / 'run/summary.json').read_text())
    overlap = summary.get('overlap_replay', [])
    if overlap:
        report['overlap_same_tape'] = equivalent(overlap, traces['native'][:len(overlap)], ['tick', 'p', 'v', 'yaw', 'pitch'])
        report['overlap_fade'] = {'ticks': len(overlap), 'max_fade': max(r['ghost']['fade'] for r in overlap),
                                  'landing_rows': [r for r in overlap if r['tick'] in [700, 750, 800]]}
    report['source_commits'] = {label: json.loads((folder / 'run.json').read_text())['commit'] for label, folder in folders}
    report['comparator_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    report['helper_sha256'] = hashlib.sha256((PROJECT / 'tests/test_r16_loop_tapes.py').read_bytes()).hexdigest()
    checks = [report['native_headless']['ok'], report['score_native_headless']['ok']] if args.headless else []
    if route or args.reference:
        checks.append(report['reference_motion']['ok'])
    for rec in report['recordings'].values():
        checks.append(rec.get('ok_without_input_alignment', rec['ok']))
    if overlap:
        checks.append(report['overlap_same_tape']['ok'])
    report['ok'] = all(checks)
    args.out.write_text(json.dumps(report, indent=1) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k in ['ok', 'native_headless', 'score_native_headless', 'reference_motion', 'overlap_same_tape']}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
