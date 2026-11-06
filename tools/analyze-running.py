#!/usr/bin/env python3
"""Measure continuous ordinary locomotion on a completed input-only route."""
import argparse
import json
import statistics
from pathlib import Path


def analyze(path: Path) -> dict:
    rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    samples = [row for row in rows if row.get('event') == 'sample']
    starts = [row for row in rows if row.get('event') == 'start']
    results = [row for row in rows if row.get('event') == 'result']
    errors = []
    if not samples:
        raise ValueError('expected ordinary spillway driver sample events')
    if len(starts) != 1 or starts[0].get('fixture', True):
        errors.append('expected one non-fixture route start')
    if len(results) != 1 or not results[0].get('success'):
        errors.append('route did not complete successfully')
    if len(results) == 1:
        final = results[0]
        if not final.get('clean_eligible') or final.get('finish_kind') != 'clean':
            errors.append('expected a recorded clean full-course finish')
        if final.get('ordered_checkpoints') != [0, 1, 2]:
            errors.append('expected all three stages in order')
    if any(int(row.get('respawns', 0)) for row in samples + results):
        errors.append('route contains a respawn')
    gaps = [float(b['time']) - float(a['time']) for a, b in zip(samples, samples[1:])]
    interval = statistics.median(gaps) if gaps else 0
    if not gaps or min(gaps) <= 0 or max(gaps) > .11:
        errors.append('samples must be ordered with no gap above 0.11 seconds')
    spans = []
    start = previous = None
    moving = False
    last_jumps = 0
    jumping = False
    for row in samples:
        jumps = int(row.get('jumps', 0))
        if jumps > last_jumps:
            jumping = True
        last_jumps = jumps
        if row.get('grounded', False) and row.get('mode') != 'air':
            jumping = False
        # a held key or a one-tick floor seam does not invent a movement action.
        active = row.get('mode') in {'slide', 'surf', 'mantle'} or jumping
        moving = moving or float(row.get('speed', 0)) > .5
        if moving and not active:
            if start is None:
                start = row
            previous = row
        elif start is not None:
            spans.append(span(start, previous))
            start = previous = None
    if start is not None:
        spans.append(span(start, previous))
    spans.sort(key=lambda item: item['duration_s'], reverse=True)
    longest = spans[0]['duration_s'] if spans else 0
    return {
        'trace': str(path.resolve()),
        'definition': 'continuous ordinary locomotion, including turns and stops; only executed jumps, slides, surf or mantle interrupt it; held keys alone do not',
        'sample_interval_s': interval,
        'endpoint_uncertainty_s': interval * 2,
        'route_valid': not errors,
        'errors': errors,
        'longest_plain_run_s': longest,
        'passed_about_four_seconds': not errors and longest <= 4.1,
        'spans': spans,
    }


def span(start: dict, end: dict) -> dict:
    return {'start_s': start['time'], 'end_s': end['time'],
            'duration_s': float(end['time']) - float(start['time']),
            'from': start['position'], 'to': end['position']}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        result = analyze(args.trace)
    except (ValueError, KeyError) as error:
        parser.exit(2, f'invalid trace: {error}\n')
    encoded = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(encoded)
    print(encoded, end='')
    raise SystemExit(0 if result['passed_about_four_seconds'] else 1)


if __name__ == '__main__':
    main()
