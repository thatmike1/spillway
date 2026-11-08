#!/usr/bin/env python3
"""turn the independent review's false-acceptance observations into failing regressions."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--source-final', type=Path, required=True)
    args = parser.parse_args()
    review = Path(__file__).with_name('test_r14_verifier_closure_review.py')
    subprocess.run([sys.executable, '-B', str(review), '--out', str(args.out),
                    '--candidate', str(args.candidate), '--source-final', str(args.source_final)], check=True)
    observations = json.loads((args.out / 'SUMMARY.json').read_text())
    expected = {'source boundary ' + name: name == 'valid' for name in
                ['valid', 'evaluator-log-error', 'missing-evaluator-log', 'rate-false', 'neutral-false', 'end-failed']}
    expected.update({'HUD ' + name: name == 'visible' for name in
                     ['visible', 'hidden', 'zero-modulate', 'zero-font-alpha', 'zero-visible-characters', 'offscreen']})
    checks = [{'name': row['name'], 'ok': row.get('accepted') is expected[row['name']]}
              for row in observations if row['name'] in expected]
    ok = len(checks) == len(expected) and all(row['ok'] for row in checks)
    (args.out / 'CLOSURE-GATES.json').write_text(json.dumps({'ok': ok, 'checks': checks}, indent=2) + '\n')
    print('%d closure gates, %d failed' % (len(checks), sum(not row['ok'] for row in checks)))
    raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
