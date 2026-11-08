#!/usr/bin/env python3
"""judge the retained os-input trace, including failed attempts and independent identity."""
import argparse
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess
import tarfile

PROJECT = Path(__file__).resolve().parents[1]
CANDIDATE = Path('/home/thatmike1/foldrunner-build-2026-11-05/delivery/work/r14-candidate-5484f10d')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--attempt', default='attempt-03')
    args = parser.parse_args()
    out = args.evidence.resolve()
    run = json.loads((out / args.attempt / 'run.json').read_text())
    with gzip.open(out / args.attempt / 'telemetry.jsonl.gz', 'rt') as stream:
        rows = [json.loads(line) for line in stream]
    samples = [r for r in rows if r['kind'] == 'sample']
    identity = next(r for r in rows if r['kind'] == 'identity')
    checks = {}
    details = {}

    def check(name, value):
        checks[name] = bool(value)

    def phase(name, kind='sample'):
        return [r for r in rows if r['phase'] == name and r['kind'] == kind]

    def speed(row):
        return math.hypot(row['velocity'][0], row['velocity'][2]) / .0254

    build = json.loads((CANDIDATE / 'BUILD.json').read_text())
    commit = build['source_commit']

    def git(*parts, binary=False):
        result = subprocess.check_output(['git', *parts], cwd=PROJECT.parents[1], timeout=30)
        return result if binary else result.decode().strip()

    stamp = git('show', '-s', '--format=%ct', commit)
    archive_cmd = ['archive', '--format=tar', '--mtime=@' + stamp, commit + ':projects/foldrunner']
    archive = git(*archive_cmd, binary=True)
    lines = []
    with tarfile.open(fileobj=io.BytesIO(archive)) as frozen:
        for member in frozen.getmembers():
            if member.isfile():
                lines.append('%s  %s' % (hashlib.sha256(frozen.extractfile(member).read()).hexdigest(), member.name))
    manifest = ''.join(line + '\n' for line in sorted(lines, key=lambda line: line.split('  ', 1)[1]))
    source = {'command': ['git', *archive_cmd], 'source_commit': commit,
              'source_tree': git('rev-parse', commit + ':projects/foldrunner'),
              'source_archive_sha256': hashlib.sha256(archive).hexdigest(),
              'source_manifest_sha256': hashlib.sha256(manifest.encode()).hexdigest(), 'file_count': len(lines)}
    source['matches_build'] = all(source[k] == build[k] for k in ['source_tree', 'source_archive_sha256', 'source_manifest_sha256']) and len(lines) == build['source_files']
    (out / 'source-identity.json').write_text(json.dumps(source, indent=1) + '\n')
    check('frozen source tree archive and 486-file manifest match candidate', source['matches_build'])
    expected_exe = build['runtime']['members_sha256']['linux_release.x86_64']
    check('runtime and pack match release before and after', run['identity']['executable_sha256'] == expected_exe
          and run['identity_after']['SpillwayR14.x86_64'] == expected_exe
          and run['identity']['actual_pack_sha256'] == build['pack_sha256']
          and run['identity_after']['SpillwayR14.pck'] == build['pack_sha256'])
    check('real release runtime loads real packed r14 scene', identity['release'] and not identity['editor']
          and not identity['debug'] and identity['res_root'] == ''
          and identity['main_scene'] == identity['project_main_scene'] == 'res://scenes/r14.tscn'
          and identity['game_script'] == 'res://scripts/r14_main.gd'
          and identity['runner'] == 'res://scripts/r14_source_player.gd')
    check('isolated profile with records off', not identity['persist'] and not run['records_created']
          and identity['user_dir'].startswith(run['scratch'] + '/')
          and all(r['profile_state'] == 'off' for r in samples))
    check('default W and Space hold hops repeatedly', run['default_held']['jumps'] >= 3
          and run['default_held']['keys']['w'] and run['default_held']['keys']['space'])
    check('F2 W and Space hold hops repeatedly', run['f2_held']['jumps'] >= 3
          and run['f2_held']['preset'] == 'server128')
    manual = run['manual_held']
    check('F1 held Space jumps once and lands while still held', manual['jumps'] == 1
          and manual['grounded'] and manual['lands'] >= 2 and manual['keys']['space'])
    check('F1 release and fresh Space press jumps again', run['manual_second']['jumps'] == 2)
    check('F1 wheel delivers another jump', run['manual_wheel']['jumps'] == 3
          and not run['manual_wheel']['grounded']
          and any(r['button'] == 4 and r['pressed'] for r in phase('manual-wheel', 'button')))
    check('all five F-key presets and rates', [(r['preset'], r['hz']) for r in run['fkeys']] == [
        ('r13_original120', 120), ('quake3_inspired128', 128), ('server128_aa1000', 128), ('server128', 128)]
          and manual['preset'] == 'vanilla64' and manual['hz'] == 64)
    check('observed physics delta follows active preset throughout', all(r['rate_ok']
          and r['rate_mismatch_ticks'] == 0 and abs(r['delta'] - 1 / r['hz']) < 1e-12 for r in samples))
    check('ordinary stage picker selects and starts Penstock straight', run['stage_selection']['stage_selected'] == 3
          and run['stage_selection']['stage_items'][3] == '3  Penstock straight'
          and run['stage_started']['practice_stage'] == 3 and not run['stage_started']['paused'])
    check('HUD reports each active preset', all(('F' + str(i)) in r['hud']['identity'] for i, r in [
        (1, manual), (2, run['f2_held']), (3, run['fkeys'][0]), (4, run['fkeys'][1]), (5, run['fkeys'][2])]))

    calibration = run['mouse_calibration']
    delivered = sum(r['screen_relative'][0] for r in phase('mouse-calibration', 'motion'))
    before, after = calibration['before'], calibration['after']
    expected_yaw = -math.radians(delivered * before['sensitivity'] * before['m_yaw'])
    measured_yaw = after['yaw'] - before['yaw']
    details['mouse'] = {'requested_xtest_dx': calibration['requested_dx'], 'observed_screen_relative_dx': delivered,
                        'sensitivity': before['sensitivity'], 'm_yaw': before['m_yaw'],
                        'expected_yaw_radians': expected_yaw, 'measured_yaw_radians': measured_yaw,
                        'error_radians': measured_yaw - expected_yaw,
                        'scope': 'XTest request and read-only Godot event observation agree; no physical device raw counts or latency claim.'}
    check('Source mouse response matches delivered delta times sensitivity times m_yaw', delivered == calibration['requested_dx']
          and abs(expected_yaw - measured_yaw) < 1e-10)
    for label, direction in [('d-right-strafe', 1), ('a-left-strafe', -1)]:
        air = [r for r in phase(label) if not r['grounded']]
        motion = sum(r['screen_relative'][0] for r in phase(label, 'motion'))
        first, last = air[0], air[-1]
        details[label] = {'air_samples': len(air), 'screen_relative_dx': motion,
                          'start_speed_u': speed(first), 'end_speed_u': speed(last),
                          'yaw_delta_radians': last['yaw'] - first['yaw'],
                          'velocity_start': first['velocity'], 'velocity_end': last['velocity']}
        check(label + ' turns and builds airborne speed', speed(last) > speed(first) + 1
              and direction * motion > 0 and direction * (last['yaw'] - first['yaw']) < 0
              and any(r['keys']['d' if direction > 0 else 'a'] and not r['keys']['w'] for r in air))
    coast = [r for r in phase('no-keys-coast') if not r['grounded'] and not any(r['keys'].values())]
    first, last = coast[0], coast[-1]
    drift = max(math.hypot(r['velocity'][0] - first['velocity'][0], r['velocity'][2] - first['velocity'][2]) for r in coast)
    details['coast'] = {'samples': len(coast), 'tick_intervals': last['tick'] - first['tick'],
                        'simulation_seconds': (last['tick'] - first['tick']) / first['hz'],
                        'logged_wall_ms': last['ms'] - first['ms'], 'speed_u': speed(first),
                        'max_horizontal_velocity_drift_m_s': drift,
                        'horizontal_displacement_m': math.hypot(last['position'][0] - first['position'][0], last['position'][2] - first['position'][2])}
    check('bounded no-key airborne flight coasts without horizontal loss', len(coast) >= 10
          and details['coast']['simulation_seconds'] > .1 and drift < 1e-6
          and details['coast']['horizontal_displacement_m'] > .5)
    check('Escape pauses resumes and Quit click exits cleanly', run.get('game_exit') == 0
          and run['quit_wall_s'] < 5 and len(phase('escape-resume', 'key')) >= 4
          and any(r['button'] == 1 and r['pressed'] for r in phase('escape-quit', 'button')))
    check('real AMD kernel gfx work plus engine device confirmation', run['gpu']['ok']
          and any(c['driver'] == 'amdgpu' and c['gfx_ns_last'] > 0 for c in run['gpu']['clients'])
          and 'AMD' in run['device']['device'] and 'radeonsi' in identity['adapter'])
    attempts = {}
    for path in sorted(out.glob('attempt-*')):
        info = json.loads((path / 'run.json').read_text())
        display = json.loads((path / 'display/native-display.json').read_text())
        clean = info['scratch_removed'] and info['display_released'] and not info['game_alive_after']
        clean = clean and not display['cleanup']['problems'] and not display['cleanup']['owned_processes_remaining']
        clean = clean and not display['cleanup']['x']['left'] and display['desktop_before']['ok'] and display['desktop_after']['ok']
        attempts[path.name] = {'failure': info.get('failure', {}).get('message'), 'display': display['display'], 'clean': bool(clean)}
    check('all successful and failed attempts cleaned with desktop answering', all(a['clean'] for a in attempts.values()))
    check('no successful-run engine errors', 'ERROR:' not in (out / args.attempt / 'engine.log').read_text())
    sizes = {str(p.relative_to(out)): p.stat().st_size for p in out.rglob('*') if p.is_file()}
    check('bounded evidence at most 8 MiB and 8 JPEGs without movies or PNGs', sum(sizes.values()) < 8 * 2**20
          and len(list(out.rglob('*.jpg'))) <= 8 and not any(p.suffix.lower() in ['.png', '.mp4', '.avi'] for p in out.rglob('*')))
    report = {'checks': checks, 'passed': sum(checks.values()), 'total': len(checks), 'details': details,
              'identity': identity, 'source': source, 'attempts': attempts, 'evidence_bytes': sum(sizes.values()),
              'jpeg_count': len(list(out.rglob('*.jpg'))), 'actual_input_delivery_issue': False if all(checks.values()) else 'inspect failed checks'}
    (out / 'analysis.json').write_text(json.dumps(report, indent=1) + '\n')
    print(json.dumps(report, indent=1))
    return int(not all(checks.values()))


if __name__ == '__main__':
    raise SystemExit(main())
