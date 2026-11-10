#!/usr/bin/env python3
"""audit independently observed live style against sealed R20 component recordings."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def audit(run):
    package = module('r20_style_event_package', PROJECT / 'tools/package-r20.py')
    reader = module('r20_style_event_reader', PROJECT / 'tools/analyze-r16-runs.py')
    summary = json.loads((run / 'summary.json').read_text())
    assert summary['ok'] and summary['failed'] == 0
    observed = json.loads((run / 'release-observed.json').read_text())
    by_run = {}
    for row in observed:
        assert isinstance(row['run_id'], str) and row['run_id']
        assert type(row['tick']) is int and row['tick'] >= 0
        by_run.setdefault(row['run_id'], []).append(row)
    results, seen, bank_example, lifecycle_example = [], set(), None, None
    for path in sorted((run / 'episodes').glob('*.json')):
        fixture = json.loads(path.read_text())
        for record in fixture['recordings']:
            rec = reader.read(Path(record['path']))
            assert rec.ok, rec.errors
            identity = rec.header['run_id']
            assert identity not in seen, 'duplicate episode recording'
            seen.add(identity)
            assert package.json_numbers_match(rec.header, record['header'])
            assert package.json_numbers_match(rec.seal, record['seal'])
            assert package.json_numbers_match(rec.events, record['events'])
            rows = by_run.get(identity, [])
            n = len(rec.columns['tick'])
            assert [row['tick'] for row in rows] == list(range(n)), 'incomplete independent style observations'
            assert [event['q'] for event in rec.events] == list(range(len(rec.events)))
            assert all(type(event['t']) is int and -1 <= event['t'] < n for event in rec.events)
            assert rec.header['metadata']['scoring']['style'] == summary['identity']
            total, kinds = package.audit_style_stream(rec, rows)
            banks = [e for e in rec.events if e['k'] == 'style' and e['d']['v'] == 2]
            diagnostics = [e for e in rec.events if e['k'] == 'direction']
            if banks and bank_example is None:
                bank_example = rec, rows
            if any(e['s'] == 'event' for e in diagnostics) and lifecycle_example is None:
                lifecycle_example = rec, rows
            results.append({'episode': path.stem, 'path': str(rec.path), 'sha256': sha(rec.path),
                'ticks': n, 'score': total, 'by_kind': kinds, 'banks': len(banks), 'diagnostics': len(diagnostics)})
    assert not set(by_run) - seen, 'live observations have no sealed episode recording'
    assert bank_example is not None and lifecycle_example is not None
    negatives = []

    def rejects(label, example, mutate):
        rec, rows = copy.deepcopy(example)
        mutate(rec, rows)
        try:
            package.audit_style_stream(rec, rows)
        except package.Rejected:
            negatives.append({'name': label, 'refused': True})
        else:
            raise AssertionError('corruption accepted: ' + label)

    def first_bank(rec):
        return next(e['d'] for e in rec.events if e['k'] == 'style' and e['d']['v'] == 2)

    rejects('bank amount', bank_example, lambda r,s: first_bank(r).update(points=first_bank(r)['points'] + 1))
    rejects('bank speed', bank_example, lambda r,s: first_bank(r)['m'].update(end_ups=9999.))
    rejects('bank category label', bank_example, lambda r,s: first_bank(r).update(label='Speed'))
    rejects('scored seal', bank_example, lambda r,s: r.seal['outcome']['style'].update(score=0))
    rejects('missing live scored event', bank_example,
        lambda r,s: s[first_bank(r)['tick']].update(style_events=[]))
    rejects('missing live pending state', bank_example,
        lambda r,s: next(row for row in s if row['style_direction']['pending'] > 0)['style_direction'].update(pending=0))
    rejects('non-scored points', bank_example,
        lambda r,s: next(e['d'] for e in r.events if e['k'] == 'direction').update(points=1))
    rejects('diagnostic serial', bank_example,
        lambda r,s: next(e['d'] for e in r.events if e['k'] == 'direction').update(serial=999))
    rejects('lifecycle cashout', lifecycle_example,
        lambda r,s: next(e['d'] for e in r.events if e['k'] == 'direction' and e['s'] == 'event').update(kind='direction_banked'))
    rejects('lifecycle reason without boundary', lifecycle_example,
        lambda r,s: next(e['d'] for e in r.events if e['k'] == 'direction' and e['s'] == 'event').update(reason='unknown_boundary'))
    return {'ok': True, 'scope': 'frozen-source, read-only live scorer observer and both recording readers; no packed/native/Windows or physical parity claim',
        'recordings': results, 'observed_ticks': len(observed), 'negative_controls': negatives,
        'helpers': {name: sha(PROJECT / name) for name in ['tools/package-r20.py', 'tools/check-r20-style-events.py',
            'tests/r20_release_style_observer.gd', 'tools/analyze-r16-runs.py']}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True, type=Path)
    args = parser.parse_args()
    result = audit(args.run.resolve())
    (args.run / 'RELEASE-STYLE-AUDIT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'ok': True, 'recordings': len(result['recordings']),
        'observed_ticks': result['observed_ticks'], 'negative_controls': len(result['negative_controls'])}))


if __name__ == '__main__':
    main()
