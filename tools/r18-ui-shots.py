#!/usr/bin/env python3
"""r18 ui screenshots on a private hardware display (the desktop's nvidia, via the r17 desktop helper).

stills  : tools/r18-ui-shots.gd screens of one source tree at one or more resolutions.
run     : real retained-input play of one map; keeps readback frames taken at 300+ u/s.
release : launches an exported executable and grabs the private display.

python3 tools/r18-ui-shots.py stills --project DIR --out DIR --res 1920x1080,2560x1440,3440x1440
python3 tools/r18-ui-shots.py run --project DIR --out DIR --res 3440x1440 --map night-shift
python3 tools/r18-ui-shots.py release --exe PATH --out DIR --res 3440x1440
"""
import argparse
import gzip
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
FLOOR = 10_000_000_000
_spec = importlib.util.spec_from_file_location('r18_desktop', PROJECT / 'look/desktop-gpu/helpers/desktop-run.py')
dr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dr)
nd = dr.nd


def gate():
    free = shutil.disk_usage('/home').free
    if free < FLOOR:
        raise RuntimeError('HOME free below 10 GB: %d' % free)


def resolutions(text):
    return [tuple(int(v) for v in item.split('x')) for item in text.split(',')]


def private_env(display, scratch):
    env = display.child_env(nd.minimal_env())
    for key, suffix in [('DATA', 'HOME'), ('CONFIG', 'HOME'), ('CACHE', 'HOME'), ('STATE', 'HOME'), ('RUNTIME', 'DIR')]:
        folder = scratch / key.lower()
        folder.mkdir(mode=0o700, exist_ok=True)
        env['XDG_%s_%s' % (key, suffix)] = str(folder)
    return env


def launch(command, env, cwd, log, deadline=240):
    with log.open('w') as stream:
        p = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        start = time.monotonic()
        try:
            while p.poll() is None:
                gate()
                if time.monotonic() - start > deadline:
                    raise TimeoutError(' '.join(map(str, command)))
                time.sleep(0.2)
        finally:
            if p.poll() is None:
                nd._stop_group(p)
    return p.returncode


def with_display(width, height, evidence, body):
    gate()
    evidence.mkdir(parents=True, exist_ok=True)
    with dr.DesktopDisplay(evidence / ('display-%dx%d-%d' % (width, height, time.time_ns())), width=width, height=height,
                           driver='nvidia', desktop=os.environ.get('DISPLAY', ':0'), min_free_gib=FLOOR / 2**30) as display:
        with tempfile.TemporaryDirectory(prefix='r18-ui-profile-', dir=Path.home() / '.cache') as scratch:
            return body(display, private_env(display, Path(scratch)))


def engine_command(project, width, height, script, args):
    return [str(ENGINE), '--path', str(project), '--display-driver', 'x11', '--rendering-driver', 'opengl3',
            '--audio-driver', 'Dummy', '--windowed', '--position', '0,0', '--resolution', '%dx%d' % (width, height),
            '--script', script, '--', *args]


def stills(a):
    for width, height in resolutions(a.res):
        out = a.out.resolve() / ('%dx%d' % (width, height))
        out.mkdir(parents=True, exist_ok=True)
        args = ['--out=' + str(out)] + (['--states=' + a.states] if a.states else [])
        code = with_display(width, height, a.out / 'evidence', lambda d, env: launch(
            engine_command(a.project, width, height, a.script, args), env, a.project, out / 'engine.log'))
        text = (out / 'engine.log').read_text()
        if a.script != 'res://tools/r18-ui-shots.gd':
            print(json.dumps({'res': [width, height], 'exit': code}), flush=True)
            continue
        rows = json.loads((out / 'stills.json').read_text())['rows']
        bad = [r for r in rows if r['size'] != [width, height]]
        print(json.dumps({'res': [width, height], 'exit': code, 'stills': len(rows), 'wrong_size': bad,
                          'nvidia': 'NVIDIA' in text, 'script_errors': text.count('SCRIPT ERROR')}), flush=True)
        if code != 0 or bad or 'NVIDIA' not in text:
            raise SystemExit('stills failed at %dx%d; see %s' % (width, height, out / 'engine.log'))


def speed(row):
    v = row.get('post', {}).get('v', [0, 0, 0])
    return math.hypot(v[0], v[2]) / 0.0254


def run(a):
    tape_mod = importlib.util.spec_from_file_location('tape', PROJECT / 'tools/momentum-tape.py')
    tape = importlib.util.module_from_spec(tape_mod)
    tape_mod.loader.exec_module(tape)
    routes = json.loads((OUTER / 'delivery/spillway-r16/VERIFICATION.json').read_text())['routes']
    route = next(r for r in routes if r['map'] == a.map and (a.map != 'night-shift' or r['name'] == 'night-f5-earned'))
    expanded = tape.expand(json.loads(Path(route['tape']).read_text()))
    with gzip.open(route['reference'], 'rt') as f:
        fast = [json.loads(line)['tick'] for line in f if speed(json.loads(line)) >= 300]
    first = fast[0] if fast else 1280
    duration = min(expanded['duration_ticks'], first + int(a.extra * 128))
    expanded['duration_ticks'] = duration
    expanded['duration_s'] = duration / 128
    expanded['events'] = [e for e in expanded['events'] if e['tick'] < duration]
    expanded['description'] = 'r18 ui capture: prefix of retained R16 input, no state writes'
    for width, height in resolutions(a.res):
        out = a.out.resolve() / ('%dx%d' % (width, height)) / a.map
        if out.exists():
            shutil.rmtree(out)
        out.mkdir(parents=True)
        (out / 'input.expanded.json').write_text(json.dumps(expanded))
        args = ['--out=' + str(out), '--tape=' + str(out / 'input.expanded.json'), '--physics-hz=128', '--warmup=' + str(route['warmup']),
                '--frames=readback', '--readback-every=6', '--wall-budget-s=200', '--game-script=res://scripts/r17_main.gd', '--game-class=',
                '--motor=' + str(a.preset or route['preset']), '--r16-map=' + a.map, '--r16-source-sensitivity=' + str(route.get('sensitivity', 2.5)),
                '--no-records', '--no-run-recordings'] + (['--ui-telemetry'] if a.telemetry else [])
        code = with_display(width, height, a.out / 'evidence', lambda d, env: launch(
            engine_command(a.project, width, height, 'res://tools/momentum-tape.gd', args), env, a.project, out / 'engine.log', 400))
        trace = {r['tick']: r for r in map(json.loads, (out / 'evaluator/trace.jsonl').read_text().splitlines())}
        frames = [json.loads(line) for line in (out / 'evaluator/frames.jsonl').read_text().splitlines()]
        keep = []
        for frame in frames:
            if 'png' not in frame:
                continue
            row = trace.get(frame['last_tick'])
            s = speed(row) if row else 0
            if s >= 300:
                keep.append((frame, s))
            else:
                Path(frame['png']).unlink(missing_ok=True)
        picks = keep[:: max(1, len(keep) // a.keep)][:a.keep] if keep else []
        for frame, s in keep:
            if (frame, s) not in picks:
                Path(frame['png']).unlink(missing_ok=True)
        named = []
        for frame, s in picks:
            target = out / ('%s-tick%05d-%du.png' % (a.map, frame['last_tick'], round(s)))
            Path(frame['png']).rename(target)
            named.append({'file': str(target), 'tick': frame['last_tick'], 'speed_u_s': s})
        shutil.rmtree(out / 'frames', ignore_errors=True)
        for big in ['evaluator/trace.jsonl', 'evaluator/frames.jsonl', 'evaluator/ghost.jsonl']:
            p = out / big
            if p.exists():
                with p.open('rb') as src, gzip.open(str(p) + '.gz', 'wb') as dst:
                    shutil.copyfileobj(src, dst)
                p.unlink()
        (out / 'capture.json').write_text(json.dumps({'route': route, 'preset': a.preset or route['preset'], 'exit': code,
            'picks': named, 'frames_at_300_plus': len(keep), 'res': [width, height]}, indent=1))
        print(json.dumps({'map': a.map, 'res': [width, height], 'exit': code, 'picks': named}), flush=True)


def release(a):
    for width, height in resolutions(a.res):
        out = a.out.resolve() / ('%dx%d' % (width, height))
        out.mkdir(parents=True, exist_ok=True)

        def body(display, env):
            log = (out / 'engine.log').open('w')
            p = subprocess.Popen([str(a.exe), '--display-driver', 'x11', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
                                  '--windowed', '--position', '0,0', '--resolution', '%dx%d' % (width, height), '--', '--no-run-recordings'],
                                 cwd=a.exe.parent, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                time.sleep(a.wait)
                shots = []
                for i, extra in enumerate(a.keys or ['']):
                    if extra:
                        subprocess.run(['xdotool', 'key', extra], env=env, check=False)
                        time.sleep(2.5)
                    target = out / ('release-%d.png' % i)
                    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'x11grab', '-video_size', '%dx%d' % (width, height),
                                    '-i', env['DISPLAY'] + '+0,0', '-frames:v', '1', str(target)], env=env, check=True)
                    shots.append(str(target))
                return {'alive': p.poll() is None, 'shots': shots}
            finally:
                nd._stop_group(p)
                log.close()
        result = with_display(width, height, a.out / 'evidence', body)
        print(json.dumps(result), flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('stills')
    s.add_argument('--project', type=Path, default=PROJECT)
    s.add_argument('--out', type=Path, required=True)
    s.add_argument('--res', default='1920x1080,2560x1440,3440x1440')
    s.add_argument('--states', default='')
    s.add_argument('--script', default='res://tools/r18-ui-shots.gd')
    r = sub.add_parser('run')
    r.add_argument('--project', type=Path, default=PROJECT)
    r.add_argument('--out', type=Path, required=True)
    r.add_argument('--res', default='3440x1440')
    r.add_argument('--map', required=True)
    r.add_argument('--preset')
    r.add_argument('--extra', type=float, default=6.0, help='seconds of input kept after the first 300 u/s tick')
    r.add_argument('--keep', type=int, default=3)
    r.add_argument('--telemetry', action='store_true')
    e = sub.add_parser('release')
    e.add_argument('--exe', type=Path, required=True)
    e.add_argument('--out', type=Path, required=True)
    e.add_argument('--res', default='3440x1440')
    e.add_argument('--wait', type=float, default=8.0)
    e.add_argument('--keys', nargs='*')
    a = p.parse_args()
    {'stills': stills, 'run': run, 'release': release}[a.cmd](a)


if __name__ == '__main__':
    main()
