#!/usr/bin/env python3
"""p / r15 crouch through actual os input on the private amd display, with moving native views.

each episode launches the r15 movement lab at one crouch station (the labelled setup: the
station spawn and the approved server128 profile), then drives it only through xdotool key
events and libXtst relative mouse motion on that display. the lab's --observer only reads the
runner and writes telemetry; nothing writes pose, velocity, view or duck state. the actor is
coordinate-aware: it waits on the observer's feet position to time a key press, as a player
watching the screen would, so this proves the input path and the runner's response, not
open-loop reproducibility (that is tests/test_r15_crouch.gd).

python3 -I tests/r15_crouch_os_input.py --evidence DIR [--episodes ledge,low_gap,tunnel]
python3 -I tests/r15_crouch_os_input.py --rejudge DIR   (re-run only the analysis on kept telemetry)
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
import signal
import subprocess
import tempfile
import time
import traceback

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get('GODOT', Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))
spec = importlib.util.spec_from_file_location('crouch_nd', PROJECT / 'tools/r14_native_display.py')
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
OWNED = ['scripts/r15_source_player.gd', 'scripts/r15_movement_lab.gd', 'tests/r15_crouch_os_input.py',
         'scripts/r14_source_player.gd', 'scripts/r14_source_motion.gd', 'scripts/r14_source_lab.gd', 'scripts/r14_presets.gd']
U = 0.0254


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class Session:
    """one lab process on the private display, its observer and its input helpers."""

    def __init__(self, display, env, out, scratch, report, deadline):
        self.display, self.env, self.out, self.scratch, self.report, self.deadline = display, env, out, scratch, report, deadline
        self.game = self.gpu = self.window = self.xt = self.recorder = None

    def run(self, cmd, timeout=8, check=True):
        if time.monotonic() > self.deadline:
            raise TimeoutError('global budget')
        self.report['commands'].append({'wall': time.monotonic(), 'argv': [str(c) for c in cmd]})
        return subprocess.run(cmd, env=self.env, capture_output=True, text=True, timeout=timeout, check=check)

    def xdo(self, *parts, check=True):
        assert self.env['DISPLAY'] == self.display.display and 190 <= self.display.number <= 199
        return self.run(['xdotool', *map(str, parts)], check=check)

    def latest(self):
        try:
            return json.loads((self.observer / 'latest.json').read_text())
        except (OSError, ValueError):
            return {}

    def wait(self, predicate, seconds=10, what='condition'):
        until = min(self.deadline, time.monotonic() + seconds)
        while time.monotonic() < until:
            row = self.latest()
            if row and predicate(row):
                return row
            if self.game.poll() is not None:
                raise RuntimeError('lab exited %s' % self.game.returncode)
            time.sleep(.004)
        raise TimeoutError('%s timed out; latest=%r' % (what, self.latest()))

    def launch(self, name, station, view):
        self.name = name
        self.observer = self.scratch / ('observer-' + name)
        self.observer.mkdir()
        cmd = [str(GODOT), '--path', str(PROJECT), '--verbose', '--audio-driver', 'Dummy', '--display-driver', 'x11',
               '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720',
               '--script', 'res://scripts/r15_movement_lab.gd', '--',
               '--station=' + station, '--preset=server128', '--view=' + view, '--observer=' + str(self.observer)]
        self.report['episodes'][name] = {'command': cmd, 'station': station, 'view': view, 'actions': [], 'shots': []}
        self.log = (self.out / (name + '-engine.log')).open('w')
        self.game = subprocess.Popen(cmd, cwd=self.scratch, env=self.env, stdout=self.log, stderr=subprocess.STDOUT,
                                     start_new_session=True, preexec_fn=nd._owned_child(os.getpid()))
        self.gpu = nd.GpuWatch().follow(self.game.pid)
        self.wait(lambda r: r.get('station') == station and r.get('g'), 60, 'lab ready')
        self.window = self.xdo('search', '--onlyvisible', '--name', 'Spillway').stdout.split()[0]
        self.xdo('windowfocus', self.window)
        time.sleep(.3)
        self.release()

    def action(self, label, *parts):
        row = self.latest()
        self.report['episodes'][self.name]['actions'].append({'label': label, 'xdotool': [str(p) for p in parts], 'at_tick': row.get('t'), 'feet_u': row.get('p')})
        self.xdo(*parts)

    def mouse(self, dx, count, spacing=.02):
        if self.xt is None:
            x11 = ctypes.CDLL('libX11.so.6')
            xt = ctypes.CDLL('libXtst.so.6')
            x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
            x11.XOpenDisplay.restype = ctypes.c_void_p
            x11.XFlush.argtypes = [ctypes.c_void_p]
            x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
            xt.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
            handle = x11.XOpenDisplay(self.display.display.encode())
            assert handle
            self.x11, self.xtst, self.xt = x11, xt, handle
        before = self.latest().get('yaw')
        for _ in range(count):
            assert self.xtst.XTestFakeRelativeMotionEvent(self.xt, dx, 0, 0)
            self.x11.XFlush(self.xt)
            time.sleep(spacing)
        time.sleep(.1)
        self.report['episodes'][self.name]['actions'].append({'label': 'xtest relative', 'dx': dx, 'count': count, 'yaw_before': before, 'yaw_after': self.latest().get('yaw')})

    def shot(self, label):
        if len(list(self.out.rglob('*.jpg'))) >= 14:
            raise RuntimeError('fourteen JPEG evidence limit')
        path = self.out / ('%s-%s.jpg' % (self.name, label))
        row = self.latest()
        self.run(['ffmpeg', '-v', 'error', '-y', '-f', 'x11grab', '-video_size', '1296x736', '-i', self.display.display,
                  '-frames:v', '1', '-q:v', '6', str(path)], timeout=15)
        self.report['episodes'][self.name]['shots'].append({'file': path.name, 'tick': row.get('t'), 'feet_u': row.get('p'), 'duck': row.get('duck'), 'hull': row.get('hull')})

    def record(self, seconds):
        path = self.out / (self.name + '.mp4')
        cmd = ['ffmpeg', '-v', 'error', '-y', '-f', 'x11grab', '-framerate', '30', '-video_size', '1296x736', '-i', self.display.display,
               '-t', str(seconds), '-vf', 'scale=960:-2', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '30', '-pix_fmt', 'yuv420p', str(path)]
        self.report['commands'].append({'wall': time.monotonic(), 'argv': cmd})
        self.recorder = subprocess.Popen(cmd, env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def release(self):
        self.xdo('keyup', 'w', 'a', 's', 'd', 'space', 'Control_L', 'Tab', check=False)

    def close(self):
        if self.recorder:
            try:
                self.recorder.wait(timeout=20)
            except subprocess.TimeoutExpired:
                nd._stop_group(self.recorder)
            self.recorder = None
        if self.game and self.game.poll() is None:
            self.release()
            # the lab's own f10 quit flushes its telemetry.
            self.xdo('key', 'F10', check=False)
            try:
                self.game.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
        if self.game:
            nd._stop_group(self.game)
        if self.gpu:
            self.gpu.stop()
        self.log.close()
        ep = self.report['episodes'][self.name]
        ep['exit'] = self.game.returncode if self.game else None
        ep['gpu'] = self.gpu.verdict() if self.gpu else None
        text = (self.out / (self.name + '-engine.log')).read_text()
        ep['device'] = nd.godot_device(text)
        ep['lab_line'] = next((l for l in text.splitlines() if l.startswith('r15 movement lab:')), None)
        telemetry = self.observer / 'telemetry.jsonl'
        if telemetry.exists():
            with telemetry.open('rb') as source, gzip.open(self.out / (self.name + '-telemetry.jsonl.gz'), 'wb', compresslevel=9) as target:
                shutil.copyfileobj(source, target)
        if self.xt:
            self.x11.XCloseDisplay(self.xt)
            self.xt = None
        # keep the engine log short: the verbose startup is the device evidence.
        lines = text.splitlines()
        (self.out / (self.name + '-engine.log')).write_text('\n'.join(lines[:80] + ['...'] + lines[-40:]) + '\n')


def feet(row):
    return row.get('p') or [0, 0, 0]


def ep_ledge(s):
    s.launch('ledge', 'ledge', 'eye')
    s.record(14)
    s.action('run', 'keydown', 'w')
    s.wait(lambda r: feet(r)[2] <= -150.0, 10, 'takeoff distance')
    s.action('jump', 'key', 'space')
    time.sleep(.03)
    s.action('crouch in flight', 'keydown', 'Control_L')
    s.wait(lambda r: r['duck']['ducked'] and not r['g'], 3, 'airborne duck')
    s.shot('01-airborne-duck')
    s.wait(lambda r: r['g'] and abs(feet(r)[1] - 60.0) < 0.2, 3, 'on the ledge')
    time.sleep(.4)
    s.action('stop', 'keyup', 'w')
    s.action('release crouch under roof', 'keyup', 'Control_L')
    s.wait(lambda r: r['duck']['blocked'], 2, 'stand refused')
    s.shot('02-under-roof-blocked')
    s.mouse(-12, 12)
    s.mouse(12, 12)
    s.action('walk out', 'keydown', 'w')
    s.wait(lambda r: not r['duck']['ducked'], 15, 'stands past the roof')
    time.sleep(.25)
    s.shot('03-stood-on-ledge')
    s.action('stop', 'keyup', 'w')
    time.sleep(.3)
    s.close()


def ep_low_gap(s):
    s.launch('low_gap', 'low_gap', 'chase')
    s.record(9)
    s.action('run', 'keydown', 'w')
    s.wait(lambda r: feet(r)[2] <= -262.0, 10, 'pit edge')
    s.action('crouch and hop', 'keydown', 'Control_L', 'space')
    s.wait(lambda r: not r['g'] and r['duck']['ducked'], 2, 'crouch hop airborne')
    time.sleep(.12)
    s.shot('01-crouch-hop-under-roof')
    s.action('stop hopping', 'keyup', 'space')
    s.wait(lambda r: r['g'] and feet(r)[2] < -384.0 and abs(feet(r)[1]) < 1.0, 3, 'far deck')
    s.shot('02-far-deck')
    s.action('stop', 'keyup', 'w', 'Control_L')
    time.sleep(.6)
    s.close()


def ep_tunnel(s):
    s.launch('tunnel', 'tunnel', 'chase')
    s.record(16)
    s.action('run standing', 'keydown', 'w')
    s.wait(lambda r: abs(feet(r)[2] + 240.0) < 0.5 and abs(r['v'][2]) < 1.0, 6, 'standing stopped at the mouth')
    s.shot('01-standing-blocked')
    s.action('crouch', 'keydown', 'Control_L')
    s.wait(lambda r: feet(r)[2] <= -480.0, 12, 'mid tunnel')
    s.action('release inside', 'keyup', 'Control_L')
    s.wait(lambda r: r['duck']['blocked'], 2, 'stand refused')
    s.action('tab view', 'key', 'Tab')
    time.sleep(.3)
    s.shot('02-eye-blocked-inside')
    s.wait(lambda r: not r['duck']['ducked'], 15, 'stands at the exit')
    time.sleep(.2)
    s.shot('03-eye-stood-outside')
    s.action('stop', 'keyup', 'w')
    time.sleep(.4)
    s.close()


def analyze(out, report):
    """judge every episode from its own telemetry; the actor's waits are not the verdict."""
    checks = {}
    for name in report['episodes']:
        path = out / (name + '-telemetry.jsonl.gz')
        if not path.exists():
            checks[name + ': telemetry'] = False
            continue
        rows = [json.loads(l) for l in gzip.open(path) if l.strip()]
        ev = [(r['t'], e) for r in rows for e in r['duck']['ev']]
        names = [e for _, e in ev]
        travel = max(abs(r['d'][1]) for r in rows) if rows else 0
        lift = [r for r in rows if r['duck']['shift']]
        if name == 'ledge':
            on = [r for r in rows if r['g'] and abs(r['p'][1] - 60.0) < 0.2]
            checks['ledge: crouched in flight (+9 u lift)'] = any(abs(r['duck']['shift'] - 9.0) < 1e-3 for r in lift)
            checks['ledge: landed on the 60 u ledge'] = bool(on)
            checks['ledge: stand refused under the roof'] = 'stand_blocked' in names
            stood = [r for r in rows if 'unduck' in r['duck']['ev']]
            checks['ledge: stood past the roof'] = bool(stood) and stood[0]['p'][2] < -768.0 - 16.0 + 0.05 and abs(stood[0]['p'][1] - 60.0) < 0.2
            yaws = [a for a in report['episodes'][name]['actions'] if a.get('label') == 'xtest relative']
            checks['ledge: xtest mouse turned the view'] = bool(yaws) and all(a['yaw_before'] != a['yaw_after'] for a in yaws)
        if name == 'low_gap':
            checks['low_gap: ducked hop over the pit'] = 'duck' in names and any(not r['g'] and r['duck']['ducked'] for r in rows)
            checks['low_gap: never above the 100 u roof'] = all(r['hull'][2] <= 100.001 for r in rows)
            checks['low_gap: landed on the far deck'] = any(r['g'] and r['p'][2] < -384.0 and abs(r['p'][1]) < 1.0 for r in rows)
            checks['low_gap: never fell into the pit'] = min(r['p'][1] for r in rows) > -1.0
        if name == 'tunnel':
            checks['tunnel: standing stopped at the mouth'] = any(abs(r['p'][2] + 240.0) < 0.5 and not r['duck']['ducked'] for r in rows)
            inside = [r for r in rows if -768.0 - 16.0 < r['p'][2] < -256.0 + 16.0]
            checks['tunnel: ducked and under 62 u inside'] = bool(inside) and all(r['duck']['ducked'] and r['hull'][2] < 62.0 for r in inside)
            checks['tunnel: stand refused inside'] = 'stand_blocked' in names
            stood = [r for r in rows if 'unduck' in r['duck']['ev']]
            checks['tunnel: stood on leaving'] = bool(stood) and stood[-1]['p'][2] < -784.0 + 0.05
        # on a lift tick the booked vertical travel is the velocity's own, never the 9 u.
        checks[name + ': lift never booked as travel'] = all(abs(r['d'][1] - r['v'][1] / 128.0) < 0.2 for r in lift) if lift else True
        ep = report['episodes'][name]
        checks[name + ': rendered on amdgpu'] = bool(ep.get('gpu', {}).get('ok')) and 'AMD' in str(ep.get('device'))
        ep['telemetry_rows'] = len(rows)
        ep['duck_events'] = ev
        ep['max_tick_vertical_travel_u'] = travel
    return checks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path)
    parser.add_argument('--episodes', default='ledge,low_gap,tunnel')
    parser.add_argument('--rejudge', type=Path)
    if '--rejudge' in os.sys.argv:
        args = parser.parse_known_args()[0]
        report = json.loads((args.rejudge / 'run.json').read_text())
        checks = analyze(args.rejudge, report)
        report['rejudged'] = {'checks': checks, 'passed': all(checks.values()), 'analyzer_sha256': digest(__file__)}
        (args.rejudge / 'run.json').write_text(json.dumps(report, indent=1) + '\n')
        print(json.dumps(report['rejudged'], indent=1))
        return 0 if report['rejudged']['passed'] else 1
    args = parser.parse_args()
    if args.evidence is None:
        parser.error('--evidence is required')
    out = args.evidence.resolve()
    out.mkdir(parents=True, exist_ok=False)
    report = {'commands': [], 'episodes': {}, 'limitations': [
        'XTest is OS synthetic input on a private display, not physical-device latency or feel.',
        'The actor waits on observer telemetry to time presses (coordinate-aware), like a player watching the screen.',
        'Source checkout run of uncommitted r15 files, not a pack.']}
    report['identity'] = {'driver_sha256': digest(__file__), 'godot_sha256': digest(GODOT), 'helper_sha256': digest(PROJECT / 'tools/r14_native_display.py'),
                          'files': {f: digest(PROJECT / f) for f in OWNED}}
    try:
        report['git_head'] = subprocess.run(['git', '-C', str(PROJECT), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    except OSError:
        pass
    free = shutil.disk_usage(Path.home()).free
    report['home_free_before'] = free
    scratch = None
    deadline = time.monotonic() + 300
    try:
        if free < 15 * 2**30:
            raise RuntimeError('HOME below 15 GiB; no native launch')
        scratch = Path(tempfile.mkdtemp(prefix='r15-crouch-os-', dir='/dev/shm'))
        for name in ['data', 'config', 'cache', 'state']:
            (scratch / name).mkdir()
        base = {**os.environ, **{'XDG_%s_HOME' % k.upper(): str(scratch / k) for k in ['data', 'config', 'cache', 'state']}}
        with nd.NativeDisplay(out / 'display', displays=range(190, 200)) as display:
            env = display.child_env(base)
            for name in args.episodes.split(','):
                session = Session(display, env, out, scratch, report, deadline)
                try:
                    {'ledge': ep_ledge, 'low_gap': ep_low_gap, 'tunnel': ep_tunnel}[name](session)
                except BaseException as error:
                    report['episodes'].setdefault(name, {})['failure'] = {'type': type(error).__name__, 'message': str(error)}
                    if session.game:
                        session.close()
                    if isinstance(error, KeyboardInterrupt):
                        raise
        report['display_released'] = display.released
        report['checks'] = analyze(out, report)
        report['passed'] = all(report['checks'].values()) and not any('failure' in e for e in report['episodes'].values())
    except BaseException as error:
        report['failure'] = {'type': type(error).__name__, 'message': str(error), 'traceback': traceback.format_exc()}
    finally:
        if scratch and scratch.exists():
            report['records_created'] = [str(p.relative_to(scratch)) for p in (scratch / 'data').rglob('*')]
            shutil.rmtree(scratch)
            report['scratch_removed'] = not scratch.exists()
        report['home_free_after'] = shutil.disk_usage(Path.home()).free
        report['evidence_bytes'] = sum(p.stat().st_size for p in out.rglob('*') if p.is_file())
        (out / 'run.json').write_text(json.dumps(report, indent=1) + '\n')
    print(json.dumps({k: report.get(k) for k in ['failure', 'passed', 'checks', 'display_released', 'scratch_removed', 'evidence_bytes']}, indent=1))
    return 0 if report.get('passed') else 1


if __name__ == '__main__':
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('outer 330 s alarm')))
    signal.alarm(330)
    raise SystemExit(main())
