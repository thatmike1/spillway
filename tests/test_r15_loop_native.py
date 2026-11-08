#!/usr/bin/env python3
"""p / native r15 product tour on the private amd/x11 display (tools/r14_native_display.py). the
real r15 scene runs under tests/test_r15_loop_tour.gd, which only observes it; all control is OS
input from this process: xdotool keys and clicks into the game window and XTest relative mouse
motion, timed from the observer's telemetry like a player watching the screen. one run covers
the default map, a run-up and hops, ground and air crouch, F5, the pause menu's map chooser, a
click to Overflow, F checkpoint practice and the menu's Quit. it records an MP4, selected JPEGs
and the gzipped per-tick telemetry, proves the game drew on the amd render node, and removes
every process, display and scratch file it made. presentation and lifecycle evidence only: not
a course route, timing or feel claim.

python3 tests/test_r15_loop_native.py --out DIR
exit 0 every check passed, 1 a check failed, 3 refused (HOME below 15 GiB).
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
import sys
import tempfile
import time
import traceback

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get('GODOT', Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))
spec = importlib.util.spec_from_file_location('r15_loop_nd', PROJECT / 'tools/r14_native_display.py')
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
SOURCES = ['scripts/r15_main.gd', 'scripts/r15_hud.gd', 'scripts/r15_presets.gd', 'scripts/r15_maps.gd', 'scripts/r15_launch.gd', 'scenes/r15.tscn',
           'scripts/r15_source_player.gd', 'tests/test_r15_loop_tour.gd', 'tests/test_r15_loop_native.py', 'tools/r14_native_display.py']
MAX_JPEGS = 9
GRAB = '1296x736'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class Tour:
    def __init__(self, display, env, out, observer, deadline):
        self.display, self.env, self.out, self.observer, self.deadline = display, env, out, observer, deadline
        self.actions, self.shots, self.commands = [], [], []
        self.game = self.window = self.xt = self.recorder = None

    def run(self, cmd, timeout=10, check=True):
        if time.monotonic() > self.deadline:
            raise TimeoutError('global budget')
        self.commands.append([str(c) for c in cmd])
        return subprocess.run(cmd, env=self.env, capture_output=True, text=True, timeout=timeout, check=check)

    def xdo(self, *parts, check=True):
        assert self.env['DISPLAY'] == self.display.display and 190 <= self.display.number <= 199
        return self.run(['xdotool', *map(str, parts)], check=check)

    def latest(self):
        try:
            return json.loads((self.observer / 'latest.json').read_text())
        except (OSError, ValueError):
            return {}

    def wait(self, predicate, seconds, what):
        until = min(self.deadline, time.monotonic() + seconds)
        while time.monotonic() < until:
            row = self.latest()
            if row and predicate(row):
                return row
            if self.game.poll() is not None:
                raise RuntimeError('game exited %s while waiting for %s' % (self.game.returncode, what))
            time.sleep(.004)
        raise TimeoutError('%s timed out; latest=%r' % (what, {k: self.latest().get(k) for k in ['t', 'map', 'preset', 'paused', 'ducked', 'grounded']}))

    def act(self, label, *parts):
        row = self.latest()
        self.actions.append({'label': label, 'xdotool': [str(p) for p in parts], 'at_tick': row.get('t')})
        self.xdo(*parts)

    def click(self, label, at):
        assert at, 'no target for ' + label
        self.act(label, 'mousemove', '--window', self.window, at[0], at[1], 'click', 1)

    def turn(self, dx, count):
        if self.xt is None:
            x11 = ctypes.CDLL('libX11.so.6')
            xt = ctypes.CDLL('libXtst.so.6')
            x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
            x11.XOpenDisplay.restype = ctypes.c_void_p
            x11.XFlush.argtypes = [ctypes.c_void_p]
            xt.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
            self.x11, self.xtst = x11, xt
            self.xt = x11.XOpenDisplay(self.display.display.encode())
            assert self.xt
        before = self.latest().get('t')
        for _ in range(count):
            assert self.xtst.XTestFakeRelativeMotionEvent(self.xt, dx, 0, 0)
            self.x11.XFlush(self.xt)
            time.sleep(.016)
        self.actions.append({'label': 'xtest relative turn', 'dx': dx, 'count': count, 'at_tick': before})

    def shot(self, label):
        if len(self.shots) >= MAX_JPEGS:
            raise RuntimeError('JPEG limit')
        path = self.out / ('%02d-%s.jpg' % (len(self.shots) + 1, label))
        row = self.latest()
        self.run(['ffmpeg', '-v', 'error', '-y', '-f', 'x11grab', '-video_size', GRAB, '-i', self.display.display, '-frames:v', '1', '-q:v', '5', str(path)], timeout=15)
        self.shots.append({'file': path.name, 'tick': row.get('t'), 'map': row.get('map'), 'preset': row.get('preset'), 'paused': row.get('paused'), 'ducked': row.get('ducked')})

    def start_recording(self, seconds):
        cmd = ['ffmpeg', '-v', 'error', '-y', '-f', 'x11grab', '-framerate', '30', '-video_size', GRAB, '-i', self.display.display, '-t', str(seconds),
               '-vf', 'scale=960:-2', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '30', '-pix_fmt', 'yuv420p', str(self.out / 'tour.mp4')]
        self.commands.append(cmd)
        self.recorder = subprocess.Popen(cmd, env=self.env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def stop_recording(self):
        if self.recorder and self.recorder.poll() is None:
            self.recorder.send_signal(signal.SIGINT)
            try:
                self.recorder.wait(15)
            except subprocess.TimeoutExpired:
                self.recorder.kill()

    def release(self):
        self.xdo('keyup', 'w', 'a', 's', 'd', 'space', 'Control_L', check=False)


def settled(t: Tour, pick, seconds=3):
    """a target that two telemetry rows a few ticks apart agree on."""
    until = time.monotonic() + seconds
    last = None
    while time.monotonic() < until:
        row = t.latest()
        value = pick(row) if row.get('paused') else None
        if value and value == last:
            return value
        last = value
        time.sleep(.1)
    raise TimeoutError('menu target never settled')


def play(t: Tour):
    """the scripted tour; every step waits on what the game shows before the next input."""
    ready = t.wait(lambda r: r.get('map') and r.get('preset') == 'server128' and r.get('grounded'), 60, 'game ready')
    t.window = t.xdo('search', '--onlyvisible', '--name', 'Spillway R15').stdout.split()[0]
    t.xdo('windowfocus', t.window)
    time.sleep(.4)
    t.release()
    t.start_recording(75)
    time.sleep(.5)
    t.shot('default-spawn')
    t.act('click to capture the mouse', 'mousemove', '--window', t.window, 640, 360, 'click', 1)
    t.act('hold W', 'keydown', 'w')
    t.wait(lambda r: float(r.get('speed_u', 0)) > 240, 6, 'run-up')
    t.turn(-2, 20)
    t.shot('running')
    t.act('hold Space: autohop', 'keydown', 'space')
    t.wait(lambda r: int(r.get('jumps', 0)) >= int(ready.get('jumps', 0)) + 3, 8, 'three hops')
    t.act('release Space and W', 'keyup', 'space', 'w')
    t.wait(lambda r: r.get('grounded') and float(r.get('speed_u', 999)) < 5, 8, 'stopped')
    t.act('hold Ctrl on the ground', 'keydown', 'Control_L')
    t.wait(lambda r: r.get('ducked') and r.get('grounded'), 3, 'ground duck')
    time.sleep(.4)
    t.shot('ground-crouch')
    t.act('release Ctrl', 'keyup', 'Control_L')
    t.wait(lambda r: not r.get('ducked'), 3, 'stand')
    t.act('R: restart at the spawn', 'key', 'r')
    t.wait(lambda r: r.get('clean') and float(r.get('elapsed', 1)) == 0.0 and r.get('grounded'), 3, 'restart')
    air_before = int(t.latest().get('duck_counts', {}).get('duck_air', 0))
    t.act('hold W', 'keydown', 'w')
    t.wait(lambda r: float(r.get('speed_u', 0)) > 240, 6, 'second run-up')
    t.act('jump', 'key', 'space')
    t.wait(lambda r: not r.get('grounded') and float(r.get('v', [0, 0, 0])[1]) < 2.0, 3, 'rising')
    t.act('crouch in the air', 'keydown', 'Control_L')
    t.wait(lambda r: int(r.get('duck_counts', {}).get('duck_air', 0)) > air_before, 2, 'air duck')
    t.shot('air-crouch')
    t.wait(lambda r: r.get('grounded'), 4, 'landing')
    t.act('release Ctrl and W', 'keyup', 'Control_L', 'w')
    t.act('F5', 'key', 'F5')
    t.wait(lambda r: r.get('preset') == 'server128_aa1000', 3, 'F5')
    time.sleep(.5)
    t.shot('f5-aa1000')
    t.act('Escape', 'key', 'Escape')
    t.wait(lambda r: r.get('paused') and r.get('cards', {}).get('overflow'), 3, 'menu')
    time.sleep(.6)
    t.shot('menu-map-chooser')
    # aim from telemetry after the menu has laid out, as a player clicks what is on screen.
    t.click('Overflow card', settled(t, lambda r: r['cards']['overflow']))
    t.wait(lambda r: r.get('map') == 'overflow' and not r.get('paused'), 20, 'overflow loaded')
    time.sleep(.6)
    t.act('click to capture the mouse', 'mousemove', '--window', t.window, 640, 360, 'click', 1)
    t.act('hold W', 'keydown', 'w')
    time.sleep(1.8)
    t.shot('overflow-running')
    t.act('F: last checkpoint', 'key', 'f')
    t.wait(lambda r: r.get('practice_reason') == 'practice', 3, 'checkpoint practice')
    t.act('release W', 'keyup', 'w')
    time.sleep(.8)
    t.shot('checkpoint-practice')
    t.stop_recording()
    t.act('Escape', 'key', 'Escape')
    t.wait(lambda r: r.get('paused') and r.get('quit'), 3, 'menu for quit')
    time.sleep(.3)
    t.click('Quit button', settled(t, lambda r: r['quit']))
    t.quit_clicked = time.monotonic()
    t.game.wait(20)
    t.quit_seconds = time.monotonic() - t.quit_clicked


def analyze(rows, t, report):
    checks = {}
    first = rows[0] if rows else {}
    checks['default map is Penstock, labelled the stand-in until Breakwater exists'] = first.get('map') == 'practice' and 'development stand-in' in first.get('identity', '')
    checks['production r15 runner, not a stand-in'] = first.get('runner') == 'res://scripts/r15_source_player.gd' and first.get('standin') is False
    checks['F2 bhop server at 128 Hz on screen'] = 'F2 CS:GO bhop server' in first.get('identity', '') and first.get('engine_hz') == 128
    checks['window title names R15, the map and preset'] = any('Spillway R15' in r.get('title', '') and 'Penstock Yard' in r.get('title', '') for r in rows)
    checks['the hud showed run speed over 240 u/s'] = any(r.get('hud_speed', '0').isdigit() and int(r['hud_speed']) > 240 for r in rows)
    checks['held Space hopped at least three times'] = max((int(r.get('jumps', 0)) for r in rows), default=0) >= 3
    ground = [r for r in rows if r.get('ducked') and r.get('grounded') and r.get('crouch_tag') == 'CROUCH']
    checks['ground crouch: duck hull and CROUCH tag'] = bool(ground)
    air = None
    for a, b in zip(rows, rows[1:]):
        if int(b.get('duck_counts', {}).get('duck_air', 0)) > int(a.get('duck_counts', {}).get('duck_air', 0)):
            air = (a, b)
            break
    checks['air crouch happened in flight'] = air is not None and not air[1].get('grounded')
    if air:
        lift = air[1]['feet'][1] - air[0]['feet'][1] - air[0]['v'][1] / 128.0
        report['air_crouch'] = {'tick': air[1]['t'], 'lift_m_beyond_travel': lift, 'speed_before': air[0]['speed_u'], 'speed_after': air[1]['speed_u']}
        checks['air crouch: about 9 u (0.2286 m) of lift beyond travel'] = abs(lift - 9 * 0.0254) < 0.02
        checks['air crouch: hud speed did not jump'] = abs(float(air[1]['speed_u']) - float(air[0]['speed_u'])) < 3.0
    checks['F5 shows Bhop server AA 1000'] = any(r.get('preset') == 'server128_aa1000' and 'F5 Bhop server AA 1000' in r.get('identity', '') for r in rows)
    menu = [r for r in rows if r.get('paused') and r.get('cards')]
    checks['menu map chooser laid out in a grid with both r14 maps'] = bool(menu) and int(menu[0].get('columns', 0)) >= 3 and {'practice', 'overflow'} <= set(menu[0]['cards'])
    checks['clicking Overflow loaded it and kept F5'] = any(r.get('map') == 'overflow' and r.get('preset') == 'server128_aa1000' and not r.get('paused') for r in rows)
    checks['F started checkpoint practice, shown on screen'] = any(r.get('practice_reason') == 'practice' and 'PRACTICE' in r.get('practice_tag', '') for r in rows)
    checks['no respawn-free run claim: nothing recorded'] = all(r.get('records') in ('new', 'loaded', 'new, look settings read from R14') for r in rows)
    checks['R restarted a clean attempt'] = any(a.get('label', '').startswith('R:') for a in t.actions)
    checks['Quit button exited 0 within 10 s'] = t.game.returncode == 0 and getattr(t, 'quit_seconds', 99) < 10
    return checks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    args = ap.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    report = {'started': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'godot_sha256': digest(GODOT), 'sources': {s: digest(PROJECT / s) for s in SOURCES},
              'limits': ['XTest/xdotool OS input on a private display, not physical devices, latency or feel.',
                         'The actor waits on telemetry to time inputs, like a player watching the screen.',
                         'Source checkout run with uncommitted r15 shell files, not a pack.']}
    report['git_head'] = subprocess.run(['git', '-C', str(PROJECT), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    report['git_status'] = subprocess.run(['git', '-C', str(PROJECT), 'status', '--short', '--', '.'], capture_output=True, text=True).stdout
    free = shutil.disk_usage(Path.home()).free
    report['home_free_before'] = free
    if free < 15 * 2**30:
        report['refused'] = 'HOME below 15 GiB'
        (out / 'run.json').write_text(json.dumps(report, indent=1))
        return 3
    scratch = Path(tempfile.mkdtemp(prefix='r15-loop-native-', dir='/dev/shm'))
    t = None
    rows = []
    try:
        for name in ['data', 'config', 'cache', 'state']:
            (scratch / name).mkdir()
        base = {**os.environ, **{'XDG_%s_HOME' % k.upper(): str(scratch / k) for k in ['data', 'config', 'cache', 'state']}}
        observer = scratch / 'observer'
        with nd.NativeDisplay(out / 'display', displays=range(190, 200)) as display:
            env = display.child_env(base)
            t = Tour(display, env, out, observer, time.monotonic() + 240)
            cmd = [str(GODOT), '--path', str(PROJECT), '--audio-driver', 'Dummy', '--display-driver', 'x11', '--rendering-driver', 'opengl3', '--windowed',
                   '--resolution', '1280x720', '--script', 'res://tests/test_r15_loop_tour.gd', '--', '--observer=' + str(observer), '--r15-profile=user://spillway_r15.cfg']
            report['command'] = cmd
            log = (out / 'engine.log').open('w')
            t.game = subprocess.Popen(cmd, cwd=scratch, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True, preexec_fn=nd._owned_child(os.getpid()))
            gpu = nd.GpuWatch().follow(t.game.pid)
            try:
                play(t)
            finally:
                t.stop_recording()
                if t.game.poll() is None:
                    t.release()
                    os.killpg(t.game.pid, signal.SIGTERM)
                    t.game.wait(10)
                    report['game_killed'] = True
                gpu.stop()
                log.close()
            report['gpu'] = gpu.verdict()
            text = (out / 'engine.log').read_text(errors='replace')
            report['godot_device'] = nd.godot_device(text)
            report['engine_errors'] = [l for l in text.splitlines() if 'ERROR' in l][:40]
        report['display_released'] = display.released
        trace = observer / 'trace.jsonl'
        raw = trace.read_bytes()
        rows = [json.loads(l) for l in raw.decode().splitlines() if l.strip()]
        with gzip.open(out / 'telemetry.jsonl.gz', 'wb', compresslevel=9) as z:
            z.write(raw)
        report['telemetry'] = {'rows': len(rows), 'sha256_raw': hashlib.sha256(raw).hexdigest(), 'gz_roundtrip': hashlib.sha256(gzip.open(out / 'telemetry.jsonl.gz').read()).hexdigest() == hashlib.sha256(raw).hexdigest()}
        checks = analyze(rows, t, report)
        checks['the game drew on the amd render node'] = bool(report['gpu'].get('ok'))
        checks['no engine errors'] = not report['engine_errors']
        checks['godot reports the AMD device'] = bool(report['godot_device']) and 'AMD' in str(report['godot_device'].get('device', ''))
        mp4 = out / 'tour.mp4'
        if mp4.exists():
            probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_frames,duration', '-of', 'json', str(mp4)], capture_output=True, text=True)
            report['mp4'] = json.loads(probe.stdout or '{}') | {'bytes': mp4.stat().st_size, 'sha256': digest(mp4)}
        checks['moving MP4 recorded'] = mp4.exists() and float(report.get('mp4', {}).get('streams', [{}])[0].get('duration', 0)) > 8
        report['checks'] = checks
        report['passed'] = all(checks.values()) and report['display_released']
    except BaseException as error:
        report['failure'] = {'type': type(error).__name__, 'message': str(error), 'traceback': traceback.format_exc()}
    finally:
        if t is not None:
            report['actions'] = t.actions
            report['shots'] = t.shots
            report['commands'] = t.commands
        report['profile_files'] = [str(p.relative_to(scratch)) for p in (scratch / 'data').rglob('*') if p.is_file()] if (scratch / 'data').exists() else []
        shutil.rmtree(scratch, ignore_errors=True)
        report['scratch_removed'] = not scratch.exists()
        report['home_free_after'] = shutil.disk_usage(Path.home()).free
        report['evidence_bytes'] = sum(p.stat().st_size for p in out.rglob('*') if p.is_file())
        (out / 'run.json').write_text(json.dumps(report, indent=1) + '\n')
    print(json.dumps({k: report.get(k) for k in ['failure', 'passed', 'checks', 'display_released', 'scratch_removed', 'evidence_bytes']}, indent=1))
    return 0 if report.get('passed') else 1


if __name__ == '__main__':
    raise SystemExit(main())
