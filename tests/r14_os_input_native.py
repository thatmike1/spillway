#!/usr/bin/env python3
"""bounded xtest/xdotool input-path check of the unchanged shipped linux release."""
import argparse
import ctypes
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import traceback
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
CANDIDATE = OUTER / 'delivery/spillway-r14'
spec = importlib.util.spec_from_file_location('os_input_nd', PROJECT / 'tools/r14_native_display.py')
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=CANDIDATE)
    parser.add_argument('--shots', default='01-startup,02-default-held,03-manual-wheel,04-stage-picker,05-penstock-straight,06-strafe-coast,07-quit-menu')
    args = parser.parse_args()
    out = args.evidence.resolve()
    out.mkdir(parents=True, exist_ok=False)
    report = {'commands': [], 'checks': {}, 'limitations': [
        'XTest is OS synthetic input, not physical-device latency or feel.',
        'This is a short input-path check, not a second full route or discovery run.']}
    game = gpu = display = scratch = None
    xt_display = None
    env = None
    deadline = time.monotonic() + 240
    free = shutil.disk_usage(Path.home()).free
    report['home_free_before'] = free
    try:
        if free < 15 * 2**30:
            raise RuntimeError('HOME below 15 GiB; no native launch')
        scratch = Path(tempfile.mkdtemp(prefix='r14-os-input-', dir='/dev/shm'))
        report['scratch'] = str(scratch)
        package = next(args.package.glob('*linux*.zip'))
        with zipfile.ZipFile(package) as archive:
            archive.extractall(scratch / 'release')
        release = scratch / 'release/SpillwayR14-linux-x86_64'
        exe, pack = release / 'SpillwayR14.x86_64', release / 'SpillwayR14.pck'
        exe.chmod(0o755)
        build = json.loads((release / 'BUILD.json').read_text())
        report['identity'] = {k: build.get(k) for k in ['source_commit', 'source_tree', 'source_archive_sha256',
                                                       'source_manifest_sha256', 'pack_sha256', 'main_scene']}
        report['identity'].update(zip_sha256=digest(package), executable_sha256=digest(exe),
                                  actual_pack_sha256=digest(pack), observer_sha256=digest(PROJECT / 'tests/r14_os_input_observer.gd'),
                                  driver_sha256=digest(__file__),
                                  helper_sha256=digest(PROJECT / 'tools/r14_native_display.py'))
        assert digest(pack) == build['pack_sha256']
        assert digest(exe) == build['runtime']['members_sha256']['linux_release.x86_64']
        (release / 'override.cfg').write_text('[autoload]\nOSObserver="*%s"\n' % (PROJECT / 'tests/r14_os_input_observer.gd'))
        data = scratch / 'observer'
        data.mkdir()
        (data / 'phase').write_text('startup')
        for name in ['data', 'config', 'cache', 'state', 'cwd']:
            (scratch / name).mkdir()
        profile_env = {**os.environ, **{'XDG_%s_HOME' % k.upper(): str(scratch / k) for k in ['data', 'config', 'cache', 'state']}}

        def run(cmd, timeout=8, check=True):
            if time.monotonic() > deadline:
                raise TimeoutError('global 240 s budget')
            report['commands'].append({'wall': time.monotonic(), 'argv': [str(c) for c in cmd]})
            return subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=timeout, check=check)

        def xdo(*parts, check=True):
            assert env['DISPLAY'] == display.display and 190 <= display.number <= 199
            return run(['xdotool', *map(str, parts)], check=check)

        def latest():
            try:
                return json.loads((data / 'latest.json').read_text())
            except (OSError, ValueError):
                return {}

        def wait(predicate, seconds=10):
            until = min(deadline, time.monotonic() + seconds)
            while time.monotonic() < until:
                row = latest()
                if predicate(row):
                    return row
                if game.poll() is not None:
                    raise RuntimeError('game exited %s: %s' % (game.returncode, (out / 'engine.log').read_text()[-1500:]))
                time.sleep(.03)
            raise TimeoutError('condition timed out; latest=%r' % latest())

        def phase(name):
            (data / 'phase').write_text(name)
            return wait(lambda r: r.get('phase') == name)

        def shot(name):
            if name not in args.shots.split(','):
                return
            if len(list(out.parent.rglob('*.jpg'))) >= 8:
                raise RuntimeError('eight JPEG evidence limit')
            path = out / (name + '.jpg')
            run(['ffmpeg', '-v', 'error', '-y', '-f', 'x11grab', '-video_size', '1296x736', '-i', display.display,
                 '-frames:v', '1', '-q:v', '5', str(path)], timeout=15)

        def key(name):
            xdo('key', name)
            time.sleep(.25)

        def button(name):
            pos = latest()['buttons'][name]
            xdo('mousemove', '--window', window, round(pos[0]), round(pos[1]))
            time.sleep(.1)
            xdo('click', '1')
            time.sleep(.3)

        def release_keys():
            xdo('keyup', 'w', 'a', 's', 'd', 'space', 'Control_L', 'Escape', 'F1', 'F2', 'F3', 'F4', 'F5', check=False)
            xdo('mouseup', '1', '4', '5', check=False)

        with nd.NativeDisplay(out / 'display', displays=range(190, 200)) as display:
            env = display.child_env(profile_env)
            cmd = [str(exe), '--verbose', '--audio-driver', 'Dummy', '--display-driver', 'x11', '--rendering-driver', 'opengl3',
                   '--windowed', '--resolution', '1280x720', '--', '--no-records', '--os-observer=' + str(data)]
            report['game_command'] = cmd
            # parent death, a private session and an outer alarm bound every owned child.
            with (out / 'engine.log').open('w') as log:
                game = subprocess.Popen(cmd, cwd=scratch / 'cwd', env=env, stdout=log, stderr=subprocess.STDOUT,
                                        start_new_session=True,
                                        preexec_fn=nd._owned_child(os.getpid()))
                report['game_pid'] = game.pid
                report['game_pgid'] = os.getpgid(game.pid)
                gpu = nd.GpuWatch().follow(game.pid)
                try:
                    ready = wait(lambda r: r.get('preset') == 'server128', 45)
                    window = xdo('search', '--onlyvisible', '--name', 'Spillway R14').stdout.splitlines()[0]
                    xdo('windowfocus', window)
                    time.sleep(.3)
                    release_keys()
                    report['startup'] = ready
                    shot('01-startup')
                    phase('default-held-w-space')
                    xdo('keydown', 'w', 'space')
                    time.sleep(2.4)
                    report['default_held'] = latest()
                    release_keys()
                    shot('02-default-held')
                    key('r')
                    key('F1')
                    wait(lambda r: r.get('preset') == 'vanilla64')
                    key('r')
                    phase('manual-held-space')
                    xdo('keydown', 'space')
                    time.sleep(1.65)
                    report['manual_held'] = latest()
                    xdo('keyup', 'space')
                    phase('manual-release-space-press')
                    key('space')
                    time.sleep(.75)
                    report['manual_second'] = latest()
                    phase('manual-wheel')
                    xdo('click', '4')
                    time.sleep(.3)
                    report['manual_wheel'] = latest()
                    shot('03-manual-wheel')
                    release_keys()
                    report['fkeys'] = []
                    for name, expected in [('F3', 'r13_original120'), ('F4', 'quake3_inspired128'),
                                           ('F5', 'server128_aa1000'), ('F2', 'server128')]:
                        phase('switch-' + name)
                        key(name)
                        report['fkeys'].append(wait(lambda r: r.get('preset') == expected))
                    key('r')
                    phase('pause-stage-picker')
                    key('Escape')
                    wait(lambda r: r.get('paused') is True)
                    report['pause'] = latest()
                    shot('04-stage-picker')
                    button('stage_picker')
                    key('Home')
                    # native PopupMenu starts keyboard selection at the first item on Down.
                    for _ in range(4):
                        key('Down')
                    key('Return')
                    selected = wait(lambda r: r.get('stage_selected') == 3, 5)
                    report['stage_selection'] = selected
                    button('stage_practice_button')
                    stage = wait(lambda r: r.get('practice_stage') == 3 and not r.get('paused'), 5)
                    report['stage_started'] = stage
                    shot('05-penstock-straight')
                    phase('f2-held-w-space')
                    xdo('keydown', 'w', 'space')
                    time.sleep(2.1)
                    report['f2_held'] = latest()
                    release_keys()
                    # explicit xtest relative requests on this display only; observer measures delivered deltas.
                    x11 = ctypes.CDLL('libX11.so.6')
                    xt = ctypes.CDLL('libXtst.so.6')
                    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
                    x11.XOpenDisplay.restype = ctypes.c_void_p
                    x11.XFlush.argtypes = [ctypes.c_void_p]
                    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
                    xt.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
                    xt_display = x11.XOpenDisplay(display.display.encode())
                    assert xt_display

                    def move(dx, count=1, spacing=.035):
                        for _ in range(count):
                            assert xt.XTestFakeRelativeMotionEvent(xt_display, dx, 0, 0)
                            x11.XFlush(xt_display)
                            report['commands'].append({'wall': time.monotonic(), 'xtest_relative': [dx, 0]})
                            time.sleep(spacing)

                    phase('mouse-calibration')
                    before = latest()
                    move(100)
                    time.sleep(.3)
                    report['mouse_calibration'] = {'before': before, 'after': latest(), 'requested_dx': 100}
                    # ordinary F restarts the active practice stage; no observer state writes.
                    key('f')
                    phase('d-right-strafe')
                    xdo('keydown', 'w')
                    time.sleep(.65)
                    xdo('keydown', 'space')
                    time.sleep(.08)
                    xdo('keyup', 'w')
                    xdo('keydown', 'd')
                    move(12, 10, .025)
                    report['right_strafe'] = latest()
                    release_keys()
                    phase('no-keys-coast')
                    time.sleep(.12)
                    report['coast'] = latest()
                    shot('06-strafe-coast')
                    key('f')
                    phase('a-left-strafe')
                    xdo('keydown', 'w')
                    time.sleep(.65)
                    xdo('keydown', 'space')
                    time.sleep(.08)
                    xdo('keyup', 'w')
                    xdo('keydown', 'a')
                    move(-12, 10, .025)
                    report['left_strafe'] = latest()
                    release_keys()
                    phase('escape-resume')
                    key('Escape')
                    wait(lambda r: r.get('paused') is True)
                    key('Escape')
                    wait(lambda r: r.get('paused') is False)
                    phase('escape-quit')
                    key('Escape')
                    wait(lambda r: r.get('paused') is True)
                    shot('07-quit-menu')
                    clicked = time.monotonic()
                    button('quit_button')
                    report['game_exit'] = game.wait(timeout=12)
                    report['quit_wall_s'] = time.monotonic() - clicked
                finally:
                    if xt_display:
                        x11.XCloseDisplay(xt_display)
                        xt_display = None
                    release_keys()
                    nd._stop_group(game)
                    gpu.stop()
                    report['gpu'] = gpu.verdict()
            report['device'] = nd.require_amd_log((out / 'engine.log').read_text())
            gpu.require()
    except BaseException as error:
        report['failure'] = {'type': type(error).__name__, 'message': str(error), 'traceback': traceback.format_exc()}
    finally:
        if game:
            nd._stop_group(game)
        if gpu:
            gpu.stop()
        if scratch and scratch.exists():
            telemetry = scratch / 'observer/telemetry.jsonl'
            if telemetry.exists():
                with telemetry.open('rb') as source, gzip.open(out / 'telemetry.jsonl.gz', 'wb', compresslevel=9) as target:
                    shutil.copyfileobj(source, target)
            report['records_created'] = [str(p.relative_to(scratch)) for p in (scratch / 'data').rglob('*.cfg')]
            release = scratch / 'release/SpillwayR14-linux-x86_64'
            report['identity_after'] = {p.name: digest(p) for p in [release / 'SpillwayR14.pck', release / 'SpillwayR14.x86_64'] if p.exists()}
            shutil.rmtree(scratch)
            report['scratch_removed'] = not scratch.exists()
        if display:
            report['display_released'] = display.released
        report['game_alive_after'] = bool(game and game.poll() is None)
        report['home_free_after'] = shutil.disk_usage(Path.home()).free
        report['evidence_bytes'] = sum(p.stat().st_size for p in out.rglob('*') if p.is_file())
        (out / 'run.json').write_text(json.dumps(report, indent=1) + '\n')
    print(json.dumps({k: report.get(k) for k in ['failure', 'game_exit', 'display_released', 'scratch_removed', 'evidence_bytes']}))
    return int('failure' in report)


if __name__ == '__main__':
    # terminal cancellation also unwinds the game/display ownership scopes.
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('outer 260 s alarm')))
    signal.alarm(260)
    raise SystemExit(main())
