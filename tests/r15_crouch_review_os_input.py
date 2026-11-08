#!/usr/bin/env python3
"""p / bounded native red/control for the diagnostic settings resize, not a product key.

the copy passed by --project must contain the reviewed source and its own import cache.
each process receives one setup, then xtest keys and relative mouse only. no movie.
"""
import argparse
import ctypes
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

SOURCE = Path(__file__).resolve().parents[1]
GODOT = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
spec = importlib.util.spec_from_file_location('review_display', SOURCE / 'tools/r14_native_display.py')
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run_episode(display, env, project, target, resize):
    target.mkdir()
    actions = []
    game = watch = None
    handle = None
    report = {'resize': resize, 'actions': actions}

    def latest():
        try:
            return json.loads((target / 'latest.json').read_text())
        except (OSError, ValueError):
            return {}

    def wait(predicate, seconds=12):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            row = latest()
            if row and predicate(row):
                return row
            if game.poll() is not None:
                raise RuntimeError('game exited early: %s' % game.returncode)
            time.sleep(.004)
        raise TimeoutError('latest=%r' % latest())

    def xdo(*args):
        assert env['DISPLAY'] == display.display and 190 <= display.number <= 199
        actions.append({'argv': list(args), 'at': latest()})
        return subprocess.run(['xdotool', *args], env=env, capture_output=True, text=True,
                              check=True, timeout=5).stdout

    command = [str(GODOT), '--path', str(project), '--audio-driver', 'Dummy', '--display-driver', 'x11',
               '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720',
               '--script', 'res://tests/r15_crouch_review_native.gd', '--', '--out=' + str(target)]
    report['command'] = command
    try:
        with (target / 'engine.log').open('w') as log:
            game = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                    start_new_session=True, preexec_fn=nd._owned_child(os.getpid()))
            watch = nd.GpuWatch().follow(game.pid)
            wait(lambda r: r.get('grounded'), 30)
            window = xdo('search', '--onlyvisible', '--name', 'Spillway').splitlines()[0]
            xdo('windowfocus', window)
            xdo('keydown', 'Control_L', 'w')
            wait(lambda r: r['p'][2] < -500 and r['ducked'], 18)
            xdo('keyup', 'w')
            wait(lambda r: abs(r['v'][2]) < .01)
            x11 = ctypes.CDLL('libX11.so.6')
            xt = ctypes.CDLL('libXtst.so.6')
            x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
            x11.XOpenDisplay.restype = ctypes.c_void_p
            x11.XFlush.argtypes = [ctypes.c_void_p]
            x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
            xt.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
            handle = x11.XOpenDisplay(display.display.encode())
            if not handle:
                raise RuntimeError('cannot open owned private display for xtest')
            yaw = latest()['yaw']
            assert xt.XTestFakeRelativeMotionEvent(handle, 20, 0, 0)
            x11.XFlush(handle)
            turned = wait(lambda r: r['yaw'] != yaw)
            report['mouse_changed_yaw'] = turned['yaw'] != yaw
            assert xt.XTestFakeRelativeMotionEvent(handle, -20, 0, 0)
            x11.XFlush(handle)
            wait(lambda r: abs(r['yaw'] - yaw) < 1e-5)
            xdo('keyup', 'Control_L')
            wait(lambda r: r['blocked'])
            xdo('keydown', 'Control_L')
            wait(lambda r: r['held'] and not r['blocked'])
            before = latest()
            if resize:
                xdo('key', 'F7')
                wait(lambda r: r['height'] == 70)
            wait(lambda r: r['t'] > before['t'] + 30)
            xdo('keyup', 'w', 'Control_L')
            xdo('key', 'F10')
            game.wait(timeout=10)
    except BaseException as error:
        report['failure'] = repr(error)
    finally:
        if game:
            nd._stop_group(game)
            report['exit'] = game.returncode
        if watch:
            watch.stop()
            report['gpu'] = watch.verdict()
        if handle:
            x11.XCloseDisplay(handle)
    log = (target / 'engine.log').read_text()
    report['device'] = nd.godot_device(log)
    telemetry = target / 'telemetry.jsonl.gz'
    if telemetry.exists():
        rows = [json.loads(line) for line in gzip.open(telemetry)]
        bad = [r for r in rows if r['overlap']]
        report.update({'rows': len(rows), 'overlap_ticks': len(bad), 'first_overlap': bad[0] if bad else None,
                       'max_actual_vy': max(abs(r['actual_v'][1]) for r in rows),
                       'min_feet_y': min(r['p'][1] for r in rows)})
    (target / 'episode.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    report = {'home_free_before': shutil.disk_usage(Path.home()).free,
              'godot_sha256': digest(GODOT), 'driver_sha256': digest(__file__),
              'helper_sha256': digest(SOURCE / 'tools/r14_native_display.py'),
              'files': {n: digest(args.project / n) for n in ['scripts/r15_source_player.gd',
                        'scripts/r14_source_player.gd', 'tests/test_r15_crouch_review.gd',
                        'tests/r15_crouch_review_native.gd']},
              'scope': 'native OS input; F7 is an explicit settings diagnostic, not a shipped binding'}
    if report['home_free_before'] < 15 * 2**30:
        raise RuntimeError('HOME below 15 GiB, native work refused')
    with tempfile.TemporaryDirectory(prefix='r15-crouch-review-profile-', dir='/dev/shm') as tmp:
        env = dict(os.environ)
        for name in ['data', 'config', 'cache', 'state']:
            d = Path(tmp) / name
            d.mkdir()
            env['XDG_%s_HOME' % name.upper()] = str(d)
        with nd.NativeDisplay(args.out / 'display', displays=range(190, 200)) as display:
            env = display.child_env(env)
            report['control'] = run_episode(display, env, args.project, args.out / 'control', False)
            report['red'] = run_episode(display, env, args.project, args.out / 'resize', True)
        report['display_released'] = display.released
        report['profile_files'] = [str(p.relative_to(tmp)) for p in Path(tmp).rglob('*') if p.is_file()]
    report['scratch_removed'] = not Path(tmp).exists()
    report['confirmed'] = (report['control'].get('overlap_ticks') == 0
                           and report['red'].get('overlap_ticks', 0) > 0
                           and all(report[k].get('gpu', {}).get('ok')
                                   and report[k].get('mouse_changed_yaw')
                                   and report[k].get('exit') == 0 for k in ['control', 'red']))
    (args.out / 'run.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['confirmed', 'display_released', 'scratch_removed']}, indent=2))
    return 0 if report['confirmed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
