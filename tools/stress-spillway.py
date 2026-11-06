#!/usr/bin/env python3
"""Run the frozen R12 input matrix and retain every attempt outside Git."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
MATRIX_ID = 'r12-bhop-surf-1'
# r12 retires the two apron-junction variants and adds the actual wet-chute line.
CASES = [(f'baseline-{route}-{seed}', route, seed, [])
         for route in ['safe', 'fast', 'recovery', 'brake', 'safe_corner', 'wet']
         for seed in range(5)]
# waypoint timing shifts every scheduled takeoff; surf timing shifts its first crest jump.
CASES += [(f'{label}-{route}-{seed}', route, seed,
           [f'--jump-delay={delay}', '--aim-deg=2'])
          for route in ['safe', 'fast']
          for label, delay in [('early', '-0.08'), ('late', '0.08')]
          for seed in range(1, 4)]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_hashes():
    paths = set(PROJECT.glob('scripts/spillway_*.gd'))
    paths.update(PROJECT.glob('shaders/spillway*.gdshader'))
    paths.update(PROJECT / name for name in ['project.godot', 'export_presets.cfg',
                                            'scripts/audio.gd', 'scenes/main.tscn'])
    return {str(path.relative_to(PROJECT)): digest(path) for path in sorted(paths)}


def run_process(command, directory, environment=None):
    try:
        result = subprocess.run(command, cwd=directory, env=environment, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
        return result.returncode, result.stdout, False
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        return 124, output + '\nHOST TIMEOUT after45seconds\n', True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pack', type=Path, help='test this immutable exported PCK outside the source tree')
    parser.add_argument('--godot', default=os.environ.get('GODOT', str(Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')))
    args = parser.parse_args()
    root = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=PROJECT, text=True).strip())
    output = args.output.expanduser().resolve()
    if output == root or root in output.parents:
        parser.error('evidence must be outside Git')
    if output.exists() and any(output.iterdir()):
        parser.error('use an empty evidence directory so old traces cannot count as new attempts')
    pack = args.pack.expanduser().resolve() if args.pack else None
    if pack and not pack.is_file():
        parser.error('--pack must name an existing PCK')
    output.mkdir(parents=True, exist_ok=True)
    before = source_hashes() if not pack else None
    pack_hash = digest(pack) if pack else None
    provenance = {'matrix_id': MATRIX_ID, 'mode': 'exported_pack' if pack else 'source_checkout',
                  'pack': str(pack) if pack else None, 'pack_sha256': pack_hash,
                  'source_hashes': before, 'harness_sha256': digest(Path(__file__)),
                  'harness_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip(),
                  'planned_cases': [{'case': name, 'route': route, 'seed': seed, 'arguments': extra}
                                    for name, route, seed, extra in CASES]}
    rows = []

    def save(complete=False, unchanged=True, status='running'):
        temporary = output / 'matrix-results.json.tmp'
        temporary.write_text(json.dumps({'attempts': len(rows), 'expected_attempts': len(CASES),
            'successes': sum(item['success'] for item in rows), 'complete': complete, 'status': status,
            'runtime_unchanged': unchanged, **provenance, 'cases': rows}, indent=2) + '\n')
        temporary.replace(output / 'matrix-results.json')

    save()
    if pack:
        environment = dict(os.environ, GODOT=args.godot)
        code, log, _ = run_process(['bash', str(PROJECT / 'tools/check-pack.sh'), str(pack)], output, environment)
        (output / 'preflight.log').write_text(log)
        if code:
            save(status='preflight_failed')
            raise SystemExit('packed preflight failed; no route attempts started')
    with tempfile.TemporaryDirectory(prefix='spillway-r12-matrix-') as temporary:
        directory = Path(temporary) if pack else PROJECT
        provenance['execution_directory'] = str(directory)
        for name, route, seed, extra in CASES:
            folder = output / name
            folder.mkdir()
            runtime = ['--main-pack', str(pack)] if pack else ['--path', str(PROJECT)]
            command = [args.godot, '--headless', '--fixed-fps', '120', *runtime, '--',
                       '--bot', '--bot-quit', f'--route={route}', f'--seed={seed}',
                       f'--evidence-dir={folder}', *extra]
            environment = dict(os.environ, XDG_DATA_HOME=str(folder / 'profile'))
            code, log, timeout = run_process(command, directory, environment)
            (folder / 'engine.log').write_text(log)
            traces = sorted(folder.glob('route-*.jsonl'))
            parse_error = None
            records = []
            if len(traces) == 1:
                try:
                    records = [json.loads(line) for line in traces[0].read_text().splitlines()]
                except (ValueError, OSError) as error:
                    parse_error = str(error)
            finals = [record for record in records if record.get('event') == 'result']
            final = finals[0] if len(finals) == 1 else {}
            engine_errors = bool(re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:', log))
            ordered = final.get('ordered_checkpoints') == [0, 1, 2]
            finished = code == 0 and not engine_errors and not parse_error and len(traces) == 1 and final.get('success', False)
            success = bool(finished and ordered and final.get('respawns') == 0 and final.get('clean_eligible') and final.get('finish_kind') == 'clean')
            quality_flags = []
            if route == 'fast':
                for section in ['CrestSurf', 'YardSurf', 'OutflowSweep', 'OutflowSurf']:
                    ride = final.get('surf_report', {}).get(section, {})
                    if not ride.get('exit_speed') or ride.get('contact_ticks', 0) < 24 or ride.get('contact_ticks', 0) < .4 * ride.get('ride_ticks', 1):
                        quality_flags.append('incomplete surf contact: ' + section)
                if any(drop['from'] - drop['to'] > 4 for drop in final.get('speed_drops', [])):
                    quality_flags.append('single-tick speed loss over4m/s')
            rows.append({'case': name, 'command': command, 'exit': code, 'host_timeout': timeout,
                         'engine_errors': engine_errors, 'trace_error': parse_error,
                         'success': success, 'quality_flags': quality_flags,
                         'result': final, 'trace': str(traces[0]) if len(traces) == 1 else None})
            print(name, 'PASS' if success else 'FAIL', round(final.get('time', 0), 3),
                  final.get('reason', 'no result'), '; '.join(quality_flags), flush=True)
            save()
    unchanged = digest(pack) == pack_hash if pack else source_hashes() == before
    save(complete=unchanged, unchanged=unchanged, status='complete' if unchanged else 'runtime_changed')
    passed = sum(row['success'] for row in rows)
    print(f'Spillway {MATRIX_ID}: {passed}/{len(CASES)} ordered finishes; surf quality flags remain separate. Not enjoyment proof.')
    if not unchanged:
        raise SystemExit('runtime changed during the matrix; this pass is not canonical')
    raise SystemExit(0 if passed == len(CASES) else 1)


if __name__ == '__main__':
    main()
