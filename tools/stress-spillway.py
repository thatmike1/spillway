#!/usr/bin/env python3
"""run the input timing/aim matrix and preserve every attempt outside Git."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
SOURCES = ['spillway_player.gd', 'spillway_level.gd', 'spillway_course.gd', 'spillway_main.gd', 'spillway_driver.gd']


def source_hashes():
    return {name: hashlib.sha256((PROJECT / 'scripts' / name).read_bytes()).hexdigest() for name in SOURCES}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pack', type=Path, help='run the exact exported PCK instead of the source checkout')
    parser.add_argument('--godot', default=os.environ.get('GODOT', str(Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')))
    args = parser.parse_args()
    root = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=PROJECT, text=True).strip())
    output = args.output.expanduser().resolve()
    if output == root or root in output.parents:
        parser.error('evidence must be outside Git')
    if output.exists() and any(output.iterdir()):
        parser.error('use an empty evidence directory so old traces cannot count as new attempts')
    output.mkdir(parents=True, exist_ok=True)
    pack = args.pack.expanduser().resolve() if args.pack else None
    if pack and not pack.is_file():
        parser.error('--pack must name an existing exported PCK')
    before = source_hashes() if not pack else None
    pack_hash = hashlib.sha256(pack.read_bytes()).hexdigest() if pack else None
    provenance = {'mode': 'exported_pack' if pack else 'source_checkout',
                  'pack': str(pack) if pack else None, 'pack_sha256': pack_hash,
                  'source_hashes': before,
                  'harness_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip()}

    cases = [(f'baseline-{route}-{seed}', route, seed, []) for route in ['safe', 'fast', 'recovery', 'brake', 'safe_corner', 'fast_housing_turn', 'rail_hop_recovery'] for seed in range(5)]
    cases += [(f'{label}-fast-{seed}', 'fast', seed, [f'--jump-delay={delay}', '--aim-deg=2']) for label, delay in [('early', '-0.08'), ('late', '0.08')] for seed in range(1, 4)]
    isolated_runtime = tempfile.TemporaryDirectory(prefix="spillway-packed-matrix-") if pack else None
    run_directory = Path(isolated_runtime.name) if isolated_runtime else PROJECT
    provenance["execution_directory"] = str(run_directory)
    rows = []
    def save(complete=False, unchanged=True):
        temporary = output / 'matrix-results.json.tmp'
        temporary.write_text(json.dumps({'attempts': len(rows), 'expected_attempts': len(cases),
            'successes': sum(item['success'] for item in rows), 'complete': complete,
            'runtime_unchanged': unchanged, **provenance, 'cases': rows}, indent=2) + '\n')
        temporary.replace(output / 'matrix-results.json')
    save()
    for name, route, seed, extra in cases:
        folder = output / name
        folder.mkdir(exist_ok=True)
        runtime = ['--main-pack', str(pack)] if pack else ['--path', str(PROJECT)]
        command = [args.godot, '--headless', '--fixed-fps', '120', *runtime, '--', '--bot', '--bot-quit', f'--route={route}', f'--seed={seed}', f'--evidence-dir={folder}', *extra]
        result = subprocess.run(command, cwd=run_directory, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (folder / 'engine.log').write_text(result.stdout)
        traces = sorted(folder.glob('route-*.jsonl'), key=lambda path: path.stat().st_mtime_ns)
        records = [json.loads(line) for line in traces[-1].read_text().splitlines()] if traces else []
        final = next((record for record in reversed(records) if record.get('event') == 'result'), {})
        errors = 'SCRIPT ERROR:' in result.stdout or 'ERROR:' in result.stdout
        row = {'case': name, 'command': command, 'exit': result.returncode, 'engine_errors': errors, 'success': result.returncode == 0 and not errors and final.get('success', False), 'result': final, 'trace': str(traces[-1]) if traces else None}
        rows.append(row)
        print(name, 'PASS' if row['success'] else 'FAIL', round(final.get('time', 0), 3), final.get('reason', 'no result'), flush=True)
        save()
    unchanged = (hashlib.sha256(pack.read_bytes()).hexdigest() == pack_hash) if pack else source_hashes() == before
    save(complete=unchanged, unchanged=unchanged)
    if not unchanged:
        raise SystemExit('runtime changed during the matrix; this pass is not canonical')
    passed = sum(row['success'] for row in rows)
    print(f'Spillway input matrix: {passed}/{len(rows)} finished. Execution evidence, not human enjoyment.')
    raise SystemExit(0 if passed == len(rows) else 1)


if __name__ == '__main__':
    main()
