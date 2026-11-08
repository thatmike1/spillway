#!/usr/bin/env python3
"""p / per-tick comparison of momentum-tape evaluator traces for the r15 no-crouch parity check.

usage: python3 -I tests/r15_crouch_tape_compare.py CANDIDATE_RUN REFERENCE_RUN [MORE_REFERENCE_RUNS...]
each RUN is a tools/momentum-tape.py run directory with evaluator/trace.jsonl.gz and report.json.
post-step position, velocity and yaw must be exactly equal on every tick; delivered key and mouse
events are compared with wall-clock fields removed. prints one json object; exit 1 on a difference.
"""
import gzip
import json
import sys
from pathlib import Path


def load(run):
    run = Path(run)
    rows = [json.loads(line) for line in gzip.open(run / 'evaluator/trace.jsonl.gz') if line.strip()]
    report = json.loads((run / 'evaluator/report.json').read_text())
    return rows, report


def strip(value):
    # wall-clock timing differs between any two runs; it is not an input.
    if isinstance(value, dict):
        return {k: strip(v) for k, v in value.items() if 'wall' not in k}
    if isinstance(value, list):
        return [strip(v) for v in value]
    return value


def compare(a, b):
    out = {'ticks': [len(a), len(b)], 'worst': {}, 'first_difference': None, 'input_rows_differing': 0}
    for i, (p, q) in enumerate(zip(a, b)):
        for key in ('p', 'v', 'yaw'):
            x, y = p['post'].get(key), q['post'].get(key)
            d = max(abs(u - w) for u, w in zip(x, y)) if isinstance(x, list) else abs(x - y)
            out['worst'][key] = max(out['worst'].get(key, 0.0), d)
            if d and out['first_difference'] is None:
                out['first_difference'] = {'row': i, 'field': key}
        if strip(p.get('keys')) != strip(q.get('keys')) or strip(p.get('mouse')) != strip(q.get('mouse')):
            out['input_rows_differing'] += 1
    out['equal'] = len(a) == len(b) and out['first_difference'] is None and out['input_rows_differing'] == 0
    return out


def main():
    candidate, *references = sys.argv[1:]
    rows, report = load(candidate)
    result = {'candidate': candidate, 'end': report.get('end'), 'outcome_end_p': report.get('outcome', {}).get('end_p'),
              'final_game': rows[-1].get('game'), 'motor': rows[-1]['post'].get('motion_state', {}).get('motor'), 'against': {}}
    ok = True
    for ref in references:
        other, other_report = load(ref)
        c = compare(rows, other)
        c['reference_final_game'] = other[-1].get('game')
        c['reference_motor'] = other[-1]['post'].get('motion_state', {}).get('motor')
        result['against'][ref] = c
        ok = ok and c['equal']
    result['equal'] = ok
    print(json.dumps(result, indent=1))
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
